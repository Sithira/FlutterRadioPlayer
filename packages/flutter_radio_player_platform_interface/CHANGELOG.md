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
