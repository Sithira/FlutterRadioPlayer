import 'dart:async';

import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePlatform extends FlutterRadioPlayerPlatform
    with MockPlatformInterfaceMixin {
  List<String> calls = [];

  @override
  Future<void> initialize(List<RadioSource> sources,
      {bool playWhenReady = false}) async {
    calls.add('initialize');
  }

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> playOrPause() async => calls.add('playOrPause');
  @override
  Future<void> setVolume(double volume) async => calls.add('setVolume');
  @override
  Future<double> getVolume() async => 0.5;
  @override
  Future<void> nextSource() async => calls.add('nextSource');
  @override
  Future<void> previousSource() async => calls.add('previousSource');
  @override
  Future<void> jumpToSourceAtIndex(int index) async =>
      calls.add('jumpToSourceAtIndex');
  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  Stream<bool> get isPlayingStream => Stream.value(true);
  @override
  Stream<NowPlayingInfo> get nowPlayingStream =>
      Stream.value(const NowPlayingInfo(title: 'Test'));
  @override
  Stream<VolumeInfo> get volumeStream =>
      Stream.value(const VolumeInfo(volume: 0.5, isMuted: false));
}

void main() {
  late FakePlatform fakePlatform;
  late FlutterRadioPlayer player;

  setUp(() {
    fakePlatform = FakePlatform();
    FlutterRadioPlayerPlatform.instance = fakePlatform;
    player = FlutterRadioPlayer();
  });

  test('initialize delegates to platform', () async {
    await player.initialize([const RadioSource(url: 'http://test.com')]);
    expect(fakePlatform.calls, contains('initialize'));
  });

  test('play delegates to platform', () async {
    await player.play();
    expect(fakePlatform.calls, contains('play'));
  });

  test('pause delegates to platform', () async {
    await player.pause();
    expect(fakePlatform.calls, contains('pause'));
  });

  test('playOrPause delegates to platform', () async {
    await player.playOrPause();
    expect(fakePlatform.calls, contains('playOrPause'));
  });

  test('setVolume delegates to platform', () async {
    await player.setVolume(0.8);
    expect(fakePlatform.calls, contains('setVolume'));
  });

  test('getVolume returns value from platform', () async {
    final volume = await player.getVolume();
    expect(volume, 0.5);
  });

  test('nextSource delegates to platform', () async {
    await player.nextSource();
    expect(fakePlatform.calls, contains('nextSource'));
  });

  test('previousSource delegates to platform', () async {
    await player.previousSource();
    expect(fakePlatform.calls, contains('previousSource'));
  });

  test('jumpToSourceAtIndex delegates to platform', () async {
    await player.jumpToSourceAtIndex(1);
    expect(fakePlatform.calls, contains('jumpToSourceAtIndex'));
  });

  test('dispose delegates to platform', () async {
    await player.dispose();
    expect(fakePlatform.calls, contains('dispose'));
  });

  test('isPlayingStream returns stream from platform', () async {
    final value = await player.isPlayingStream.first;
    expect(value, true);
  });

  test('nowPlayingStream returns stream from platform', () async {
    final value = await player.nowPlayingStream.first;
    expect(value.title, 'Test');
  });

  test('volumeStream returns stream from platform', () async {
    final value = await player.volumeStream.first;
    expect(value.volume, 0.5);
    expect(value.isMuted, false);
  });
}
