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
