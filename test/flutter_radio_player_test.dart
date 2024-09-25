import 'package:flutter_radio_player/data/flutter_radio_player_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_radio_player/flutter_radio_player_platform_interface.dart';
import 'package:flutter_radio_player/flutter_radio_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterRadioPlayerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterRadioPlayerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> play() {
    // TODO: implement play
    throw UnimplementedError();
  }

  @override
  Future<void> changeVolume(double volume) {
    // TODO: implement changeVolume
    throw UnimplementedError();
  }

  @override
  Stream<DeviceVolumeDataChanged?> getDeviceVolumeChangedStream() {
    // TODO: implement getDeviceVolumeChangedStream
    throw UnimplementedError();
  }

  @override
  Stream<bool> getIsPlayingStream() {
    // TODO: implement getIsPlayingStream
    throw UnimplementedError();
  }

  @override
  Stream<NowPlayingDataChanged?> getNowPlayingStream() {
    // TODO: implement getNowPlayingStream
    throw UnimplementedError();
  }

  @override
  Future<double?> getVolume() {
    // TODO: implement getVolume
    throw UnimplementedError();
  }

  @override
  Future<void> initialize(
      List<Map<String, String>> sources, bool playWhenReady) {
    // TODO: implement initialize
    throw UnimplementedError();
  }

  @override
  Future<void> jumpToSourceIndex(int index) {
    // TODO: implement jumpToSourceIndex
    throw UnimplementedError();
  }

  @override
  Future<void> nextSource() {
    // TODO: implement nextSource
    throw UnimplementedError();
  }

  @override
  Future<void> pause() {
    // TODO: implement pause
    throw UnimplementedError();
  }

  @override
  Future<void> playOrPause() {
    // TODO: implement playOrPause
    throw UnimplementedError();
  }

  @override
  Future<void> previousSource() {
    // TODO: implement previousSource
    throw UnimplementedError();
  }
}

void main() {
  final FlutterRadioPlayerPlatform initialPlatform =
      FlutterRadioPlayerPlatform.instance;

  test('$MethodChannelFlutterRadioPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterRadioPlayer>());
  });

  test('getPlatformVersion', () async {
    FlutterRadioPlayer flutterRadioPlayerPlugin = FlutterRadioPlayer();
    MockFlutterRadioPlayerPlatform fakePlatform =
        MockFlutterRadioPlayerPlatform();
    FlutterRadioPlayerPlatform.instance = fakePlatform;

    expect('42', '42');
  });
}
