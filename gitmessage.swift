codex conversation [unknown] support current weekly brewiarz EPUB structures

Recognize current brewiarz.pl office anchors that are namespaced with their
document key while retaining the plain anchors used by the February demo.

Import four-digit default-day documents and numbered variants such as w10,
mapping suffix-free documents to the primary variant. Add regression coverage
for namespaced anchors, modern filenames, exclusions, and primary mapping.

Parse shared date, celebration, and liturgical-color metadata once per daily
document instead of repeatedly reparsing the full XHTML for every office.

Add document-progress and ETA calculation plus its intended progress overlay.
The importer remained implicitly main-actor isolated, however, so device use
could freeze the UI and prevent the overlay from visibly updating. The summary
also counted imported variants as days. Preserve the generated localization
catalog entries for that interface pending a follow-up correction.

Validate all seven supplied weekly EPUBs: 185 daily variants imported, none
skipped, all eight offices present in every variant, with choir lines retained.
