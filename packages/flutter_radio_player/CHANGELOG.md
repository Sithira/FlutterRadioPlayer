# 4.2.0

* Added `FlutterRadioPlayer.instance`, `state` and `stateStream`; the public
  constructor is unchanged, but every instance drives the same native player.
  New `stateStream` listeners first receive the latest state. `state` is
  eventually consistent.
* Re-exports `RadioPlayerState`, `PlaybackStatus`, `RadioPlayerError` and
  `RadioPlayerErrorCode`. Playback errors now appear as `status == error` with
  `state.error`. Android emits `network` and `unknown`; iOS also emits
  `invalidSource`; the other codes are reserved in 4.x.
* `isPlayingStream`, `nowPlayingStream` and `volumeStream` are single shared
  streams derived from the state: several listeners work, identical consecutive
  values are no longer emitted, and they do not replay.
* `play()`, `pause()`, `playOrPause()`, `nextSource()`, `previousSource()` and
  `jumpToSourceAtIndex()` before `initialize()` or after `dispose()` are ignored
  and log a warning; `initialize()` need not be awaited first. `dispose()`
  followed by `initialize()` works repeatedly on both platforms.
* A user-initiated `play()` or `playOrPause()` after a failure retries the
  current source.
* Android: tapping the notification opens the launcher activity; playback
  pauses when headphones are unplugged; `setVolume()` before `initialize()` is
  ignored; `dispose()` stops the service and the state returns to idle.
* iOS: the audio session is activated when playback starts, not at launch;
  an early `play()` before `initialize()` is now ignored (it used to take
  effect once a stream was loaded); after an interruption playback resumes only
  if it was active before; a source without artwork no longer shows the
  previous source's artwork; switching to an invalid source stops the previous
  stream and reports `invalidSource`; `isPlayingStream` is no longer `true`
  while nothing is loaded.
* `initialize([])` leaves the player with no sources: the current stream stops
  and the state is idle. On Android this replaces the old behaviour of pausing
  and keeping the previous list.
* Requires platform packages 4.2.0.
* Docs: added a "Player state" section, corrected the Android permission note
  (`INTERNET` must be declared by the app) and the example link.

# 4.1.0

* Platform calls are now backed by Pigeon `@async`: returned `Future`s complete
  only after the underlying operation actually runs, instead of completing
  synchronously while work was silently buffered. Public Dart API is unchanged.

# 4.0.2

* Added Swift Package Manager support for iOS
* Android: upgraded Media3 to 1.10.0, compileSdk to 36, aligned Kotlin to 2.1.20

# 4.0.1

* Added dartdoc comments to all public API elements
* Added example app for pub.dev scoring

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