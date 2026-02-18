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