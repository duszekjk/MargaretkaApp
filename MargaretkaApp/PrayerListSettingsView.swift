//
//  PrayerListSettingsView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct PrayerListSettingsView: View {
    @StateObject private var store = PrayerStore()

    var body: some View {
        List {
            ForEach(store.prayers) { prayer in
                NavigationLink(destination: PrayerEditorView(store: store, prayer: prayer)) {
                    Label(prayer.name, systemImage: prayer.renderedSymbol)
                }
            }
            .onDelete { store.delete(at: $0) }

            NavigationLink("Dodaj nową modlitwę") {
                PrayerEditorView(store: store, prayer: nil)
            }
        }
        .navigationTitle("Modlitwy")
    }
}

struct PrayerEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: PrayerStore
    @State var prayer: Prayer?

    @State private var name: String = ""
    @State private var text: String = ""
    @State private var symbol: String = "book"
    @State private var audioSource: AudioSource = .file
    @State private var audioFilename: String = ""
    @State private var showingFileImporter = false
    @State private var content: PrayerContent = .text

    private var isWebPrayer: Bool {
        if case .brewiarz = content {
            return true
        }
        return false
    }

    var body: some View {
        Form {
            Section(header: Text("Podstawowe informacje")) {
                TextField("Nazwa", text: $name)
                if isWebPrayer {
                    Text("Modlitwa online z brewiarz.pl")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Tekst modlitwy", text: $text, axis: .vertical)
                        .lineLimit(5...10)
                }
                Picker("Ikona", selection: $symbol) {
                    ForEach(["book", "bird", "bird.fill", "heart", "heart.fill", "bolt.heart", "bolt.heart.fill", "hands.sparkles", "star", "cross", "sun.min", "moon", "music.note", "leaf", "flame", "flame.fill"], id: \.self) {
                        Label($0, systemImage: $0).tag($0)
                    }
                }
            }

            Section(header: Text("Audio")) {
                if isWebPrayer {
                    Text("Audio niedostępne dla modlitw online.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Źródło audio", selection: $audioSource) {
                        ForEach(AudioSource.allCases, id: \.self) {
                            Text($0.rawValue.capitalized)
                        }
                    }

                    Group {
                        switch audioSource {
                        case .file:
                            Button("Wybierz plik audio") {
                                showingFileImporter = true
                            }
                            if !audioFilename.isEmpty {
                                Text("Wybrano: \(audioFilename)")
                            }

                        case .recorded:
                            AudioRecorderView(audioFilename: $audioFilename)

                        case .generated:
                            TextToSpeechGeneratorView(text: $text, audioFilename: $audioFilename)
                        }
                    }

                    AudioPlayerView(text: $text, audioSource: $audioSource, audioFilename: $audioFilename)
                }
            }



            Button("Zapisz") {
                let newPrayer = Prayer(
                    id: prayer?.id ?? UUID(),
                    name: name,
                    text: text,
                    symbol: symbol,
                    audioFilename: audioFilename,
                    audioSource: audioSource,
                    timestampedLines: prayer?.timestampedLines,
                    content: content
                )
                store.addOrUpdate(newPrayer)
                dismiss()
            }
        }
        .navigationTitle(prayer == nil ? "Nowa modlitwa" : "Edytuj modlitwę")
        .onAppear {
            if let prayer = prayer {
                name = prayer.name
                text = prayer.text
                symbol = prayer.symbol
                audioFilename = prayer.audioFilename ?? ""
                audioSource = prayer.audioSource ?? .file
                content = prayer.content
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let selectedURL = urls.first {
                    
                    guard selectedURL.startAccessingSecurityScopedResource() else {
                        print("❌ Nie można uzyskać dostępu do wybranego pliku.")
                        return
                    }

                    defer { selectedURL.stopAccessingSecurityScopedResource() }

                    do {
                        let fileManager = FileManager.default
                        let appSupport = try AudioStorage.applicationSupportDirectory(create: true)
                        let destinationName = UUID().uuidString + "." + selectedURL.pathExtension
                        let destinationURL = appSupport.appendingPathComponent(destinationName)
                        try fileManager.copyItem(at: selectedURL, to: destinationURL)

                        audioFilename = destinationURL.lastPathComponent

                    } catch {
                        print("❌ Nie udało się skopiować pliku audio:", error)
                    }
                }
            case .failure(let error):
                print("❌ Błąd importu:", error.localizedDescription)
            }
        }
    }
}
import SwiftUI

struct TextToSpeechGeneratorView: View {
    @Binding var text: String
    @Binding var audioFilename: String 

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔊 Nagranie zostanie wygenerowane na żywo z tekstu modlitwy podczas odtwarzania.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    @Binding var text: String
    @Binding var audioSource: AudioSource
    @Binding var audioFilename: String

    @State private var audioPlayer: AVAudioPlayer?
    @State private var speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        Button("▶️ Odtwórz audio") {
            play()
        }
    }

    private func play() {
        switch audioSource {
        case .file, .recorded:

            do {
                let url = try AudioStorage.applicationSupportDirectory(create: false)
                    .appendingPathComponent(audioFilename)
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
            } catch {
                print("❌ Błąd odtwarzania pliku audio:", error.localizedDescription)
            }

        case .generated:
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "pl-PL")
            utterance.rate = 0.45
            speechSynthesizer.speak(utterance)
        }
    }
}
