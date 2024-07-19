import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_radio_player_method_channel.dart';

abstract class FlutterRadioPlayerPlatform extends PlatformInterface {
  /// Constructs a FlutterRadioPlayerPlatform.
  FlutterRadioPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterRadioPlayerPlatform _instance = MethodChannelFlutterRadioPlayer();

  /// The default instance of [FlutterRadioPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterRadioPlayer].
  static FlutterRadioPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterRadioPlayerPlatform] when
  /// they register themselves.
  static set instance(FlutterRadioPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}