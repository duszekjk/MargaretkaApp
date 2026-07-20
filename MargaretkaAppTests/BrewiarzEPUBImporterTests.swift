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
}
