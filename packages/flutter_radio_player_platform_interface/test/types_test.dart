import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

RadioSource _source(String id, {Map<String, String>? headers}) => RadioSource(
  id: id,
  url: 'https://$id.example/stream',
  title: id.toUpperCase(),
  headers: headers ?? {'A': '1', 'B': '2'},
);

void main() {
  group('RadioSource', () {
    test('id defaults to url', () {
      const source = RadioSource(url: 'https://a.example/s');
      expect(source.id, 'https://a.example/s');
      expect(const RadioSource(url: 'u', id: 'x').id, 'x');
    });

    test('equality compares headers by content, hash ignores order', () {
      final a = _source('a', headers: {'A': '1', 'B': '2'});
      final b = _source('a', headers: Map.of({'B': '2', 'A': '1'}));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(_source('a', headers: {'A': '1', 'B': '3'})));
      expect(a, isNot(_source('a', headers: {'A': '1'})));
    });

    test('toString shows header names, never values', () {
      final text = _source(
        'a',
        headers: {'Authorization': 'Bearer secret'},
      ).toString();
      expect(text, contains('Authorization'));
      expect(text, isNot(contains('secret')));
    });

    test('copyWith replaces and clears fields', () {
      final source = RadioSource(
        url: 'https://a.example/s',
        title: 'A',
        artwork: 'art.png',
      );
      expect(source.copyWith(title: 'B').title, 'B');
      expect(source.copyWith(title: null).title, isNull);
      expect(source.copyWith(artwork: null).artwork, isNull);
      expect(source.copyWith().artwork, 'art.png');
      expect(source.copyWith(url: 'https://b.example/s').id, source.id);
    });
  });

  group('NowPlayingInfo', () {
    const cases = <(String, String?, String?)>[
      ('Miles Davis - So What', 'Miles Davis', 'So What'),
      ('  Miles Davis  -  So What ', 'Miles Davis', 'So What'),
      ('A - B - C', 'A', 'B - C'),
      ('No separator', null, null),
      ('Artist-Song', null, null),
      (' - Song', null, null),
      ('Artist - ', null, null),
      ('   -   ', null, null),
      ('', null, null),
    ];
    for (final (title, artist, song) in cases) {
      test('splits "$title"', () {
        final info = NowPlayingInfo(title: title);
        expect(info.artist, artist);
        expect(info.song, song);
      });
    }

    test('equality', () {
      expect(
        const NowPlayingInfo(title: 'x'),
        const NowPlayingInfo(title: 'x'),
      );
      expect(
        const NowPlayingInfo(title: 'x'),
        isNot(const NowPlayingInfo(title: 'y')),
      );
    });
  });

  group('RadioPlayerState', () {
    test('defaults describe a player with no sources', () {
      const state = RadioPlayerState();
      expect(state.status, PlaybackStatus.idle);
      expect(state.sources, isEmpty);
      expect(state.currentIndex, isNull);
      expect(state.currentSource, isNull);
      expect(state.nowPlaying, isNull);
      expect(state.volume, 1.0);
      expect(state.error, isNull);
    });

    test('equality compares sources element-wise', () {
      final a = RadioPlayerState(
        status: PlaybackStatus.paused,
        sources: [_source('a'), _source('b')],
        currentIndex: 1,
      );
      final b = RadioPlayerState(
        status: PlaybackStatus.paused,
        sources: List.of([_source('a'), _source('b')]),
        currentIndex: 1,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(b.copyWith(sources: [_source('a')])));
      expect(a, isNot(b.copyWith(currentIndex: 0)));
      expect(a, isNot(b.copyWith(volume: 0.5)));
    });

    test('currentSource follows currentIndex and tolerates invalid states', () {
      final sources = [_source('a'), _source('b')];
      expect(
        RadioPlayerState(sources: sources, currentIndex: 1).currentSource,
        sources[1],
      );
      expect(RadioPlayerState(sources: sources).currentSource, isNull);
      expect(
        RadioPlayerState(sources: sources, currentIndex: 5).currentSource,
        isNull,
      );
      expect(
        RadioPlayerState(sources: sources, currentIndex: -1).currentSource,
        isNull,
      );
    });

    const error = RadioPlayerError(
      code: RadioPlayerErrorCode.network,
      message: 'down',
    );
    final getterCases = <(PlaybackStatus, RadioPlayerError?, bool, bool, bool)>[
      (PlaybackStatus.idle, null, false, false, false),
      (PlaybackStatus.paused, null, false, false, false),
      (PlaybackStatus.loading, null, true, true, false),
      (PlaybackStatus.loading, error, true, true, true),
      (PlaybackStatus.playing, null, true, false, false),
      (PlaybackStatus.error, error, false, false, false),
    ];
    for (final (status, err, playing, loading, reconnecting) in getterCases) {
      test('getters for ${status.name}${err == null ? '' : ' with error'}', () {
        final state = RadioPlayerState(status: status, error: err);
        expect(state.isPlaying, playing);
        expect(state.isLoading, loading);
        expect(state.isReconnecting, reconnecting);
      });
    }

    test('copyWith keeps unspecified fields and clears nullable ones', () {
      final state = RadioPlayerState(
        status: PlaybackStatus.loading,
        sources: [_source('a')],
        currentIndex: 0,
        nowPlaying: const NowPlayingInfo(title: 't'),
        volume: 0.4,
        error: error,
      );
      expect(state.copyWith(), state);
      final cleared = state.copyWith(
        currentIndex: null,
        nowPlaying: null,
        error: null,
      );
      expect(cleared.currentIndex, isNull);
      expect(cleared.nowPlaying, isNull);
      expect(cleared.error, isNull);
      expect(cleared.volume, 0.4);
      expect(cleared.sources, state.sources);
    });

    test('toString does not leak header values', () {
      final state = RadioPlayerState(
        sources: [
          _source('a', headers: {'Authorization': 'Bearer secret'}),
        ],
        currentIndex: 0,
      );
      expect(state.toString(), isNot(contains('secret')));
    });
  });

  group('RadioPlayerError', () {
    test('equality', () {
      expect(
        const RadioPlayerError(
          code: RadioPlayerErrorCode.timeout,
          message: 'm',
        ),
        const RadioPlayerError(
          code: RadioPlayerErrorCode.timeout,
          message: 'm',
        ),
      );
      expect(
        const RadioPlayerError(
          code: RadioPlayerErrorCode.timeout,
          message: 'm',
        ),
        isNot(
          const RadioPlayerError(
            code: RadioPlayerErrorCode.network,
            message: 'm',
          ),
        ),
      );
    });
  });

  group('RadioPlayerOptions', () {
    test('defaults', () {
      const options = RadioPlayerOptions();
      expect(options.wrapAround, isTrue);
      expect(options.reconnect.giveUpAfter, const Duration(minutes: 5));
      expect(options.android.stopOnTaskRemoved, isTrue);
      expect(options.android.notificationIcon, isNull);
      expect(ReconnectPolicy.none.giveUpAfter, Duration.zero);
    });

    test('equality and copyWith', () {
      const options = RadioPlayerOptions(
        android: AndroidOptions(notificationIcon: 'ic_radio'),
      );
      expect(
        options,
        const RadioPlayerOptions(
          android: AndroidOptions(notificationIcon: 'ic_radio'),
        ),
      );
      expect(options.copyWith(wrapAround: false).wrapAround, isFalse);
      expect(options.copyWith(wrapAround: false), isNot(options));
      expect(
        options.copyWith(reconnect: ReconnectPolicy.none).reconnect,
        ReconnectPolicy.none,
      );
      expect(
        options.android.copyWith(notificationIcon: null).notificationIcon,
        isNull,
      );
      expect(
        options.android.copyWith(stopOnTaskRemoved: false),
        const AndroidOptions(
          stopOnTaskRemoved: false,
          notificationIcon: 'ic_radio',
        ),
      );
    });
  });
}
