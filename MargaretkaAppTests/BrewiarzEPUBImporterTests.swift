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
}
