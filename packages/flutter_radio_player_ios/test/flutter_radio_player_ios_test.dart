import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_radio_player_ios/flutter_radio_player_ios.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

void main() {
  test('registerWith sets platform instance', () {
    FlutterRadioPlayerIos.registerWith();
    expect(
      FlutterRadioPlayerPlatform.instance,
      isA<FlutterRadioPlayerIos>(),
    );
  });
}
