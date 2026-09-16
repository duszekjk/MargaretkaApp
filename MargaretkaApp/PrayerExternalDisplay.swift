#if os(iOS)
import AVFoundation
internal import Combine
import CoreGraphics
import CoreVideo
import SwiftUI
import UIKit

@MainActor
final class PrayerExternalDisplayStore {
    static let shared = PrayerExternalDisplayStore()
    static let pageDidChange = Notification.Name("margaretka.externalDisplay.pageDidChange")

    private(set) var currentPage: PrayerExternalDisplayPage?

    private init() {}

    func update(displayIndex: Int, steps: [PrayerFlowStep], prayersByID: [UUID: Prayer]) {
        let stepIndex = displayIndex - 1
        guard steps.indices.contains(stepIndex) else {
            clear()
            return
        }

        let step = steps[stepIndex]
        if let card = step.offlineCard {
            currentPage = .breviary(card)
        } else if let prayer = prayersByID[step.prayerID] {
            currentPage = .prayer(
                name: prayer.name,
                text: prayer.text,
                audioURL: audioURL(for: prayer)
            )
        } else {
            currentPage = nil
        }

        NotificationCenter.default.post(name: Self.pageDidChange, object: nil)
    }

    func clear() {
        currentPage = nil
        NotificationCenter.default.post(name: Self.pageDidChange, object: nil)
    }

    private func audioURL(for prayer: Prayer) -> URL? {
        guard let filename = prayer.audioFilename,
              !filename.isEmpty,
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              let directory = try? AudioStorage.applicationSupportDirectory(create: false) else {
            return nil
        }

        let url = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
}

enum PrayerExternalDisplayPage {
    case breviary(OfflineBreviaryCard)
    case prayer(name: String, text: String, audioURL: URL?)

    var audioURL: URL? {
        guard case .prayer(_, _, let audioURL) = self else { return nil }
        return audioURL
    }
}

@MainActor
final class PrayerExternalDisplayController: ObservableObject {
    static let shared = PrayerExternalDisplayController()

    let player = AVQueuePlayer()
    let audioPlayer = AVPlayer()

    @Published private(set) var hasCurrentPageAudio = false
    @Published private(set) var isAudioMuted = true

    private var looper: AVPlayerLooper?
    private var pageObserver: NSObjectProtocol?
    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    private var externalPlaybackObservation: NSKeyValueObservation?
    private var currentVideoURL: URL?
    private var carrierView: PrayerExternalPlaybackCarrierView?
    private var generationSerial = 0
    private var isStarted = false

    private init() {
        player.isMuted = true
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.externalPlaybackVideoGravity = .resizeAspect
        player.preventsDisplaySleepDuringVideoPlayback = false

        audioPlayer.isMuted = true
        audioPlayer.allowsExternalPlayback = true
        audioPlayer.preventsDisplaySleepDuringVideoPlayback = false
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        pageObserver = NotificationCenter.default.addObserver(
            forName: PrayerExternalDisplayStore.pageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPageAudio()
                self?.refreshPresentation(reason: "page changed")
            }
        }

        connectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else { return }
            Task { @MainActor in
                print(
                    "[ExternalDisplay] screen connected bounds=\(screen.bounds) " +
                    "mirrored=\(screen.mirrored != nil) totalScreens=\(UIScreen.screens.count)"
                )
                self?.attachPlayerLayerWhenPossible()
                self?.refreshPresentation(reason: "screen connected")
            }
        }

        disconnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else { return }
            Task { @MainActor in
                print(
                    "[ExternalDisplay] screen disconnected bounds=\(screen.bounds) " +
                    "totalScreens=\(UIScreen.screens.count)"
                )
                if self?.activeExternalScreen() == nil {
                    self?.player.pause()
                } else {
                    self?.refreshPresentation(reason: "remaining screen selected")
                }
            }
        }

        externalPlaybackObservation = player.observe(
            \.isExternalPlaybackActive,
            options: [.initial, .new]
        ) { [weak self] _, change in
            let active = change.newValue ?? false
            Task { @MainActor in
                print("[ExternalDisplay] AVPlayer externalPlaybackActive=\(active)")
                guard active else { return }
                self?.refreshPresentation(
                    reason: "external playback active",
                    fallbackSize: CGSize(width: 1920, height: 1080)
                )
            }
        }

        attachPlayerLayerWhenPossible()
        refreshPageAudio()
        logEnvironment()
        refreshPresentation(reason: "startup")
    }

    func prepareForAirPlay() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            print("[ExternalDisplay] AirPlay audio session setup failed: \(error)")
        }

        attachPlayerLayerWhenPossible()
        refreshPresentation(
            reason: "AirPlay picker",
            fallbackSize: CGSize(width: 1920, height: 1080)
        )
    }

    func toggleAudioMute() {
        guard hasCurrentPageAudio else { return }

        isAudioMuted.toggle()
        audioPlayer.isMuted = isAudioMuted

        if isAudioMuted {
            audioPlayer.pause()
            audioPlayer.seek(to: .zero)
        } else {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio)
                try session.setActive(true)
            } catch {
                print("[ExternalDisplay] prayer audio session setup failed: \(error)")
            }
            audioPlayer.seek(to: .zero)
            audioPlayer.play()
        }
    }

    private func refreshPageAudio() {
        let audioURL = PrayerExternalDisplayStore.shared.currentPage?.audioURL
        hasCurrentPageAudio = audioURL != nil
        isAudioMuted = true
        audioPlayer.pause()
        audioPlayer.isMuted = true

        if let audioURL {
            audioPlayer.replaceCurrentItem(with: AVPlayerItem(url: audioURL))
        } else {
            audioPlayer.replaceCurrentItem(with: nil)
        }
    }

    private func refreshPresentation(reason: String, fallbackSize: CGSize? = nil) {
        let canvasSize: CGSize
        if let screen = activeExternalScreen() {
            canvasSize = videoCanvasSize(for: screen.bounds.size)
        } else if let fallbackSize {
            canvasSize = videoCanvasSize(for: fallbackSize)
        } else {
            return
        }

        let page = PrayerExternalDisplayStore.shared.currentPage
        generationSerial += 1
        let serial = generationSerial

        guard let image = renderSlide(page: page, size: canvasSize) else {
            print("[ExternalDisplay] failed to render SwiftUI slide")
            return
        }

        print(
            "[ExternalDisplay] rendering video reason=\(reason) " +
            "canvas=\(Int(canvasSize.width))x\(Int(canvasSize.height))"
        )

        Task.detached(priority: .utility) {
            do {
                let url = try await PrayerExternalVideoEncoder.makeStaticClip(
                    image: image,
                    size: canvasSize,
                    durationSeconds: 10
                )

                await MainActor.run {
                    guard serial == self.generationSerial else {
                        try? FileManager.default.removeItem(at: url)
                        return
                    }
                    self.installVideo(url)
                }
            } catch {
                await MainActor.run {
                    print("[ExternalDisplay] video generation failed: \(error)")
                }
            }
        }
    }

    private func installVideo(_ url: URL) {
        let previousURL = currentVideoURL
        currentVideoURL = url

        attachPlayerLayerWhenPossible()
        player.pause()
        looper = nil
        player.removeAllItems()

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()

        print(
            "[ExternalDisplay] AVPlayer started " +
            "allowsExternalPlayback=\(player.allowsExternalPlayback) " +
            "usesExternalPlaybackWhileExternalScreenIsActive=\(player.usesExternalPlaybackWhileExternalScreenIsActive)"
        )

        if let previousURL {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                try? FileManager.default.removeItem(at: previousURL)
            }
        }
    }

    private func attachPlayerLayerWhenPossible(attempt: Int = 0) {
        guard carrierView == nil else { return }

        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first else {
            guard attempt < 10 else {
                print("[ExternalDisplay] could not attach AVPlayerLayer to app window")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.attachPlayerLayerWhenPossible(attempt: attempt + 1)
            }
            return
        }

        let carrier = PrayerExternalPlaybackCarrierView(
            frame: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        carrier.backgroundColor = .clear
        carrier.isUserInteractionEnabled = false
        carrier.accessibilityElementsHidden = true
        carrier.alpha = 0.01
        carrier.playerLayer.player = player
        carrier.playerLayer.videoGravity = .resizeAspect
        window.addSubview(carrier)
        carrierView = carrier

        print("[ExternalDisplay] AVPlayerLayer attached to main window")
    }

    private func renderSlide(page: PrayerExternalDisplayPage?, size: CGSize) -> CGImage? {
        let rootView = PrayerExternalDisplayRootView(page: page)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: rootView)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.cgImage
    }

    private func activeExternalScreen() -> UIScreen? {
        UIScreen.screens.first(where: { $0 !== UIScreen.main })
    }

    private func videoCanvasSize(for screenSize: CGSize) -> CGSize {
        guard screenSize.width > 0, screenSize.height > 0 else {
            return CGSize(width: 1920, height: 1080)
        }

        let maximumLongEdge: CGFloat = 2560
        let longEdge = max(screenSize.width, screenSize.height)
        let scale = min(1, maximumLongEdge / longEdge)
        let width = max(2, floor(screenSize.width * scale / 2) * 2)
        let height = max(2, floor(screenSize.height * scale / 2) * 2)
        return CGSize(width: width, height: height)
    }

    private func logEnvironment() {
        let screens = UIScreen.screens.enumerated().map { index, screen in
            "#\(index)=\(screen.bounds),mirrored=\(screen.mirrored != nil)"
        }.joined(separator: ", ")
        print(
            "[ExternalDisplay] startup supportsMultipleScenes=\(UIApplication.shared.supportsMultipleScenes) " +
            "screens=\(UIScreen.screens.count) [\(screens)]"
        )
    }
}

final class PrayerExternalPlaybackCarrierView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private enum PrayerExternalVideoEncoder {
    enum EncodingError: Error {
        case cannotAddInput
        case cannotStartWriter(Error?)
        case missingPixelBufferPool
        case cannotCreatePixelBuffer
        case cannotCreateContext
        case appendFailed(Error?)
        case writerFailed(Error?)
    }

    static func makeStaticClip(
        image: CGImage,
        size: CGSize,
        durationSeconds: Int
    ) async throws -> URL {
        let width = Int(size.width)
        let height = Int(size.height)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("external-slide-\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let bitrate = max(600_000, min(4_000_000, width * height / 2))
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: 1,
                AVVideoMaxKeyFrameIntervalKey: 1,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        guard writer.canAdd(input) else {
            throw EncodingError.cannotAddInput
        }
        writer.add(input)

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.startWriting() else {
            throw EncodingError.cannotStartWriter(writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        guard let pool = adaptor.pixelBufferPool else {
            writer.cancelWriting()
            throw EncodingError.missingPixelBufferPool
        }

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer else {
            writer.cancelWriting()
            throw EncodingError.cannotCreatePixelBuffer
        }

        try draw(image: image, into: pixelBuffer, width: width, height: height)

        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "margaretka.external-video-writer")
            var frameIndex = 0
            var finishing = false

            input.requestMediaDataWhenReady(on: queue) {
                guard !finishing else { return }

                while input.isReadyForMoreMediaData && frameIndex < durationSeconds {
                    let time = CMTime(value: CMTimeValue(frameIndex), timescale: 1)
                    guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                        finishing = true
                        input.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: EncodingError.appendFailed(writer.error))
                        return
                    }
                    frameIndex += 1
                }

                guard frameIndex >= durationSeconds else { return }
                finishing = true
                input.markAsFinished()
                writer.endSession(atSourceTime: CMTime(value: CMTimeValue(durationSeconds), timescale: 1))
                writer.finishWriting {
                    if writer.status == .completed {
                        continuation.resume(returning: outputURL)
                    } else {
                        continuation.resume(throwing: EncodingError.writerFailed(writer.error))
                    }
                }
            }
        }
    }

    private static func draw(
        image: CGImage,
        into pixelBuffer: CVPixelBuffer,
        width: Int,
        height: Int
    ) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw EncodingError.cannotCreateContext
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue |
            CGImageAlphaInfo.premultipliedFirst.rawValue

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw EncodingError.cannotCreateContext
        }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
}

@MainActor
final class PrayerExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    private var hostingController: UIHostingController<PrayerExternalDisplayRootView>?
    private var pageObserver: NSObjectProtocol?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard session.role == .windowExternalDisplayNonInteractive,
              let windowScene = scene as? UIWindowScene else { return }

        print(
            "[ExternalDisplay] scene connected role=\(session.role.rawValue) " +
            "screen=\(windowScene.screen.bounds)"
        )

        let hostingController = UIHostingController(
            rootView: PrayerExternalDisplayRootView(
                page: PrayerExternalDisplayStore.shared.currentPage
            )
        )
        hostingController.view.backgroundColor = .black

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = hostingController

        self.hostingController = hostingController
        self.window = window

        pageObserver = NotificationCenter.default.addObserver(
            forName: PrayerExternalDisplayStore.pageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPage()
            }
        }

        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("[ExternalDisplay] scene disconnected")
        if let pageObserver {
            NotificationCenter.default.removeObserver(pageObserver)
        }
        pageObserver = nil
        hostingController = nil
        window = nil
    }

    private func refreshPage() {
        hostingController?.rootView = PrayerExternalDisplayRootView(
            page: PrayerExternalDisplayStore.shared.currentPage
        )
    }
}

struct PrayerExternalDisplayRootView: View {
    let page: PrayerExternalDisplayPage?

    private var appDisplayName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        return "App"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let page {
                    ViewThatFits(in: .vertical) {
                        pageView(page, fontSize: 96, geometry: geometry)
                        pageView(page, fontSize: 88, geometry: geometry)
                        pageView(page, fontSize: 80, geometry: geometry)
                        pageView(page, fontSize: 72, geometry: geometry)
                        pageView(page, fontSize: 64, geometry: geometry)
                        pageView(page, fontSize: 56, geometry: geometry)
                        pageView(page, fontSize: 48, geometry: geometry)
                        pageView(page, fontSize: 42, geometry: geometry)
                        pageView(page, fontSize: 36, geometry: geometry)
                        pageView(page, fontSize: 30, geometry: geometry)
                        pageView(page, fontSize: 26, geometry: geometry)
                        pageView(page, fontSize: 22, geometry: geometry)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    Text(appDisplayName)
                        .font(.system(size: min(96, max(48, geometry.size.width * 0.07)), weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func pageView(
        _ page: PrayerExternalDisplayPage,
        fontSize: CGFloat,
        geometry: GeometryProxy
    ) -> some View {
        switch page {
        case .breviary(let card):
            let contentWidth = breviaryContentWidth(
                card: card,
                fontSize: fontSize,
                availableWidth: geometry.size.width
            )
            BreviaryPrayerCardText(
                card: card,
                maxHeight: geometry.size.height,
                constrainHeight: false,
                choirIndent: 84
            )
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: contentWidth, alignment: .center)

        case .prayer(_, let text, _):
            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: geometry.size.width, alignment: .center)
        }
    }

    private func breviaryContentWidth(
        card: OfflineBreviaryCard,
        fontSize: CGFloat,
        availableWidth: CGFloat
    ) -> CGFloat {
        let hasChoirSplit = card.lines.contains {
            $0.role == .choirLeft || $0.role == .choirRight
        }
        guard hasChoirSplit else { return availableWidth }

        let choirIndent: CGFloat = 84
        let choirChrome: CGFloat = choirIndent + 4 + 8 + 20
        let sideBreathingRoom = max(36, fontSize * 0.6)

        let widestLine = card.lines.reduce(CGFloat.zero) { currentMax, line in
            var font = UIFont.systemFont(
                ofSize: fontSize,
                weight: line.emphasized ? .bold : .semibold
            )
            if line.italic,
               let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
                font = UIFont(descriptor: descriptor, size: fontSize)
            }

            let textWidth = ceil(
                (line.text as NSString).size(withAttributes: [.font: font]).width
            )
            let lineChrome = (line.role == .choirLeft || line.role == .choirRight)
                ? choirChrome
                : 0
            return max(currentMax, textWidth + lineChrome)
        }

        let desiredWidth = widestLine + sideBreathingRoom * 2
        let almostFullWidth = availableWidth * 0.92
        if desiredWidth >= almostFullWidth {
            return availableWidth
        }

        return min(availableWidth, max(availableWidth * 0.28, desiredWidth))
    }
}
#endif