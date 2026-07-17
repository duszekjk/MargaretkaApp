prevent competing launch saves from freezing the app

Stop PriestStore from saving data merely because launch loaded it, and skip the
notification-ID publication and save when rescheduling produced no changes.
Publish changed IDs once instead of mutating every array element individually,
save immutable snapshots, and serialize LocalDatabase reads and writes. Add
regressions for unchanged notification IDs and concurrent database writes.

Validated with a successful iOS app build and 26 passing unit tests on the
connected iPhone. The device test host launched past the former freeze point
without redundant priest_sch saves.
