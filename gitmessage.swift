codex conversation [20260724-sync] defer startup synchronization

Start the initial synchronization one second after the first screen appears
instead of launching network and data work during scene activation. Keep local
change-triggered synchronization immediate after startup.
