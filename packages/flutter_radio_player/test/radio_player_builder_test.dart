import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_radio_player/src/flutter_radio_player.dart'
    show resetFlutterRadioPlayer;
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _PushPlatform extends FlutterRadioPlayerPlatform
    with MockPlatformInterfaceMixin {
  final events = StreamController<RadioPlayerState>.broadcast(sync: true);

  @override
  Stream<RadioPlayerState> get stateStream => events.stream;
}

const _source = RadioSource(url: 'https://a.example/s', title: 'A');
const _paused = RadioPlayerState(
  status: PlaybackStatus.paused,
  sources: [_source],
  currentIndex: 0,
);
final _playing = _paused.copyWith(status: PlaybackStatus.playing);
final _titled = _playing.copyWith(
  nowPlaying: const NowPlayingInfo(title: 'Song'),
);
final _quieter = _titled.copyWith(volume: 0.3);

Widget _app(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

String _describe(RadioPlayerState s) =>
    '${s.status.name}|${s.nowPlaying?.title ?? '-'}|${s.volume}';

void main() {
  late _PushPlatform platform;
  final player = FlutterRadioPlayer.instance;

  setUp(() {
    platform = _PushPlatform();
    FlutterRadioPlayerPlatform.instance = platform;
    resetFlutterRadioPlayer();
  });

  testWidgets('first frame uses the current state', (tester) async {
    player.state;
    platform.events.add(_playing);
    await tester.pumpWidget(
      _app(RadioPlayerBuilder(builder: (_, state) => Text(_describe(state)))),
    );
    expect(find.text('playing|-|1.0'), findsOneWidget);
  });

  testWidgets('rebuilds on every distinct state', (tester) async {
    var builds = 0;
    await tester.pumpWidget(
      _app(
        RadioPlayerBuilder(
          builder: (_, state) {
            builds++;
            return Text(_describe(state));
          },
        ),
      ),
    );
    expect(find.text('idle|-|1.0'), findsOneWidget);

    platform.events.add(_paused);
    await tester.pump();
    expect(find.text('paused|-|1.0'), findsOneWidget);

    platform.events.add(_paused);
    await tester.pump();
    platform.events.add(_titled);
    await tester.pump();
    expect(find.text('playing|Song|1.0'), findsOneWidget);
    expect(builds, 3);
  });

  testWidgets('buildWhen filters rebuilds and sees the last state seen', (
    tester,
  ) async {
    final pairs = <(PlaybackStatus, PlaybackStatus)>[];
    await tester.pumpWidget(
      _app(
        RadioPlayerBuilder(
          buildWhen: (previous, current) {
            pairs.add((previous.status, current.status));
            return previous.nowPlaying != current.nowPlaying;
          },
          builder: (_, state) => Text(_describe(state)),
        ),
      ),
    );

    platform.events.add(_paused);
    await tester.pump();
    platform.events.add(_playing);
    await tester.pump();
    expect(find.text('idle|-|1.0'), findsOneWidget);

    platform.events.add(_titled);
    await tester.pump();
    expect(find.text('playing|Song|1.0'), findsOneWidget);

    platform.events.add(_quieter);
    await tester.pump();
    expect(find.text('playing|Song|1.0'), findsOneWidget);

    expect(pairs, [
      (PlaybackStatus.idle, PlaybackStatus.paused),
      (PlaybackStatus.paused, PlaybackStatus.playing),
      (PlaybackStatus.playing, PlaybackStatus.playing),
      (PlaybackStatus.playing, PlaybackStatus.playing),
    ]);
  });

  testWidgets('stops listening when removed', (tester) async {
    await tester.pumpWidget(
      _app(RadioPlayerBuilder(builder: (_, state) => Text(_describe(state)))),
    );
    await tester.pumpWidget(_app(const SizedBox()));
    platform.events.add(_playing);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ValueListenableBuilder and ListenableBuilder work directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            ValueListenableBuilder<RadioPlayerState>(
              valueListenable: player,
              builder: (_, state, _) => Text('v:${_describe(state)}'),
            ),
            ListenableBuilder(
              listenable: player,
              builder: (_, _) => Text('l:${_describe(player.state)}'),
            ),
          ],
        ),
      ),
    );
    expect(find.text('v:idle|-|1.0'), findsOneWidget);

    platform.events.add(_titled);
    await tester.pump();
    expect(find.text('v:playing|Song|1.0'), findsOneWidget);
    expect(find.text('l:playing|Song|1.0'), findsOneWidget);
  });
}
