# 4.2.0

* Added the state snapshot (`state`, `stateStream`). The three legacy streams
  are now derived from it: single shared streams that support several listeners,
  no longer emit identical consecutive values and do not replay.
* `dispose()` followed by `initialize()` works repeatedly. The controller and
  the service are created by `initialize()` instead of at engine attach.
  `dispose()` stops the service and the notification and the state returns to
  idle. A `dispose()` issued while `initialize()` is still connecting completes
  quietly.
* `play()`, `pause()`, `playOrPause()`, `nextSource()`, `previousSource()` and
  `jumpToSourceAtIndex()` before `initialize()` or after `dispose()` are ignored
  and log a warning. `setVolume()` is also ignored and logged there; it never
  took effect before, as `initialize()` resets the volume to 0.5.
* `initialize([])` clears the playlist and stops playback, so the state is
  idle. Before, it paused and kept the previous list.
* Playback errors are reported in the state (`network` for connection failures
  and timeouts, `unknown` otherwise). A user-initiated `play()` or
  `playOrPause()` after a failure re-prepares the current source.
* The service builds the notification's content intent from the app's launcher
  intent, which avoids a possible crash when it starts without an Activity.
  Tapping the notification opens the launcher activity (before, the Activity
  that was attached at the time).
* Pauses when headphones are unplugged.
* Requires `flutter_radio_player_platform_interface` ^4.2.0.

# 4.1.0

* Converted all HostApi methods to Pigeon `@async`; replaced ad-hoc pending-ops
  queue with the native Media3 `ListenableFuture<MediaController>` readiness
  gate, dispatched on `ContextCompat.getMainExecutor`. Errors surface as
  `FlutterError` to Dart instead of being swallowed.
* Removed incorrect `Player.STATE_READY -> false` emission that could report
  `isPlaying = false` during a buffer stall mid-playback.
* `VolumeInfo.isMuted` now honestly reflects `volume == 0`.
* Artwork URL detection now checks `http://` / `https://` prefix instead of
  substring `contains("http")`.
* `FlutterLoader` lookup now goes through `FlutterInjector.instance()` singleton
  rather than reinitializing per asset load.
* `dispose()` now also stops the `PlaybackService`.

# 4.0.2

* Bumped Media3 to 1.10.0 (exoplayer, exoplayer-hls, session, common)
* Bumped compileSdk to 36
* Bumped Mockito test dependency to 5.23.0
* Aligned example app Kotlin version to 2.1.20

# 4.0.1

* Dependency updates

# 4.0.0

* Initial release as federated package
