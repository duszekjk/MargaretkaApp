import AuthenticationServices
internal import Combine
import Foundation
import Security
import UIKit

struct SyncAPIUser: Codable, Equatable {
    let id: UUID
    let displayName: String
    let email: String?
}

struct PendingSyncConflict: Identifiable {
    let id = UUID()
    let serverRevision: Int
    let serverSnapshot: MargaretkaBackup
}

enum SyncServiceError: LocalizedError {
    case invalidAppleCredential
    case invalidResponse
    case signedOut
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return "Apple nie przekazało danych potrzebnych do logowania. Spróbuj ponownie."
        case .invalidResponse:
            return "Serwer zwrócił nieprawidłową odpowiedź."
        case .signedOut:
            return "Zaloguj się przez Apple, aby synchronizować dane."
        case .server(let message):
            return message
        }
    }
}

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()
    static let baseURL = URL(string: "https://heptadaisy.duszekjk.com/api/")!

    @Published private(set) var user: SyncAPIUser?
    @Published private(set) var isWorking = false
    @Published private(set) var lastSyncDate: Date?
    @Published var errorMessage: String?
    @Published var pendingConflict: PendingSyncConflict?

    private let session: URLSession
    private var accessToken: String?
    private var photoObserver: AnyCancellable?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var isSignedIn: Bool { accessToken != nil && user != nil }

    private init(session: URLSession = .shared) {
        self.session = session
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        accessToken = SyncKeychain.string(for: "accessToken")
        var restoredUser: SyncAPIUser?
        if let data = UserDefaults.standard.data(forKey: "sync.user"),
           let restored = try? decoder.decode(SyncAPIUser.self, from: data) {
            restoredUser = restored
        }
        user = restoredUser
        if let restoredUser {
            migrateLegacyStorageIfNeeded(for: restoredUser.id)
            lastSyncDate = UserDefaults.standard.object(
                forKey: Self.lastSuccessKey(for: restoredUser.id)
            ) as? Date
        } else {
            lastSyncDate = nil
        }

        photoObserver = NotificationCenter.default.publisher(for: .syncPhotoQueued)
            .compactMap { $0.object as? UUID }
            .sink { [weak self] assetID in
                Task { @MainActor [weak self] in
                    guard let self, self.isSignedIn else { return }
                    try? await self.uploadPhoto(assetID: assetID)
                }
            }
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func signIn(with result: Result<ASAuthorization, Error>) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                  let authorizationCode = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else {
                throw SyncServiceError.invalidAppleCredential
            }
            let formatter = PersonNameComponentsFormatter()
            let name = credential.fullName.map(formatter.string(from:))
            let payload = AppleLoginRequest(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                displayName: name?.nilIfBlank,
                email: credential.email,
                device: DeviceDescription.current
            )
            let response: AppleLoginResponse = try await request(
                path: "auth/apple/",
                method: "POST",
                body: payload,
                authenticated: false
            )
            accessToken = response.accessToken
            user = response.user
            migrateLegacyStorageIfNeeded(for: response.user.id)
            lastSyncDate = UserDefaults.standard.object(
                forKey: Self.lastSuccessKey(for: response.user.id)
            ) as? Date
            try SyncKeychain.set(response.accessToken, for: "accessToken")
            UserDefaults.standard.set(try encoder.encode(response.user), forKey: "sync.user")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        do {
            try await requestWithoutResponse(path: "auth/logout/", method: "POST")
        } catch {
            errorMessage = "Wylogowano na tym urządzeniu, ale serwer nie potwierdził zakończenia sesji."
        }
        clearSession(removeAccountStorage: false)
        isWorking = false
    }

    func deleteAccount() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await requestWithoutResponse(path: "auth/account/", method: "DELETE")
            clearSession(removeAccountStorage: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearSession(removeAccountStorage: Bool) {
        if removeAccountStorage, let userID = user?.id {
            UserDefaults.standard.removeObject(forKey: Self.revisionKey(for: userID))
            UserDefaults.standard.removeObject(forKey: Self.lastSuccessKey(for: userID))
            UserDefaults.standard.removeObject(forKey: Self.uploadedPhotoIDsKey(for: userID))
        }
        accessToken = nil
        user = nil
        lastSyncDate = nil
        pendingConflict = nil
        UserDefaults.standard.removeObject(forKey: "sync.user")
        SyncKeychain.remove("accessToken")
    }

    func synchronize(
        prayerStore: PrayerStore,
        targetStore: PriestStore,
        offlineStore: OfflineBreviaryStore,
        force: Bool = false,
        revisionOverride: Int? = nil
    ) async {
        guard isSignedIn else { return }
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await uploadAllPendingPhotos()
            let sessions: [PrayerSession] = LocalDatabase.shared.load(from: PrayerSessionStore.saveKey)
            let archive = MargaretkaBackupService.archive(
                prayers: prayerStore.prayers,
                targets: targetStore.priests,
                sessions: sessions,
                offlineDays: offlineStore.days,
                purpose: .fullBackup
            )
            let payload = SnapshotPushRequest(
                baseRevision: revisionOverride ?? storedRevision,
                force: force,
                device: DeviceDescription.current,
                snapshot: archive
            )
            let response: SnapshotPushResponse = try await request(
                path: "sync/snapshot/",
                method: "POST",
                body: payload
            )
            if response.status == "conflict",
               let snapshot = response.snapshot {
                pendingConflict = PendingSyncConflict(
                    serverRevision: response.revision,
                    serverSnapshot: snapshot
                )
                return
            }
            storedRevision = response.revision
            pendingConflict = nil
            markSuccessfulSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func keepCloudCopy(
        prayerStore: PrayerStore,
        targetStore: PriestStore,
        offlineStore: OfflineBreviaryStore,
        scheduleData: ScheduleData<Priest>
    ) async {
        guard let conflict = pendingConflict else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try MargaretkaBackupService.restoreExactly(
                backup: conflict.serverSnapshot,
                prayerStore: prayerStore,
                targetStore: targetStore,
                offlineStore: offlineStore,
                scheduleData: scheduleData
            )
            storedRevision = conflict.serverRevision
            pendingConflict = nil
            try await downloadMissingPhotos(for: targetStore.priests)
            markSuccessfulSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func keepDeviceCopy(
        prayerStore: PrayerStore,
        targetStore: PriestStore,
        offlineStore: OfflineBreviaryStore
    ) async {
        guard let conflict = pendingConflict else { return }
        pendingConflict = nil
        await synchronize(
            prayerStore: prayerStore,
            targetStore: targetStore,
            offlineStore: offlineStore,
            force: true,
            revisionOverride: conflict.serverRevision
        )
    }

    func keepBothCopies(
        prayerStore: PrayerStore,
        targetStore: PriestStore,
        offlineStore: OfflineBreviaryStore
    ) async {
        guard let conflict = pendingConflict else { return }
        isWorking = true
        errorMessage = nil
        do {
            let plan = MargaretkaBackupService.makeImportPlan(
                backup: conflict.serverSnapshot,
                prayers: prayerStore.prayers,
                targets: targetStore.priests,
                offlineDays: offlineStore.days
            )
            let resolutions = Dictionary(uniqueKeysWithValues: plan.conflicts.map { ($0.id, BackupConflictResolution.keepBoth) })
            _ = try MargaretkaBackupService.apply(
                plan: plan,
                resolutions: resolutions,
                prayerStore: prayerStore,
                targetStore: targetStore,
                offlineStore: offlineStore
            )
            storedRevision = conflict.serverRevision
            pendingConflict = nil
            isWorking = false
            await synchronize(
                prayerStore: prayerStore,
                targetStore: targetStore,
                offlineStore: offlineStore,
                force: true,
                revisionOverride: conflict.serverRevision
            )
        } catch {
            isWorking = false
            errorMessage = error.localizedDescription
        }
    }

    private var storedRevision: Int? {
        get {
            guard let userID = user?.id else { return nil }
            let value = UserDefaults.standard.integer(forKey: Self.revisionKey(for: userID))
            return value == 0 ? nil : value
        }
        set {
            guard let userID = user?.id else { return }
            let key = Self.revisionKey(for: userID)
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    private func markSuccessfulSync() {
        guard let userID = user?.id else { return }
        lastSyncDate = .now
        UserDefaults.standard.set(lastSyncDate, forKey: Self.lastSuccessKey(for: userID))
    }

    private func uploadAllPendingPhotos() async throws {
        for assetID in SyncedPhotoStorage.shared.allStoredAssetIDs() where !uploadedPhotoIDs.contains(assetID) {
            try await uploadPhoto(assetID: assetID)
        }
    }

    private func uploadPhoto(assetID: UUID) async throws {
        guard let token = accessToken else { throw SyncServiceError.signedOut }
        let data = try SyncedPhotoStorage.shared.data(for: assetID)
        var urlRequest = URLRequest(url: Self.baseURL.appending(path: "media/photos/\(assetID.uuidString.lowercased())/original/"))
        urlRequest.httpMethod = "PUT"
        urlRequest.httpBody = data
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        let (_, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SyncServiceError.server("Nie udało się przesłać zdjęcia w pełnej rozdzielczości.")
        }
        var uploaded = uploadedPhotoIDs
        uploaded.insert(assetID)
        uploadedPhotoIDs = uploaded
    }

    private func downloadMissingPhotos(for targets: [Priest]) async throws {
        guard let token = accessToken else { throw SyncServiceError.signedOut }
        let missing = Set(targets.compactMap(\.photoAssetID)).filter { !SyncedPhotoStorage.shared.contains($0) }
        for assetID in missing {
            var urlRequest = URLRequest(url: Self.baseURL.appending(path: "media/photos/\(assetID.uuidString.lowercased())/original/"))
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
            try data.write(
                to: SyncedPhotoStorage.shared.url(for: assetID),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            var uploaded = uploadedPhotoIDs
            uploaded.insert(assetID)
            uploadedPhotoIDs = uploaded
        }
    }

    private var uploadedPhotoIDs: Set<UUID> {
        get {
            guard let userID = user?.id else { return [] }
            return Set(
                (UserDefaults.standard.stringArray(forKey: Self.uploadedPhotoIDsKey(for: userID)) ?? [])
                    .compactMap(UUID.init(uuidString:))
            )
        }
        set {
            guard let userID = user?.id else { return }
            UserDefaults.standard.set(
                newValue.map(\.uuidString).sorted(),
                forKey: Self.uploadedPhotoIDsKey(for: userID)
            )
        }
    }

    private func migrateLegacyStorageIfNeeded(for userID: UUID) {
        let defaults = UserDefaults.standard
        let revisionKey = Self.revisionKey(for: userID)
        let lastSuccessKey = Self.lastSuccessKey(for: userID)
        let photoIDsKey = Self.uploadedPhotoIDsKey(for: userID)

        if defaults.object(forKey: revisionKey) == nil,
           let revision = defaults.object(forKey: "sync.revision") {
            defaults.set(revision, forKey: revisionKey)
        }
        if defaults.object(forKey: lastSuccessKey) == nil,
           let lastSuccess = defaults.object(forKey: "sync.lastSuccess") {
            defaults.set(lastSuccess, forKey: lastSuccessKey)
        }
        if defaults.object(forKey: photoIDsKey) == nil,
           let photoIDs = defaults.object(forKey: "sync.uploadedPhotoIDs") {
            defaults.set(photoIDs, forKey: photoIDsKey)
        }

        defaults.removeObject(forKey: "sync.revision")
        defaults.removeObject(forKey: "sync.lastSuccess")
        defaults.removeObject(forKey: "sync.uploadedPhotoIDs")
    }

    private static func revisionKey(for userID: UUID) -> String {
        "sync.revision.\(userID.uuidString.lowercased())"
    }

    private static func lastSuccessKey(for userID: UUID) -> String {
        "sync.lastSuccess.\(userID.uuidString.lowercased())"
    }

    private static func uploadedPhotoIDsKey(for userID: UUID) -> String {
        "sync.uploadedPhotoIDs.\(userID.uuidString.lowercased())"
    }

    private func request<Request: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Request,
        authenticated: Bool = true
    ) async throws -> Response {
        var urlRequest = URLRequest(url: Self.baseURL.appending(path: path))
        urlRequest.httpMethod = method
        urlRequest.httpBody = try encoder.encode(body)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated {
            guard let accessToken else { throw SyncServiceError.signedOut }
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw SyncServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) || http.statusCode == 409 else {
            let detail = (try? decoder.decode(APIErrorResponse.self, from: data).detail)
            throw SyncServiceError.server(detail ?? "Błąd serwera synchronizacji (\(http.statusCode)).")
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func requestWithoutResponse(path: String, method: String) async throws {
        guard let accessToken else { throw SyncServiceError.signedOut }
        var urlRequest = URLRequest(url: Self.baseURL.appending(path: path))
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw SyncServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? decoder.decode(APIErrorResponse.self, from: data).detail)
            throw SyncServiceError.server(detail ?? "Błąd serwera synchronizacji (\(http.statusCode)).")
        }
    }
}

private struct AppleLoginRequest: Encodable {
    let identityToken: String
    let authorizationCode: String
    let displayName: String?
    let email: String?
    let device: DeviceDescription
}

private struct AppleLoginResponse: Decodable {
    let accessToken: String
    let user: SyncAPIUser
}

private struct SnapshotPushRequest: Encodable {
    let baseRevision: Int?
    let force: Bool
    let device: DeviceDescription
    let snapshot: MargaretkaBackup
}

private struct SnapshotPushResponse: Decodable {
    let status: String
    let revision: Int
    let snapshot: MargaretkaBackup?
}

private struct APIErrorResponse: Decodable {
    let detail: String
}

private struct DeviceDescription: Codable {
    let id: UUID
    let name: String
    let model: String
    let systemVersion: String
    let family: PhotoLayoutFamily

    static var current: DeviceDescription {
        let defaults = UserDefaults.standard
        let id: UUID
        if let raw = defaults.string(forKey: "sync.deviceID"), let stored = UUID(uuidString: raw) {
            id = stored
        } else {
            id = UUID()
            defaults.set(id.uuidString, forKey: "sync.deviceID")
        }
        let device = UIDevice.current
        return DeviceDescription(
            id: id,
            name: device.name,
            model: device.model,
            systemVersion: device.systemVersion,
            family: device.userInterfaceIdiom == .pad ? .iPad : .iPhone
        )
    }
}

private enum SyncKeychain {
    static let service = "com.duszekjk.MargaretkaApp.sync"

    static func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, for account: String) throws {
        remove(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(value.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw SyncServiceError.server("Nie udało się bezpiecznie zapisać sesji.") }
    }

    static func remove(_ account: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
