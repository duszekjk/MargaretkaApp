codex conversation [unknown] add prayer continuation metadata

Add optional content group, part index, and part count fields to offline
breviary cards. The fields allow an iPad layout to distinguish continuation
pages of one prayer from adjacent pages belonging to different prayers.

Keep the fields optional so existing persisted imports remain decodable and
are never paired without explicit grouping metadata. Full validation follows
after the importer and iPad presentation changes.
