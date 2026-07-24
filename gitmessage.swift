codex conversation [20260724-sync] set breviary defaults and window scaling

Set newly generated breviary prayer targets to notify only for Jutrznia and
Nieszpory; other offices start with no notification times. Existing user
customizations remain untouched, and the existing Koronka suggestion remains
15:00.

Replace full-screen UIScreen sizing in PrayerFlowView with the actual window
geometry so iPad Stage Manager/windowed resizing updates card widths and
background sizing instead of clipping or stretching the layout.
