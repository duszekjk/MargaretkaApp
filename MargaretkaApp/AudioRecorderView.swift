//
//  AudioRecorderView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//
import SwiftUI
internal import UniformTypeIdentifiers
import AVFoundation

struct AudioRecorderView: View {
    @Binding var audioFilename: String
    @State private var recording = false
    @State private var recorder: AVAudioRecorder?

    var body: some View {
        VStack(alignment: .leading) {
            Button(recording ? "Zatrzymaj nagrywanie" : "Rozpocznij nagrywanie") {
                recording ? stopRecording() : startRecording()
            }
            if !audioFilename.isEmpty {
                Text("Zapisano jako: \(audioFilename)")
            }
        }
    }

    func startRecording() {
        let filename = UUID().uuidString + ".m4a"
        let url = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(filename)
        

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothA2DP]
            )



            try session.setActive(true)
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            audioFilename = filename
            recording = true
        } catch {
            print("Recording failed")
        }
    }

    func stopRecording() {
        recorder?.stop()
        recording = false
    }
}
