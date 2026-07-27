codex conversation [20260727-sync] skip unavailable macOS audio session setup

Keep AVAudioSession routing configuration on iOS and let AVAudioRecorder use
the macOS system audio route without that unavailable session API.
