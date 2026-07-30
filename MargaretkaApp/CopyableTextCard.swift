//
//  CopyableTextCard.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 16/08/2025.
//


import SwiftUI

// --- Reusable: karta z łatwym kopiowaniem ---
struct CopyableTextCard: View {
    let title: String
    let text: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3).bold()

            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .textSelection(.enabled) // umożliwia zaznaczanie i ⌘C
                    .font(.body)
                    .lineSpacing(3)

                HStack(spacing: 12) {
                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = text
                        #elseif canImport(AppKit)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        #endif
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label(copied ? "Skopiowano" : "Kopiuj", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)

                    #if os(iOS)
                    ShareLink(item: text) {
                        Label("Udostępnij", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    #endif

                    Spacer()
                }
            }
            .padding()
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                if copied {
                    Label("Skopiowano", systemImage: "checkmark.circle.fill")
                        .padding(8)
                        .background(.thinMaterial, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(6)
                }
            }
        }
    }
}
