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
        let psalm135 = try #require(office.cards.first(where: { $0.title == "Psalm 135, 1-12" }))
        let psalm136 = try #require(office.cards.first(where: { $0.title == "Psalm 136" }))
        #expect(psalm135.lines.contains { $0.text.hasPrefix("1 ant.") })
        #expect(psalm135.lines.contains { $0.text == "Chwała Boga, który czyni cuda" })
        #expect(!office.cards.contains { $0.title == "Chwała Boga, który czyni cuda" })
        #expect(psalm135.lines.contains { $0.text == "Pierwsza część psalmu." })
        #expect(!psalm135.lines.contains { $0.text == "Treść następnego psalmu." })
        #expect(psalm136.lines.contains { $0.text.hasPrefix("2 ant.") })
        #expect(psalm136.lines.contains { $0.text == "Treść następnego psalmu." })
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
            card.lines.reduce(0) { $0 + $1.text.count } <= 560
        })
        #expect(cards.dropFirst().allSatisfy { $0.title?.hasPrefix("Jutrznia (") == true })
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
