# 4.2.0

* Added `FlutterRadioPlayer.instance`, `state` and `stateStream`. The state
  holds the playback status (idle, loading, playing, paused, error), the current
  index and source, the now-playing title, the volume and the pending error. A
  new `stateStream` listener first receives the latest state, then live updates.
  `state` is eventually consistent: it reflects the last update received from
  the platform, not the result of the last call. `FlutterRadioPlayer()` still
  works, but every instance drives the same native player. No existing API was
  removed, renamed or changed in meaning.
* Added `RadioPlayerState`, `PlaybackStatus`, `RadioPlayerError` and
  `RadioPlayerErrorCode`. Android emits the error codes `network` and
  `unknown`; iOS emits `invalidSource`, `network` and `unknown`. The remaining
  codes are reserved and are not emitted in 4.x.
* Playback errors are now reported: the state moves to `error` and
  `state.error` holds the code and a message. There is no automatic retry. A
  user-initiated `play()` or `playOrPause()` after a failure retries the current
  source; switching source or calling `initialize()` also clears the error.
* `isPlayingStream`, `nowPlayingStream` and `volumeStream` are now derived from
  the state. They are single shared streams, so several listeners at once work.
  They no longer emit the same value twice in a row and, as before, they do not
  replay the latest value to new listeners. They keep their per-platform
  meaning (on iOS `isPlayingStream` is `true` while buffering, on Android only
  while audio is playing).
* `dispose()` followed by `initialize()` now works repeatedly on both platforms.
* `play()`, `pause()`, `playOrPause()`, `nextSource()`, `previousSource()` and
  `jumpToSourceAtIndex()` called before `initialize()` or after `dispose()` are
  ignored and now log a warning. `initialize()` does not need to be awaited
  before the next call.
* Android: the playback controller and service are created by `initialize()`
  instead of when the plugin attaches to the engine.
* Android: `dispose()` stops the playback service and the notification, and the
  state returns to idle. A `dispose()` issued while `initialize()` is still
  connecting completes quietly.
* Android: the notification's content intent is now built in the service from
  the app's launcher intent, so tapping the notification opens the launcher
  activity (before, the Activity that was attached at the time). This avoids a
  possible crash when the service starts without an Activity.
* Android: playback pauses when headphones are unplugged (iOS already did).
* Android: `setVolume()` before `initialize()` is ignored and logged. It never
  took effect before either, because `initialize()` resets the volume to 0.5.
* iOS: the audio session is no longer activated when the plugin registers or on
  `initialize()`, only when playback starts, so other apps' audio is not
  interrupted at launch.
* iOS: `dispose()` followed by `initialize()` restores state updates and the
  lock-screen controls.
* iOS: `play()` before `initialize()` used to take effect once a stream was
  loaded; it is now ignored. `setVolume()` before `initialize()` still works.
* iOS: a source without artwork no longer shows the previous source's artwork,
  and artwork from a slow download no longer lands on a later source.
* iOS: after an audio interruption (call, Siri) playback resumes only if it was
  active before the interruption.
* iOS: switching to an invalid source (unparsable URL or one without a scheme)
  moves to that entry, stops the previous stream and reports `invalidSource`
  instead of silently continuing the old stream.
* `initialize([])` leaves the player with no sources: the current stream stops,
  the state is idle, and on iOS the lock-screen info is cleared. On Android this
  replaces the old behaviour of pausing and keeping the previous list.
* iOS: `isPlayingStream` no longer reports `true` while the player waits with
  nothing loaded.
* iOS: `dispose()` without a prior `initialize()` no longer clears the system
  now-playing info.
* Platform interface: added `state` and `stateStream` to
  `FlutterRadioPlayerPlatform`. They throw `UnimplementedError` by default, so
  existing platform implementations keep working.
* Docs: added a "Player state" section (state, errors, legacy streams, call
  ordering); corrected the Android permission note (`INTERNET` must be declared
  by the app), the `compileSdk` value in the migration guide and the example
  link.
* Examples are driven from `stateStream`; CI now builds the example for
  Android and iOS.

# 4.1.0

* Converted all HostApi methods to Pigeon `@async`; platform calls now wait for
  genuine readiness instead of being silently buffered. Dart `Future`s complete
  only after the underlying platform operation actually runs. No public Dart API
  changes.
* Android: replaced ad-hoc pending-operations queue with the native Media3
  `ListenableFuture<MediaController>` readiness gate; listeners run on
  `ContextCompat.getMainExecutor` for correct thread affinity and errors surface
  as `FlutterError` to Dart instead of being swallowed.
* Android: removed bogus `Player.STATE_READY -> false` emission that could report
  `isPlaying = false` during a buffer stall mid-playback.
* Android: `VolumeInfo.isMuted` now honestly reflects `volume == 0`.
* Android: artwork URL detection now checks `http://` / `https://` prefix instead of
  substring `contains("http")`.
* Android: `FlutterLoader` lookup now uses the `FlutterInjector.instance()`
  singleton instead of reinitializing per asset load.
* Android: `dispose()` now also stops the playback service.
* iOS: `onPlaybackStateChanged` no longer emits `false` during buffer stalls
  mid-playback (now uses `timeControlStatus != .paused`). Lock-screen playback
  rate still tracks the precise `.playing` state.
* iOS: `dispose()` now removes notification observers and deactivates the
  `AVAudioSession` with `.notifyOthersOnDeactivation` so other audio apps can
  resume. `initialize()` re-attaches observers to support dispose/reinit cycles.

# 4.0.2

* iOS: Added Swift Package Manager support
* Android: Bumped Media3 to 1.10.0, compileSdk to 36, aligned Kotlin to 2.1.20

# 4.0.1

* Added dartdoc comments to all public API elements across app-facing and platform interface packages
* Added example app (`packages/flutter_radio_player/example/`) for pub.dev scoring

# 4.0.0

* **BREAKING**: Full rewrite with federated plugin architecture (monorepo)
* **BREAKING**: Replaced `List<Map<String, String>>` with typed `RadioSource` model
* **BREAKING**: Renamed stream getters (`getPlaybackStream()` → `isPlayingStream`, etc.)
* **BREAKING**: Renamed `prevSource()` → `previousSource()`
* **BREAKING**: `getVolume()` now returns `Future<double>` (non-nullable)
* Added Pigeon for type-safe platform channels (replaces manual method/event channels)
* iOS: Replaced SwiftAudioEx with direct AVFoundation (no third-party deps)
* iOS: Raised minimum deployment target to 14.0
* iOS: Implemented `playOrPause()` (was missing)
* iOS: Added artwork URL support (was asset-only)
* iOS: Fixed volume event double-emission bug
* Added `dispose()` method on both platforms
* Added CI/CD via GitHub Actions
* Removed kotlinx-serialization dependency on Android

# 3.0.2

* Added foreground title when title was provided along with artist title

# 3.0.1

* Added missing method `jumpToSourceIndex(index)`

# 3.0.0

* Completely Rewritten from scratch with backward compatibility in-mind
* Now supports album arts in both iOS and Android platforms
* Better support for platform native companion playbacks like watchOS, wearOS, CarPlay, and Android Auto
* Multiple bugfixes and enhancements from previous versions

# 2.0.3

* Bugfixes for Android 14+

# 2.0.2

* Fixed compiling error.

# 2.0.1

* Updated for better rating

# 2.0.0

* Completely Rewritten from scratch with backward compatibility in-mind
* Supports multiple media-sources
* Better Events / Reactivity
* Better watchOS / WearOS support
* Better native control support
* New methods to control the player better

# 1.1.0

* Updated to NULL-SAFETY
* Updated exo-player version
* Bug fixes and improvements

# 1.0.7

* Fixed media meta-data on iOS

# 1.0.6

* Fixed media meta-data bug and dynamic URL changing issue.

# 1.0.5

Fixed bugs, reorganized code and improved documentation.

* Added setUrl method to dynamically change the playing URL.
* Improved documentation.

# 1.0.4

Fixed bugs and slightly improved documentation.

* Fixed an issue where player failed to bind to the application context.
* Fixed an issue with EventSink.
* Fixed a typo in the pubspec

# 1.0.3

* Fixed pubpec

# 1.0.2

* Fixed pubpec

# 1.0.1

* Fixed pubpec

# 1.0.0

* Updated Read me.

# 0.0.1

* Initial Release of FlutterRadioPlayer