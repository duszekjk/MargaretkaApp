//
//  CzymJestMargaretkaView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 16/08/2025.
//


import SwiftUI

struct CzymJestMargaretkaView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
//                Text("Czym jest „Margaretka”?")
//                    .font(.largeTitle).bold()
//                    .accessibilityAddTraits(.isHeader)

                Text("To modlitwa siedmiu osób za **jednego konkretnego kapłana** – każda osoba obejmuje go modlitwą w wybrany dzień tygodnia. Razem tworzą „stokrotkę” (7 płatków) z kapłanem w środku. Zobowiązanie ma charakter **stały** (długoterminowy).")
                    .font(.body)

                DaisyDiagram()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                Group {
                    Text("Po co?")
                        .font(.title3).bold()
                    Text("Aby otoczyć kapłana wierną, codzienną modlitwą i wsparciem – szczególnie w wierności powołaniu, świętości życia i gorliwości duszpasterskiej.")
                }

                Group {
                    Text("Jak to działa (w skrócie)")
                        .font(.title3).bold()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("7 osób = 7 dni tygodnia. Każda osoba modli się w swoim dniu.", systemImage: "checkmark.circle")
                        Label("Intencja: **konkretny kapłan** (imię i nazwisko).", systemImage: "checkmark.circle")
                        Label("Forma modlitwy: np. dziesiątka różańca, krótka modlitwa własnymi słowami; można dołączyć Komunię św., post, dobre uczynki.", systemImage: "checkmark.circle")
                        Label("Zastępstwo: jeśli nie możesz w danym dniu, postaraj się znaleźć zastępstwo lub odmów modlitwę wcześniej/później.", systemImage: "checkmark.circle")
                    }
                    .font(.body)
                }

                Group {
                    Text("Uwaga")
                        .font(.title3).bold()
                    Text("Praktyka może się nieco różnić w poszczególnych wspólnotach/parafiach – dostosuj do lokalnych zwyczajów. Istota pozostaje ta sama: **stała modlitwa za kapłana**.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Czym jest Margaretka?")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Prosty diagram „stokrotki” – 7 płatków (dni tygodnia) + środek.
struct DaisyDiagram: View {
    private let labels = ["Pn","Wt","Śr","Cz","Pt","So","Nd"]

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                let angle = Angle(degrees: Double(i) * (360.0 / 7.0))
                VStack(spacing: 6) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                        )
                    Text(labels[i])
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                }
                .rotationEffect(angle)
                .offset(y: -70)
                .rotationEffect(-angle) // trzyma etykietę prosto
            }

            Circle()
                .fill(Color.accentColor.opacity(0.25))
                .frame(width: 56, height: 56)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .imageScale(.large)
                        Text("Kapłan")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                )
        }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Diagram Margaretki: siedem płatków – dni tygodnia – wokół kapłana.")
    }
}

#Preview {
    NavigationStack {
        CzymJestMargaretkaView()
    }
}
