# 4.2.0

* Added the state snapshot (`state`, `stateStream`). The three legacy streams
  are now derived from it: single shared streams that support several listeners,
  no longer emit identical consecutive values and do not replay.
  `isPlayingStream` no longer reports `true` while the player waits with
  nothing loaded.
* `dispose()` followed by `initialize()` restores the state updates and the
  lock-screen commands. `dispose()` without a prior `initialize()` no longer
  clears the system now-playing info.
* `play()`, `pause()`, `playOrPause()`, `nextSource()`, `previousSource()` and
  `jumpToSourceAtIndex()` before `initialize()` or after `dispose()` are ignored
  and log a warning. An early `play()` used to take effect once a stream was
  loaded. `setVolume()` before `initialize()` still works.
* The audio session is activated when playback starts, not at plugin
  registration or on `initialize()`, so other apps' audio is not interrupted at
  launch.
* Playback failures are reported in the state (`network` for connectivity
  errors, `unknown` otherwise). A user-initiated `play()` or `playOrPause()`
  after a failure reloads the current source.
* Switching to an invalid source (unparsable URL or one without a scheme) moves
  to that entry, stops the previous stream and reports `invalidSource`.
* `initialize([])` stops the current stream and clears the lock-screen info.
* A source without artwork no longer shows the previous source's artwork, and
  artwork from a slow download no longer lands on a later source.
* After an audio interruption playback resumes only if it was active before.
* Requires `flutter_radio_player_platform_interface` ^4.2.0.

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
