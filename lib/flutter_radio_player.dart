
import 'flutter_radio_player_platform_interface.dart';

class FlutterRadioPlayer {
  Future<String?> getPlatformVersion() {
    return FlutterRadioPlayerPlatform.instance.getPlatformVersion();
  }
}
