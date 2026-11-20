# 5.0.0-dev.2

* **Breaking:** 5.0 platform interface. Every command returns the
  `RadioPlayerState` after it was applied; `stateStream` is the only stream.
  Removed: `initialize`, `dispose`, `getVolume`, `nextSource`, `previousSource`,
  `jumpToSourceAtIndex`, the legacy streams, the synchronous `state` getter and
  `VolumeInfo`.
* Models: `RadioPlayerState.sources`, `isPlaying`, `isLoading`, `isReconnecting`,
  `copyWith`; `RadioSource.id` and `headers`; `NowPlayingInfo.artist`/`song`;
  `RadioPlayerOptions`, `ReconnectPolicy`, `AndroidOptions`. Default volume 1.0.

# 5.0.0-dev.1

First 5.0 pre-release. Build requirements change; the Dart API and behaviour are the same as 4.2.0.

* Requires Dart 3.12 and Flutter 3.44 or later.

# 4.2.0

* Added `RadioPlayerState`, `PlaybackStatus`, `RadioPlayerError` and
  `RadioPlayerErrorCode`. `RadioPlayerErrorCode` is the final value set for the
  4.x line. The official platforms emit only `invalidSource` (iOS), `network`
  and `unknown`; the other codes are reserved.
* Added `state` and `stateStream` to `FlutterRadioPlayerPlatform`. Both throw
  `UnimplementedError` by default, so existing implementations keep working.
  Implementations that `extends` the class need no change; one that `implements`
  it must add the two members.
* No existing member changed.

# 4.1.0

* Version aligned across packages; no public API changes on the platform interface.

# 4.0.1

* Added dartdoc comments to all public API elements

# 4.0.0

* Initial release as federated package
