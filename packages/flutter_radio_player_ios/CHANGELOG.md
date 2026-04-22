# 4.1.0

* HostApi methods converted to Pigeon `@async`; iOS completion callbacks wired up.
* Fixed `onPlaybackStateChanged` reporting `false` during buffer stalls mid-playback
  (now uses `timeControlStatus != .paused`). `MPNowPlayingInfoPropertyPlaybackRate`
  still tracks the precise `.playing` state for lock-screen accuracy.
* `dispose()` now removes `AVAudioSession` interruption/route-change observers and
  deactivates the audio session with `.notifyOthersOnDeactivation` so other audio
  apps can resume.
* `initialize()` now re-attaches notification observers, supporting
  dispose-then-reinitialize cycles.

# 4.0.2

* Added Swift Package Manager support

# 4.0.1

* Dependency updates

# 4.0.0

* Initial release as federated package
