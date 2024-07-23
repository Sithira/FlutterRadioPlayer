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
}

void main() {
  final FlutterRadioPlayerPlatform initialPlatform = FlutterRadioPlayerPlatform.instance;

  test('$MethodChannelFlutterRadioPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterRadioPlayer>());
  });

  test('getPlatformVersion', () async {
    FlutterRadioPlayer flutterRadioPlayerPlugin = FlutterRadioPlayer();
    MockFlutterRadioPlayerPlatform fakePlatform = MockFlutterRadioPlayerPlatform();
    FlutterRadioPlayerPlatform.instance = fakePlatform;

    expect(await flutterRadioPlayerPlugin.getPlatformVersion(), '42');
  });
}
