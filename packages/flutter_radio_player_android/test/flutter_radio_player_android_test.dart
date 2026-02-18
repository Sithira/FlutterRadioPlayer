import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_radio_player_android/flutter_radio_player_android.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

void main() {
  test('registerWith sets platform instance', () {
    FlutterRadioPlayerAndroid.registerWith();
    expect(
      FlutterRadioPlayerPlatform.instance,
      isA<FlutterRadioPlayerAndroid>(),
    );
  });
}
