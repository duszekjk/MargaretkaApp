//
//  JakSieModlicView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 16/08/2025.
//


import SwiftUI

struct JakSieModlicView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
//                Text("Jak się modlić w Margaretce?")
//                    .font(.largeTitle).bold()
//                    .accessibilityAddTraits(.isHeader)

                Group {
                    Text("Kroki startowe")
                        .font(.title3).bold()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Wybierz kapłana (imię i nazwisko).", systemImage: "list.bullet")
                        Label("Zbierz 7 osób i przydziel dni tygodnia.", systemImage: "list.bullet")
                        Label("Zapisz imiona, dzień i datę rozpoczęcia.", systemImage: "list.bullet")
                        Label("Ustalcie formę modlitwy (minimum poniżej).", systemImage: "list.bullet")
                    }
                }

                Group {
                    Text("Codzienna propozycja (minimum)")
                        .font(.title3).bold()
                    VStack(alignment: .leading, spacing: 8) {
                        bullet("Znak krzyża.")
                        bullet("Intencja: „Panie Jezu, przyjmij tę modlitwę w intencji ks. N.”")
                        bullet("Dziesiątka różańca **lub** krótka modlitwa własnymi słowami.")
                        bullet("Wezwanie: „Jezu, Kapłanie Wieczny, umacniaj go w wierności i świętości.”")
                        bullet("Amen.")
                    }
                }

                Group {
                    CopyableTextCard(title: "Gotowy tekst modlitwy", 
                                     text: """
Panie Jezu, Dobry Pasterzu, proszę Cię za kapłanem **N.**.
Umacniaj go w wierze, nadziei i miłości. Strzeż jego serca,
obdarzaj gorliwością w posłudze i odnawiaj w nim łaskę święceń.
Maryjo, Matko Kapłanów, otaczaj go swoją opieką. Amen.
""")
                    .font(.body)
                    .padding()
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                }

                Group {
                    Text("Można dołączyć (opcjonalnie)")
                        .font(.title3).bold()
                    VStack(alignment: .leading, spacing: 8) {
                        bullet("Ofiarowanie Komunii św. w intencji kapłana.")
                        bullet("Post lub drobny uczynek miłosierdzia.")
                        bullet("Krótka Litania / modlitwa do Maryi.")
                    }
                }

                Group {
                    Text("Praktyczne wskazówki")
                        .font(.title3).bold()
                    VStack(alignment: .leading, spacing: 8) {
                        bullet("Ustaw przypomnienie w aplikacji w „swoim” dniu.")
                        bullet("Gdy wypadniesz – postaraj się o zastępstwo albo odmów w najbliższym możliwym czasie.")
                        bullet("Nawet gdy kapłan zmieni parafię – dalej obejmuj go modlitwą.")
                    }
                }

                Text("W razie lokalnych zwyczajów/parafialnych wytycznych – dostosuj formę, zachowując sens: **stała modlitwa za kapłana**.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Jak się modlić?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 6))
            Text(text)
        }
    }
}

#Preview {
    NavigationStack {
        JakSieModlicView()
    }
}
