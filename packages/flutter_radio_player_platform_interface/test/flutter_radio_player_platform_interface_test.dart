import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform extends FlutterRadioPlayerPlatform with MockPlatformInterfaceMixin {}

void main() {
  group('FlutterRadioPlayerPlatform', () {
    test('can be set with a valid token', () {
      final fake = _FakePlatform();
      FlutterRadioPlayerPlatform.instance = fake;
      expect(FlutterRadioPlayerPlatform.instance, fake);
    });

    test('all methods throw UnimplementedError by default', () {
      final fake = _FakePlatform();
      FlutterRadioPlayerPlatform.instance = fake;
      final platform = FlutterRadioPlayerPlatform.instance;

      expect(() => platform.initialize([]), throwsUnimplementedError);
      expect(() => platform.play(), throwsUnimplementedError);
      expect(() => platform.pause(), throwsUnimplementedError);
      expect(() => platform.playOrPause(), throwsUnimplementedError);
      expect(() => platform.setVolume(0.5), throwsUnimplementedError);
      expect(() => platform.getVolume(), throwsUnimplementedError);
      expect(() => platform.nextSource(), throwsUnimplementedError);
      expect(() => platform.previousSource(), throwsUnimplementedError);
      expect(() => platform.jumpToSourceAtIndex(0), throwsUnimplementedError);
      expect(() => platform.dispose(), throwsUnimplementedError);
      expect(() => platform.isPlayingStream, throwsUnimplementedError);
      expect(() => platform.nowPlayingStream, throwsUnimplementedError);
      expect(() => platform.volumeStream, throwsUnimplementedError);
    });
  });

  group('RadioSource', () {
    test('equality', () {
      const a = RadioSource(url: 'http://example.com', title: 'Test');
      const b = RadioSource(url: 'http://example.com', title: 'Test');
      const c = RadioSource(url: 'http://other.com');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('NowPlayingInfo', () {
    test('equality', () {
      const a = NowPlayingInfo(title: 'Song');
      const b = NowPlayingInfo(title: 'Song');
      const c = NowPlayingInfo();
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('VolumeInfo', () {
    test('equality', () {
      const a = VolumeInfo(volume: 0.5, isMuted: false);
      const b = VolumeInfo(volume: 0.5, isMuted: false);
      const c = VolumeInfo(volume: 1.0, isMuted: true);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
