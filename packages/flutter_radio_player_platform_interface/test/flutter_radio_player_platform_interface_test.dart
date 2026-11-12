import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform extends FlutterRadioPlayerPlatform with MockPlatformInterfaceMixin {}

class _LegacyPlatform extends FlutterRadioPlayerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> play() async {}

  @override
  Stream<bool> get isPlayingStream => const Stream<bool>.empty();
}

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

  group('FlutterRadioPlayerPlatform state members', () {
    test('state and stateStream throw UnimplementedError by default', () {
      final platform = _FakePlatform();

      expect(() => platform.state, throwsUnimplementedError);
      expect(() => platform.stateStream, throwsUnimplementedError);
    });

    test('a subclass overriding only the 4.1.0 members still instantiates', () {
      final platform = _LegacyPlatform();
      FlutterRadioPlayerPlatform.instance = platform;

      expect(platform.isPlayingStream, isA<Stream<bool>>());
      expect(() => platform.state, throwsUnimplementedError);
      expect(() => platform.stateStream, throwsUnimplementedError);
    });
  });

  group('PlaybackStatus', () {
    test('has the five documented values', () {
      expect(PlaybackStatus.values, [
        PlaybackStatus.idle,
        PlaybackStatus.loading,
        PlaybackStatus.playing,
        PlaybackStatus.paused,
        PlaybackStatus.error,
      ]);
    });
  });

  group('RadioPlayerErrorCode', () {
    test('has the seven documented values', () {
      expect(RadioPlayerErrorCode.values.map((code) => code.name), [
        'invalidSource',
        'network',
        'httpStatus',
        'unsupportedFormat',
        'backgroundRestricted',
        'timeout',
        'unknown',
      ]);
    });

    test('every value round-trips through its name', () {
      for (final code in RadioPlayerErrorCode.values) {
        expect(RadioPlayerErrorCode.values.byName(code.name), code);
      }
    });
  });

  group('RadioPlayerError', () {
    test('equality and hashCode', () {
      const a = RadioPlayerError(
        code: RadioPlayerErrorCode.network,
        message: 'offline',
      );
      const b = RadioPlayerError(
        code: RadioPlayerErrorCode.network,
        message: 'offline',
      );
      const differentCode = RadioPlayerError(
        code: RadioPlayerErrorCode.unknown,
        message: 'offline',
      );
      const differentMessage = RadioPlayerError(
        code: RadioPlayerErrorCode.network,
        message: 'timeout',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(differentCode)));
      expect(a, isNot(equals(differentMessage)));
    });

    test('toString', () {
      const error = RadioPlayerError(
        code: RadioPlayerErrorCode.invalidSource,
        message: 'bad url',
      );
      expect(
        error.toString(),
        'RadioPlayerError(code: RadioPlayerErrorCode.invalidSource, '
        'message: bad url)',
      );
    });
  });

  group('RadioPlayerState', () {
    test('defaults describe a player with nothing loaded', () {
      const state = RadioPlayerState();
      expect(state.status, PlaybackStatus.idle);
      expect(state.currentIndex, isNull);
      expect(state.currentSource, isNull);
      expect(state.nowPlaying, isNull);
      expect(state.volume, 0.5);
      expect(state.error, isNull);
    });

    test('equality and hashCode', () {
      const source = RadioSource(url: 'http://example.com', title: 'Test');
      const error = RadioPlayerError(
        code: RadioPlayerErrorCode.network,
        message: 'offline',
      );
      const a = RadioPlayerState(
        status: PlaybackStatus.error,
        currentIndex: 1,
        currentSource: source,
        nowPlaying: NowPlayingInfo(title: 'Song'),
        volume: 0.8,
        error: error,
      );
      const b = RadioPlayerState(
        status: PlaybackStatus.error,
        currentIndex: 1,
        currentSource: source,
        nowPlaying: NowPlayingInfo(title: 'Song'),
        volume: 0.8,
        error: error,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(const RadioPlayerState(), equals(const RadioPlayerState()));
    });

    test('differs when any field differs', () {
      const base = RadioPlayerState(
        status: PlaybackStatus.playing,
        currentIndex: 0,
        currentSource: RadioSource(url: 'http://a.com'),
        nowPlaying: NowPlayingInfo(title: 'Song'),
        volume: 0.5,
        error: RadioPlayerError(
          code: RadioPlayerErrorCode.unknown,
          message: 'x',
        ),
      );
      final variants = <RadioPlayerState>[
        const RadioPlayerState(status: PlaybackStatus.paused),
        const RadioPlayerState(
          status: PlaybackStatus.playing,
          currentIndex: 1,
        ),
        const RadioPlayerState(
          status: PlaybackStatus.playing,
          currentIndex: 0,
          currentSource: RadioSource(url: 'http://b.com'),
        ),
        const RadioPlayerState(
          status: PlaybackStatus.playing,
          currentIndex: 0,
          currentSource: RadioSource(url: 'http://a.com'),
          nowPlaying: NowPlayingInfo(title: 'Other'),
        ),
        const RadioPlayerState(
          status: PlaybackStatus.playing,
          currentIndex: 0,
          currentSource: RadioSource(url: 'http://a.com'),
          nowPlaying: NowPlayingInfo(title: 'Song'),
          volume: 0.9,
        ),
        const RadioPlayerState(
          status: PlaybackStatus.playing,
          currentIndex: 0,
          currentSource: RadioSource(url: 'http://a.com'),
          nowPlaying: NowPlayingInfo(title: 'Song'),
        ),
      ];
      for (final variant in variants) {
        expect(base, isNot(equals(variant)));
      }
    });

    test('toString', () {
      const state = RadioPlayerState(
        status: PlaybackStatus.playing,
        currentIndex: 2,
        volume: 0.7,
      );
      expect(
        state.toString(),
        'RadioPlayerState(status: PlaybackStatus.playing, currentIndex: 2, '
        'currentSource: null, nowPlaying: null, volume: 0.7, error: null)',
      );
    });
  });
}
