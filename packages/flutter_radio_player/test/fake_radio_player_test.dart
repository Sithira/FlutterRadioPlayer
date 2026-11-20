import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_radio_player/testing.dart';
import 'package:flutter_test/flutter_test.dart';

RadioSource _fromJson(Map<String, dynamic> json) => RadioSource(
  id: json['id'] as String?,
  url: json['url'] as String,
  title: json['title'] as String?,
  artwork: json['artwork'] as String?,
  headers: Map<String, String>.from(json['headers'] as Map? ?? const {}),
);

List<RadioSource> _list(Object? json) => [
  for (final item in json! as List) _fromJson(item as Map<String, dynamic>),
];

const _a = RadioSource(url: 'https://a.example/s', title: 'A');
const _b = RadioSource(url: 'https://b.example/s', title: 'B');
const _c = RadioSource(url: 'https://c.example/s', title: 'C');
const _song = NowPlayingInfo(title: 'Artist - Song');

void main() {
  late FakeRadioPlayer fake;
  final player = FlutterRadioPlayer.instance;

  setUp(() => fake = FakeRadioPlayer.install());

  group('selection table (test_fixtures/selection_cases.json)', () {
    final table =
        jsonDecode(
              File(
                '../../test_fixtures/selection_cases.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    for (final raw in table['cases'] as List) {
      final c = raw as Map<String, dynamic>;
      test(c['name'], () async {
        final old = _list(c['old']);
        if (old.isNotEmpty) {
          await player.setSources(old, initialIndex: c['oldIndex'] as int);
          await player.play();
          fake.state = fake.state.copyWith(nowPlaying: _song);
          await pumpEventQueue();
        }

        await player.setSources(
          _list(c['new']),
          initialIndex: c['initialIndex'] as int?,
        );

        final state = player.state;
        expect(state.currentIndex, c['expectedIndex']);
        expect(state.sources, _list(c['new']));
        if (c['expectedIndex'] == null) {
          expect(state.status, PlaybackStatus.idle);
        } else if (c['expectedStream'] == 'keep') {
          expect(state.status, PlaybackStatus.playing);
          expect(state.nowPlaying, _song);
        } else {
          expect(state.status, PlaybackStatus.paused);
          expect(state.nowPlaying, isNull);
        }
      });
    }
  });

  group('setSources', () {
    test('autoPlay plays the selected source', () async {
      await player.setSources(const [_a, _b], initialIndex: 1, autoPlay: true);
      expect(player.state.status, PlaybackStatus.playing);
      expect(player.state.currentSource, _b);
    });

    test('autoPlay false does not pause a kept stream', () async {
      await player.setSources(const [_a, _b], autoPlay: true);
      await player.setSources(const [_c, _a]);
      expect(player.state.status, PlaybackStatus.playing);
      expect(player.state.currentIndex, 1);
    });

    test('empty list gives idle and keeps volume', () async {
      await player.setVolume(0.4);
      await player.setSources(const [_a], autoPlay: true);
      await player.setSources(const []);
      expect(player.state, const RadioPlayerState(volume: 0.4));
    });
  });

  group('transport with no sources does nothing', () {
    test('every command completes and changes nothing', () async {
      await player.play();
      await player.pause();
      await player.playOrPause();
      await player.stop();
      await player.next();
      await player.previous();
      expect(player.state, const RadioPlayerState());
      expect(fake.calls, [
        'play',
        'pause',
        'playOrPause',
        'stop',
        'next',
        'previous',
      ]);
    });
  });

  group('C3 wrap-around', () {
    test('wraps by default', () async {
      await player.setSources(const [_a, _b, _c], initialIndex: 2);
      await player.next();
      expect(player.state.currentIndex, 0);
      await player.previous();
      expect(player.state.currentIndex, 2);
    });

    test('stops at the ends without wrapAround', () async {
      await player.setOptions(const RadioPlayerOptions(wrapAround: false));
      await player.setSources(const [_a, _b, _c], initialIndex: 2);
      await player.next();
      expect(player.state.currentIndex, 2);
      await player.play(index: 0);
      await player.previous();
      expect(player.state.currentIndex, 0);
      expect(player.state.status, PlaybackStatus.playing);
    });

    test('does nothing with one source', () async {
      await player.setSources(const [_a], autoPlay: true);
      fake.state = fake.state.copyWith(nowPlaying: _song);
      await pumpEventQueue();
      await player.next();
      await player.previous();
      expect(player.state.currentIndex, 0);
      expect(player.state.nowPlaying, _song);
    });
  });

  group('C4 source change', () {
    test('next keeps playing and clears nowPlaying', () async {
      await player.setSources(const [_a, _b], autoPlay: true);
      fake.state = fake.state.copyWith(nowPlaying: _song);
      await pumpEventQueue();
      await player.next();
      expect(player.state.status, PlaybackStatus.playing);
      expect(player.state.currentIndex, 1);
      expect(player.state.nowPlaying, isNull);
    });

    test('loading counts as playing', () async {
      await player.setSources(const [_a, _b]);
      fake.state = fake.state.copyWith(status: PlaybackStatus.loading);
      await pumpEventQueue();
      await player.previous();
      expect(player.state.status, PlaybackStatus.playing);
    });

    test('paused stays paused', () async {
      await player.setSources(const [_a, _b]);
      await player.next();
      expect(player.state.status, PlaybackStatus.paused);
      expect(player.state.currentIndex, 1);
    });

    test('failed stays not playing and the error clears', () async {
      await player.setSources(const [_a, _b]);
      fake.state = fake.state.copyWith(
        status: PlaybackStatus.error,
        error: const RadioPlayerError(
          code: RadioPlayerErrorCode.network,
          message: 'down',
        ),
      );
      await pumpEventQueue();
      await player.next();
      expect(player.state.status, PlaybackStatus.paused);
      expect(player.state.error, isNull);
    });

    test('play(index:) switches and plays', () async {
      await player.setSources(const [_a, _b, _c]);
      await player.play(index: 2);
      expect(player.state.status, PlaybackStatus.playing);
      expect(player.state.currentSource, _c);
    });

    test('play(index:) on the current source keeps nowPlaying', () async {
      await player.setSources(const [_a, _b], autoPlay: true);
      fake.state = fake.state.copyWith(nowPlaying: _song);
      await pumpEventQueue();
      await player.play(index: 0);
      expect(player.state.nowPlaying, _song);
    });
  });

  group('C5 index out of range', () {
    test(
      'play(index:) beyond the list is a RangeError, state unchanged',
      () async {
        await player.setSources(const [_a, _b]);
        final before = player.state;
        await expectLater(player.play(index: 2), throwsRangeError);
        expect(player.state, before);
      },
    );

    test('play(index:) with no sources does nothing', () async {
      await player.play(index: 3);
      expect(player.state, const RadioPlayerState());
    });
  });

  group('C7 volume', () {
    test('defaults to 1.0', () {
      expect(player.state.volume, 1.0);
    });

    test('setSources and stop keep the volume', () async {
      await player.setVolume(0.3);
      await player.setSources(const [_a, _b], autoPlay: true);
      await player.stop();
      await player.setSources(const [_c]);
      expect(player.state.volume, 0.3);
    });

    test('clamped', () async {
      await player.setVolume(2);
      expect(player.state.volume, 1.0);
    });
  });

  group('commands', () {
    test('pause and stop differ only in calls and nowPlaying', () async {
      await player.setSources(const [_a], autoPlay: true);
      fake.state = fake.state.copyWith(nowPlaying: _song);
      await pumpEventQueue();
      await player.pause();
      expect(player.state.status, PlaybackStatus.paused);
      expect(player.state.nowPlaying, _song);
      await player.play();
      await player.stop();
      expect(player.state.status, PlaybackStatus.paused);
      expect(player.state.nowPlaying, isNull);
      expect(fake.calls.skip(1), ['pause', 'play', 'stop']);
    });

    test('playOrPause toggles on isPlaying', () async {
      await player.setSources(const [_a]);
      await player.playOrPause();
      expect(player.state.status, PlaybackStatus.playing);
      fake.state = fake.state.copyWith(status: PlaybackStatus.loading);
      await pumpEventQueue();
      await player.playOrPause();
      expect(player.state.status, PlaybackStatus.paused);
    });

    test('setOptions is recorded and kept', () async {
      const options = RadioPlayerOptions(reconnect: ReconnectPolicy.none);
      await player.setOptions(options);
      expect(fake.options, options);
      expect(fake.calls, ['setOptions']);
    });
  });

  group('install', () {
    test('a second install starts idle and drops the first fake', () async {
      await player.setSources(const [_a], autoPlay: true);
      final first = fake;
      final second = FakeRadioPlayer.install();
      expect(player.state, const RadioPlayerState());

      first.state = const RadioPlayerState(volume: 0.1);
      await pumpEventQueue();
      expect(player.state, const RadioPlayerState());

      second.state = const RadioPlayerState(volume: 0.2);
      await pumpEventQueue();
      expect(player.state.volume, 0.2);
    });
  });

  testWidgets('tapping a station plays it', (tester) async {
    final fake = FakeRadioPlayer.install();
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.tap(find.text('Jazz FM'));
    await tester.pump();
    expect(fake.state.currentIndex, 1);
    expect(fake.state.isPlaying, isTrue);

    fake.state = fake.state.copyWith(
      nowPlaying: const NowPlayingInfo(title: 'Miles Davis - So What'),
    );
    await tester.pump();
    expect(find.text('Miles Davis - So What'), findsOneWidget);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final player = FlutterRadioPlayer.instance;

  @override
  void initState() {
    super.initState();
    player.setSources(const [
      RadioSource(url: 'https://example.com/chill.mp3', title: 'Chillout'),
      RadioSource(url: 'https://example.com/jazz.aac', title: 'Jazz FM'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: RadioPlayerBuilder(
        builder: (context, state) => Column(
          children: [
            Text(state.nowPlaying?.title ?? state.currentSource?.title ?? ''),
            for (final (index, source) in state.sources.indexed)
              GestureDetector(
                onTap: () => player.play(index: index),
                child: Text(source.title ?? source.url),
              ),
          ],
        ),
      ),
    );
  }
}
