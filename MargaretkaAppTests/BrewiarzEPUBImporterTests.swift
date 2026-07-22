import Foundation
import Testing
@testable import MargaretkaApp

struct BrewiarzEPUBImporterTests {
    @Test func parsesDatedOfficeChoirsAndCanonicalPrayerReference() throws {
        let xhtml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Poniedziałek, 20 lipca 2026</div>
        <div>ŚW. PRZYKŁADOWEGO PATRONA</div>
        <div>Kolor szat: ZIELONY</div>
        <a id="jt" name="jt"></a>
        <div style="font-weight:bold">Jutrznia</div>
        <div style="text-align:left">
        Lewy chór *<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Prawy chór<br/>
        <span style="color:red">K. </span>Panie, wysłuchaj.<br/>
        <span style="color:red">W. </span>A wołanie nasze niech przyjdzie do Ciebie.<br/>
        Ojcze nasz...<br/>
        </div>
        <a id="m1" name="m1"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/2007p.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))
        #expect(day.date == BreviaryCivilDate(year: 2026, month: 7, day: 20))
        #expect(day.liturgicalColor == "ZIELONY")
        #expect(day.celebrationName == "ŚW. PRZYKŁADOWEGO PATRONA")
        let lines = try #require(day.offices.first(where: { $0.key == .jutrznia }))
            .cards.flatMap(\.lines)
        #expect(lines.contains { $0.role == .choirLeft && $0.text == "Lewy chór *" })
        #expect(lines.contains { $0.role == .choirRight && $0.text == "Prawy chór" })
        #expect(lines.contains { $0.role == .leader })
        #expect(lines.contains { $0.role == .response })
        #expect(lines.contains { $0.role == .prayerReference && $0.canonicalPrayerName == "Ojcze nasz" })
    }

    @Test func parsesNamespacedOfficeAnchorsAndModernDocumentNames() throws {
        let xhtml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Piątek, 4 września 2026</div>
        <div>ŚW. PRZYKŁADOWEGO MĘCZENNIKA</div>
        <div>Kolor szat: BIAŁY</div>
        <a id="d0409w10_jt"></a>
        <div style="font-weight:bold">Jutrznia</div>
        <div style="text-align:left">Lewy chór *<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Prawy chór<br/></div>
        <a id="d0409w10_m1"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/0409w10.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))

        #expect(day.date == BreviaryCivilDate(year: 2026, month: 9, day: 4))
        #expect(day.variantIdentifier == "w10")
        #expect(day.offices.contains { $0.key == .jutrznia })
        #expect(BrewiarzEPUBImporter.isDailyBreviaryDocument("OEBPS/Text/0308.xhtml"))
        #expect(BrewiarzEPUBImporter.isDailyBreviaryDocument("OEBPS/Text/0409w10.xhtml"))
        #expect(!BrewiarzEPUBImporter.isDailyBreviaryDocument("OEBPS/Text/0000_list_epub.xhtml"))
        #expect(!BrewiarzEPUBImporter.isDailyBreviaryDocument("OEBPS/Text/kartka_040926.xhtml"))
    }

    @Test func plainFourDigitDocumentUsesPrimaryVariant() throws {
        let xhtml = """
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Poniedziałek, 3 sierpnia 2026</div>
        <a id="d0308_jt"></a><div>Jutrznia</div><div>Treść modlitwy.</div>
        <a id="d0308_m1"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/0308.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))

        #expect(day.variantIdentifier == "p")
        #expect(day.variantName == "Tekst podstawowy")
    }

    @Test func selectsFirstAvailableVariantForEachDateBeforeParsing() {
        let documents = [
            "OEBPS/Text/1708p.xhtml",
            "OEBPS/Text/1708w1.xhtml",
            "OEBPS/Text/1708w2.xhtml",
            "OEBPS/Text/1808p.xhtml",
            "OEBPS/Text/1808w2.xhtml",
            "OEBPS/Text/1908w2.xhtml",
            "OEBPS/Text/kartka_170826.xhtml"
        ]

        let ownFirst = BrewiarzEPUBImporter.selectedDailyDocuments(
            from: documents,
            preferenceOrder: ["w2", "w1", "p"]
        )
        let primaryFallback = BrewiarzEPUBImporter.selectedDailyDocuments(
            from: documents,
            preferenceOrder: ["w1", "p", "w2"]
        )

        #expect(ownFirst == [
            "OEBPS/Text/1708w2.xhtml",
            "OEBPS/Text/1808w2.xhtml",
            "OEBPS/Text/1908w2.xhtml"
        ])
        #expect(primaryFallback == [
            "OEBPS/Text/1708w1.xhtml",
            "OEBPS/Text/1808p.xhtml",
            "OEBPS/Text/1908w2.xhtml"
        ])
    }

    @Test func progressEstimatesRemainingDocumentsFromMeasuredAverage() {
        let progress = BrewiarzEPUBImportProgress(
            completedDocuments: 3,
            totalDocuments: 9,
            elapsed: 12
        )

        #expect(progress.fractionCompleted == 1.0 / 3.0)
        #expect(progress.estimatedRemaining == 24)
        #expect(BrewiarzEPUBImportProgress(
            completedDocuments: 0,
            totalDocuments: 9,
            elapsed: 0
        ).estimatedRemaining == nil)
    }

    @Test func separatesPsalmPrayersReusesCanonicalPrayerAndDropsLinks() throws {
        let xhtml = """
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Poniedziałek, 20 lipca 2026</div>
        <a id="d2007p_jt"></a>
        <div><b>Jutrznia</b></div>
        <div style="text-align:left">
        <div><a href="kartka.xhtml">KARTKA Z KALENDARZA NA DZISIAJ</a></div>
        <div><span style="color:red"><b>PSALMODIA</b></span></div>
        <div><span style="color:red">1 ant. </span>Wysławiajcie Pana.</div>
        <div style="text-align:center"><span style="color:red"><b>Psalm 135, 1-12</b><br/><b>Chwała Boga, który czyni cuda</b></span></div>
        <div>Pierwsza część psalmu.<br/>Drugi werset psalmu.</div>
        <div><span style="color:red">Ant. </span>Wysławiajcie Pana.</div>
        <div><span style="color:red">2 ant. </span>Miłosierdzie Pana trwa na wieki.</div>
        <div style="text-align:center"><span style="color:red"><b>Psalm 136</b><br/><b>Hymn paschalny</b></span></div>
        <div>Treść następnego psalmu.</div>
        <div><span style="color:red"><b>CZYTANIE (Rz 8, 1)</b></span></div>
        <div>Treść czytania.</div>
        <div><span style="color:red"><b>RESPONSORIUM KRÓTKIE</b></span></div>
        <div>Treść responsorium.</div>
        <div><span style="color:red"><b>PROŚBY</b></span></div>
        <div>Treść próśb.</div>
        <div>Ojcze nasz, któryś jest w niebie,<br/>święć się imię Twoje;<br/>ale nas zbaw ode złego. Amen.</div>
        <div><span style="color:red"><b>MODLITWA</b></span></div>
        <div>Treść modlitwy końcowej.</div>
        <div>Modlitwa przedpołudniowa</div>
        <div><a href="#d2007p_m1">MODL. PRZEDPOŁUDNIOWA | DZISIAJ | JUTRO</a></div>
        </div>
        <a id="d2007p_m1"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/2007p.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))
        let office = try #require(day.offices.first(where: { $0.key == .jutrznia }))
        let psalm135GroupID = try #require(office.cards.first(where: {
            $0.title == "Psalm 135, 1-12"
        })?.contentGroupID)
        let psalm136GroupID = try #require(office.cards.first(where: {
            $0.title == "Psalm 136"
        })?.contentGroupID)
        let psalm135Cards = office.cards.filter { $0.contentGroupID == psalm135GroupID }
        let psalm136Cards = office.cards.filter { $0.contentGroupID == psalm136GroupID }
        #expect(psalm135Cards.count == 2)
        #expect(psalm136Cards.count == 2)
        #expect(psalm135GroupID != psalm136GroupID)
        #expect(psalm135Cards.allSatisfy { $0.contentGroupID == psalm135GroupID })
        #expect(psalm136Cards.allSatisfy { $0.contentGroupID == psalm136GroupID })
        #expect(psalm135Cards.map(\.partIndex) == [0, 1])
        #expect(psalm136Cards.map(\.partIndex) == [0, 1])
        let psalm135Lines = psalm135Cards.flatMap(\.lines)
        let psalm136Lines = psalm136Cards.flatMap(\.lines)
        #expect(office.cards.flatMap(\.lines).contains { $0.text.hasPrefix("1 ant.") })
        #expect(office.cards.flatMap(\.lines).contains { $0.text.hasPrefix("2 ant.") })
        #expect(psalm135Lines.contains { $0.text == "Pierwsza część psalmu." })
        #expect(!psalm135Lines.contains { $0.text == "Treść następnego psalmu." })
        #expect(psalm136Lines.contains { $0.text == "Hymn paschalny" })
        #expect(psalm136Lines.contains { $0.text == "Treść następnego psalmu." })
        #expect(office.cards.contains { $0.title == "CZYTANIE (Rz 8, 1)" })
        #expect(office.cards.contains { $0.title == "RESPONSORIUM KRÓTKIE" })
        #expect(office.cards.contains { $0.title == "PROŚBY" })
        #expect(office.cards.contains { $0.title == "MODLITWA" })
        #expect(!office.cards.flatMap(\.lines).contains { $0.text == "Modlitwa przedpołudniowa" })
        #expect(office.cards.contains { card in
            card.lines.count == 1 && card.lines[0].canonicalPrayerName == "Ojcze nasz"
        })
        #expect(!office.cards.flatMap(\.lines).contains { line in
            line.text.localizedCaseInsensitiveContains("kartka z kalendarza")
                || line.text.localizedCaseInsensitiveContains("jutro")
        })
    }

    @Test func dropsRubricsAndPsalmCommentaryWithoutDroppingPrayerResponses() throws {
        let xhtml = """
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Poniedziałek, 17 sierpnia 2026</div>
        <a id="d1708p_jt"></a>
        <div><b>Jutrznia</b></div>
        <div style="text-align:left">
        <span style="color:red">Powyższe teksty opuszcza się, jeśli tę Godzinę poprzedza Wezwanie.</span><br/>
        <span style="color:red">K. </span>Panie, wysłuchaj.<br/>
        </div>
        <div style="text-align:center"><span style="color:red"><b>Psalm 90</b><br/><b>Bóg nadzieją człowieka</b></span></div>
        <div><i>Jeden dzień u Pana jest jak tysiąc lat, a tysiąc lat jak jeden dzień</i> (2 P 3, 8)<br/></div>
        <div style="text-align:left">Kto mieszka pod osłoną Najwyższego, *<br/>mówi do Pana: Tyś moją ucieczką.</div>
        <div><b>PROŚBY</b></div>
        <div><i>Wysłuchaj nas, Panie.</i><br/>Otaczaj opieką swój lud.</div>
        <a id="d1708p_m1"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/1708p.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))
        let lines = try #require(day.offices.first(where: { $0.key == .jutrznia }))
            .cards.flatMap(\.lines)

        #expect(!lines.contains { $0.text.contains("Powyższe teksty") })
        #expect(!lines.contains { $0.text.contains("Jeden dzień u Pana") })
        #expect(!lines.contains { $0.text == "Bóg nadzieją człowieka" })
        #expect(lines.contains { $0.role == .leader && $0.text == "K. Panie, wysłuchaj." })
        #expect(lines.contains { $0.text == "Kto mieszka pod osłoną Najwyższego, *" })
        #expect(lines.contains { $0.italic && $0.text == "Wysłuchaj nas, Panie." })
    }

    @Test func keepsCompleteIntercessionsTogetherWithTwoOrThreePerCard() throws {
        let xhtml = """
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Środa, 22 lipca 2026</div>
        <a id="d2207p_jt"></a>
        <div><b>Jutrznia</b></div>
        <div><b>PROŚBY</b></div>
        <div>Uwielbiajmy naszego Zbawiciela i wołajmy do Niego:</div>
        <div>Przyjdź, Panie Jezu.</div>
        <div>Pierwsza prośba do Chrystusa,</div>
        <div><b>- pierwsze dopełnienie.</b></div>
        <div>Przyjdź, Panie Jezu.</div>
        <div>Druga prośba do Chrystusa,</div>
        <div><b>- drugie dopełnienie.</b></div>
        <div>Przyjdź, Panie Jezu.</div>
        <div>Trzecia prośba do Chrystusa,</div>
        <div><b>- trzecie dopełnienie.</b></div>
        <div>Przyjdź, Panie Jezu.</div>
        <div>Czwarta prośba do Chrystusa,</div>
        <div><b>- czwarte dopełnienie.</b></div>
        <div>Przyjdź, Panie Jezu.</div>
        <div>Piąta prośba do Chrystusa,</div>
        <div><b>- piąte dopełnienie.</b></div>
        <div>Przyjdź, Panie Jezu.</div>
        <div><b>MODLITWA</b></div>
        <div>Treść modlitwy końcowej.</div>
        <a id="d2207p_m1"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/2207p.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))
        let office = try #require(day.offices.first(where: { $0.key == .jutrznia }))
        let cards = office.cards
            .filter { $0.title?.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "pl_PL")
            ).hasPrefix("prosby") == true }

        #expect(cards.count == 2)
        #expect(cards.map { card in
            card.lines.count(where: { $0.text.hasPrefix("-") })
        } == [3, 2])
        #expect(cards.allSatisfy { card in
            !card.lines.contains { $0.text.hasPrefix("-") && $0.role == .heading }
        })
        let intercessionGroupID = try #require(cards.first?.contentGroupID)
        #expect(cards.allSatisfy { $0.contentGroupID == intercessionGroupID })
        #expect(cards.map(\.partIndex) == [1, 2])
        #expect(cards.allSatisfy { $0.partCount == 2 })
        let finalPrayer = try #require(office.cards.first { card in
            card.title?.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "pl_PL")
            ) == "modlitwa"
        })
        #expect(finalPrayer.contentGroupID != intercessionGroupID)

        let expectedPairs = [
            (lead: "Pierwsza", continuation: "pierwsze"),
            (lead: "Druga", continuation: "drugie"),
            (lead: "Trzecia", continuation: "trzecie"),
            (lead: "Czwarta", continuation: "czwarte"),
            (lead: "Piąta", continuation: "piąte")
        ]
        for expected in expectedPairs {
            let matchingCards = cards.filter { card in
                card.lines.contains { $0.text.hasPrefix("\(expected.lead) prośba") }
            }
            let card = try #require(matchingCards.first)
            #expect(matchingCards.count == 1)
            #expect(card.lines.contains { line in
                line.text.hasPrefix("-") && line.text.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: Locale(identifier: "pl_PL")
                ).contains(expected.continuation.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: Locale(identifier: "pl_PL")
                ))
            })
        }
    }

    @Test func pairsOnlySequentialPartsOfTheSamePrayerOnIPad() {
        let prayerID = UUID()
        let otherPrayerID = UUID()
        let firstGroupID = UUID()
        let secondGroupID = UUID()
        let steps = [
            PrayerFlowStep(
                prayerID: prayerID,
                offlineCard: OfflineBreviaryCard(
                    lines: [.init(role: .body, text: "1")],
                    contentGroupID: firstGroupID,
                    partIndex: 1,
                    partCount: 3
                )
            ),
            PrayerFlowStep(
                prayerID: prayerID,
                offlineCard: OfflineBreviaryCard(
                    lines: [.init(role: .body, text: "2")],
                    contentGroupID: firstGroupID,
                    partIndex: 2,
                    partCount: 3
                )
            ),
            PrayerFlowStep(
                prayerID: prayerID,
                offlineCard: OfflineBreviaryCard(
                    lines: [.init(role: .body, text: "3")],
                    contentGroupID: firstGroupID,
                    partIndex: 3,
                    partCount: 3
                )
            ),
            PrayerFlowStep(
                prayerID: prayerID,
                offlineCard: OfflineBreviaryCard(
                    lines: [.init(role: .body, text: "A")],
                    contentGroupID: secondGroupID,
                    partIndex: 1,
                    partCount: 2
                )
            ),
            PrayerFlowStep(
                prayerID: otherPrayerID,
                offlineCard: OfflineBreviaryCard(
                    lines: [.init(role: .body, text: "B")],
                    contentGroupID: secondGroupID,
                    partIndex: 2,
                    partCount: 2
                )
            )
        ]

        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 0,
            steps: steps,
            enabled: true
        ) == [0, 1])
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 1,
            steps: steps,
            enabled: true
        ) == [0, 1])
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 2,
            steps: steps,
            enabled: true
        ) == [2])
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 3,
            steps: steps,
            enabled: true
        ) == [3])
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 0,
            steps: steps,
            enabled: false
        ) == [0])
    }

    @Test func decodesCardsStoredBeforeContinuationMetadataWasAdded() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "title": "Psalm 1",
          "lines": [{
            "id": "00000000-0000-0000-0000-000000000002",
            "role": "body",
            "text": "Treść",
            "emphasized": false,
            "italic": false
          }]
        }
        """

        let card = try JSONDecoder().decode(
            OfflineBreviaryCard.self,
            from: try #require(json.data(using: .utf8))
        )
        #expect(card.contentGroupID == nil)
        #expect(card.partIndex == nil)
        #expect(card.partCount == nil)
    }

    @Test func importsSaintBiographyAsDatedPaginatedContent() throws {
        let biography = Array(repeating: "Jacek podejmował wyprawy misyjne i wiernie służył Kościołowi.", count: 12)
            .joined(separator: " ")
        let xhtml = """
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Poniedziałek, 17 sierpnia 2026</div>
        <div>ŚW. JACKA, PREZBITERA</div>
        <div><b>Garść informacji:</b><br/><br/>
        \(biography)<br/><br/><br/></div>
        <div><b>Teksty Mszy św.</b></div>
        <a id="d1708p_jt"></a><div><b>Jutrznia</b></div><div>Treść modlitwy.</div>
        <a id="d1708p_m1"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/1708p.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))
        let saint = try #require(day.saintBiography)

        #expect(saint.title == "ŚW. JACKA, PREZBITERA")
        #expect(!saint.cards.isEmpty)
        #expect(saint.text.contains("wyprawy misyjne"))
        #expect(!saint.text.contains("Garść informacji"))
        #expect(!saint.text.contains("Teksty Mszy"))
        #expect(saint.cards.allSatisfy { card in
            card.lines.reduce(0) { $0 + $1.text.count } <= 1024
        })
    }

    @Test @MainActor func saintBiographyCreatesOneComplexPrayerAndNativeCards() throws {
        let prayer = Prayer(
            name: "Święty dnia",
            text: "Życiorys świętego z brewiarz.pl",
            symbol: "person.crop.circle.badge.checkmark",
            audioFilename: nil,
            audioSource: nil,
            timestampedLines: nil,
            content: .saintBiography
        )
        let biography = OfflineSaintBiography(
            title: "ŚW. JACKA, PREZBITERA",
            cards: [
                OfflineBreviaryCard(
                    title: "ŚW. JACKA, PREZBITERA",
                    lines: [.init(role: .body, text: "Jacek urodził się w Kamieniu na Śląsku.")]
                )
            ]
        )
        let day = OfflineBreviaryDay(
            date: .init(year: 2026, month: 8, day: 17),
            variantIdentifier: "p",
            variantName: "Tekst podstawowy",
            saintBiography: biography,
            offices: [],
            sourceImportID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        )

        let targets = BreviaryPrayerTargetFactory.missingTargets(
            for: [day],
            prayers: [prayer],
            existingTargets: []
        )
        let target = try #require(targets.first(where: { $0.displayName == "Święty dnia" }))
        let steps = PrayerFlowStepBuilder.makeSteps(
            assignedPrayerIDs: [prayer.id],
            prayersByID: [prayer.id: prayer],
            offlineOffices: [:],
            saintBiography: biography
        )

        #expect(target.category == .prayer)
        #expect(steps.count == 1)
        #expect(steps[0].offlineCard?.lines.first?.text.contains("Jacek urodził się") == true)
    }

    @Test @MainActor func offlineCardsBecomeExistingPrayerFlowSteps() throws {
        let breviaryID = UUID()
        let ourFatherID = UUID()
        let breviary = Prayer(
            id: breviaryID,
            name: "Jutrznia",
            text: "Modlitwa w brewiarz.pl",
            symbol: "sunrise",
            audioFilename: nil,
            audioSource: nil,
            timestampedLines: nil,
            content: .brewiarz(.jutrznia)
        )
        let ourFather = Prayer(
            id: ourFatherID,
            name: "Ojcze Nasz",
            text: "Ojcze nasz...",
            symbol: "book",
            audioFilename: nil,
            audioSource: nil,
            timestampedLines: nil
        )
        let psalmCard = OfflineBreviaryCard(
            title: "Psalm 135, 1-12",
            lines: [.init(role: .heading, text: "Psalm 135, 1-12")]
        )
        let referenceCard = OfflineBreviaryCard(
            title: "Ojcze nasz",
            lines: [.init(role: .prayerReference, text: "Ojcze nasz", canonicalPrayerName: "Ojcze nasz")]
        )
        let office = OfflineBreviaryOffice(
            key: .jutrznia,
            cards: [psalmCard, referenceCard],
            contentFingerprint: "fixture"
        )

        let steps = PrayerFlowStepBuilder.makeSteps(
            assignedPrayerIDs: [breviaryID],
            prayersByID: [breviaryID: breviary, ourFatherID: ourFather],
            offlineOffices: [.jutrznia: office]
        )

        #expect(steps.count == 2)
        #expect(steps[0].offlineCard?.title == "Psalm 135, 1-12")
        #expect(steps[1].prayerID == ourFatherID)
        #expect(steps[1].offlineCard == nil)
    }

    @Test func importSummaryDistinguishesDatesFromVariants() {
        let report = BackupImportReport(
            prayersAdded: 0,
            targetsAdded: 0,
            sessionsAdded: 0,
            breviaryDatesAdded: 7,
            breviaryVariantsAdded: 31
        )

        #expect(report.summary.contains("7 dni kalendarzowych"))
        #expect(report.summary.contains("31 wariantów dziennych"))
    }

    @Test func splitsSingleOversizedSourceParagraphIntoCardsThatFitTheFlow() throws {
        let longParagraph = Array(repeating: "Dłuższy fragment modlitwy", count: 90).joined(separator: " ")
        let xhtml = """
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Poniedziałek, 20 lipca 2026</div>
        <a id="d2007p_jt"></a>
        <div><b>Jutrznia</b></div>
        <div>\(longParagraph)</div>
        <a id="d2007p_m1"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/2007p.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))
        let cards = try #require(day.offices.first(where: { $0.key == .jutrznia }))
            .cards

        #expect(cards.count > 2)
        #expect(cards.allSatisfy { card in
            card.lines.reduce(0) { $0 + $1.text.count } <= 1024
        })
        #expect(cards.dropFirst().allSatisfy { $0.title?.hasPrefix("Jutrznia (") == true })
    }

    @Test func keepsPsalmHeadingWithFirstPartAndPairsAllFourContentParts() throws {
        let sentences = (1...4).map { number in
            Array(repeating: "Fragment\(number)", count: 52).joined(separator: " ") + "."
        }
        let xhtml = """
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Poniedziałek, 20 lipca 2026</div>
        <a id="d2007p_jt"></a>
        <div><b>Jutrznia</b></div>
        <div><span style="color:red">1 ant. </span>Pan jest blisko.</div>
        <div style="text-align:center"><span style="color:red"><b>Psalm 1</b></span></div>
        <div>\(sentences.joined(separator: " "))</div>
        <a id="d2007p_m1"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/2007p.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))
        let office = try #require(day.offices.first(where: { $0.key == .jutrznia }))
        let cards = office.cards.filter { $0.contentGroupID != nil && $0.title?.hasPrefix("Psalm 1") == true }
        let headingCard = try #require(cards.first)
        let contentCards = cards.filter { ($0.partIndex ?? 0) > 0 }

        #expect(cards.count == 4)
        #expect(headingCard.lines.first?.text == "Psalm 1")
        #expect(headingCard.partIndex == 1)
        #expect(contentCards.count == 4)
        #expect(contentCards.first?.lines.contains { $0.text.hasPrefix("Fragment1") } == true)
        #expect(contentCards.map(\.partIndex) == [1, 2, 3, 4])

        let prayerID = UUID()
        let steps = cards.map { PrayerFlowStep(prayerID: prayerID, offlineCard: $0) }
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 0,
            steps: steps,
            enabled: true
        ) == [0, 1])
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 1,
            steps: steps,
            enabled: true
        ) == [0, 1])
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 2,
            steps: steps,
            enabled: true
        ) == [2, 3])
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 0,
            steps: steps,
            enabled: false
        ) == [0])
    }

    @Test func splitsReadingsAtSentenceBoundariesAndAvoidsOneWordLastCard() throws {
        let longSentence = Array(repeating: "słowo", count: 171).joined(separator: " ") + "."
        let secondSentence = Array(repeating: "drugie", count: 60).joined(separator: " ") + "."
        let xhtml = """
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Poniedziałek, 20 lipca 2026</div>
        <a id="d2007p_gc"></a>
        <div><b>Godzina Czytań</b></div>
        <div><b>CZYTANIE PIERWSZE</b></div>
        <div>\(longSentence) \(secondSentence)</div>
        <a id="d2007p_jt"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/2007p.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))
        let office = try #require(day.offices.first(where: { $0.key == .godzinaCzytan }))
        let readingCards = office.cards.filter { $0.title?.hasPrefix("CZYTANIE PIERWSZE") == true }
        let bodyLines = readingCards.flatMap(\.lines).filter { $0.role != .heading }

        #expect(readingCards.count >= 3)
        #expect(bodyLines.last?.text == secondSentence)
        #expect(bodyLines.allSatisfy { line in
            line.text.split(whereSeparator: { $0.isWhitespace }).count > 1
        })
        #expect(bodyLines.filter { $0.text.hasSuffix(".") }.count >= 2)
    }

    @Test func groupsOrdinalFirstReadingPagesForIPadPairing() throws {
        let paragraphs = (1...4).map { number in
            Array(repeating: "Czytanie\(number)", count: 82).joined(separator: " ") + "."
        }
        let xhtml = """
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <div>Poniedziałek, 20 lipca 2026</div>
        <a id="d2007p_gc"></a>
        <div><b>Godzina Czytań</b></div>
        <div><b>PIERWSZE CZYTANIE</b></div>
        <div>Iz 1, 1-20</div>
        <div>\(paragraphs.joined(separator: " "))</div>
        <div><b>RESPONSORIUM</b></div>
        <div>Osobna treść responsorium.</div>
        <a id="d2007p_jt"></a>
        </body></html>
        """

        let day = try #require(BrewiarzEPUBImporter.parseDailyDocument(
            xhtml,
            entryName: "OEBPS/Text/2007p.xhtml",
            importID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        ))
        let office = try #require(day.offices.first(where: { $0.key == .godzinaCzytan }))
        let headingCard = try #require(office.cards.first(where: {
            $0.lines.contains { $0.text == "PIERWSZE CZYTANIE" }
        }))
        let readingGroupID = try #require(headingCard.contentGroupID)
        let readingCards = office.cards.filter { $0.contentGroupID == readingGroupID }

        #expect(readingCards.count == 4)
        #expect(readingCards.map(\.partIndex) == [1, 2, 3, 4])
        #expect(readingCards.allSatisfy { $0.partCount == 4 })
        #expect(office.cards.first(where: {
            $0.title?.hasPrefix("RESPONSORIUM") == true
        })?.contentGroupID != readingGroupID)

        let prayerID = UUID()
        let steps = readingCards.map { PrayerFlowStep(prayerID: prayerID, offlineCard: $0) }
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 0,
            steps: steps,
            enabled: true
        ) == [0, 1])
        #expect(PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: 2,
            steps: steps,
            enabled: true
        ) == [2, 3])
    }

    @Test @MainActor func createsEveryImportedOfficeAsAComplexPrayerWithoutReplacingExistingJutrznia() throws {
        let prayers = BrewiarzPrayerKey.allCases.map { key in
            Prayer(
                name: key.displayName,
                text: "Modlitwa w brewiarz.pl",
                symbol: "globe.europe.africa",
                audioFilename: nil,
                audioSource: nil,
                timestampedLines: nil,
                content: .brewiarz(key)
            )
        }
        let jutrzniaPrayer = try #require(prayers.first(where: {
            if case .brewiarz(.jutrznia) = $0.content { return true }
            return false
        }))
        let existingJutrznia = Priest(
            id: UUID(),
            firstName: "Moja Jutrznia",
            lastName: "",
            title: "",
            category: .prayer,
            photoData: Data([1, 2, 3]),
            assignedPrayerGroups: [
                AssignedPrayerGroup(id: UUID(), prayerIds: [jutrzniaPrayer.id], repeatCount: 1)
            ],
            schedule: .suggested(forPrayerName: "Jutrznia"),
            lastModified: .now,
            notificationTitle: "Jutrznia",
            notificationMessage: ""
        )
        let offices = BrewiarzPrayerKey.allCases.map {
            OfflineBreviaryOffice(
                key: $0,
                cards: [.init(lines: [.init(role: .body, text: "Treść")])],
                contentFingerprint: $0.id
            )
        }
        let day = OfflineBreviaryDay(
            date: BreviaryCivilDate(year: 2026, month: 7, day: 20),
            variantIdentifier: "p",
            variantName: "Tekst podstawowy",
            offices: offices,
            sourceImportID: UUID(),
            sourceIdentifier: "fixture.epub",
            sourceTitle: "fixture"
        )

        let missing = BreviaryPrayerTargetFactory.missingTargets(
            for: [day],
            prayers: prayers,
            existingTargets: [existingJutrznia]
        )

        #expect(missing.count == BrewiarzPrayerKey.allCases.count - 1)
        #expect(!missing.contains { $0.displayName == "Jutrznia" })
        #expect(Set(missing.map(\.displayName)).contains("Kompleta"))
        #expect(Set(missing.map(\.displayName)).contains("Nieszpory"))
    }
}
