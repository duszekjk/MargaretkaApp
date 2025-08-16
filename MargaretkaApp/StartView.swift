//
//  StartView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 16/08/2025.
//
import SwiftUI
struct StartView: View {
    @Binding var showSettings: Bool
    @Binding var showEditor: Bool
    @Binding var showOsoby: Bool
    @Binding var showCzymJest: Bool
    @Binding var showJakSie: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Modlitwa Margaretka")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("Wspieraj duchowo kapłanów\nprzez codzienną modlitwę.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 20) {
                    BigActionButton(
                        title: "Dodaj osobę\ndo modlitwy",
                        systemImage: "plus.circle.fill",
                        style: .prominent
                    ) {
                        showEditor = true
                        showOsoby = true
                        showSettings = true
                    }

                    BigActionButton(
                        title: "Czym jest\nMargaretka?",
                        systemImage: "questionmark.circle",
                        style: .bordered
                    ) {
                        showCzymJest = true
                        showSettings = true
                    }

                    BigActionButton(
                        title: "Jak się\nmodlić?",
                        systemImage: "hands.sparkles",
                        style: .bordered
                    ) {
                        showJakSie = true
                        showSettings = true
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("© 2025 DUSZEKJK Jacek Kałużny")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
//            .background(Color(.systemGroupedBackground))
            .edgesIgnoringSafeArea(.all)
        }
    }
}
enum ActionButtonStyle {
    case prominent, bordered
}

struct BigActionButton: View {
    let title: String
    let systemImage: String
    let style: ActionButtonStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .semibold))
                Text(title)
                    .multilineTextAlignment(.center)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        }
        .modifier(ButtonStyling(style: style))
    }
}

/// Custom button style modifier for compatibility
struct ButtonStyling: ViewModifier {
    let style: ActionButtonStyle

    func body(content: Content) -> some View {
        switch style {
        case .prominent:
            content
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        case .bordered:
            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 2)
                )
                .foregroundColor(Color.accentColor)
        }
    }
}

