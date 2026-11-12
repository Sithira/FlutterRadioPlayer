import 'dart:async';

import 'package:flutter_radio_player_android/flutter_radio_player_android.dart';
import 'package:flutter_radio_player_android/src/messages.g.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHostApi implements RadioPlayerHostApi {
  final List<String> calls = [];
  RadioPlayerStateMessage stateOnGet = _message();

  @override
  Future<void> initialize(
    List<RadioSourceMessage> sources,
    bool playWhenReady,
  ) async {
    calls.add('initialize:${sources.length}:$playWhenReady');
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> playOrPause() async => calls.add('playOrPause');

  @override
  Future<void> setVolume(double volume) async => calls.add('setVolume:$volume');

  @override
  Future<double> getVolume() async {
    calls.add('getVolume');
    return 0.25;
  }

  @override
  Future<void> nextSource() async => calls.add('nextSource');

  @override
  Future<void> previousSource() async => calls.add('previousSource');

  @override
  Future<void> jumpToSourceAtIndex(int index) async =>
      calls.add('jumpToSourceAtIndex:$index');

  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  Future<RadioPlayerStateMessage> getState() async {
    calls.add('getState');
    return stateOnGet;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RadioPlayerStateMessage _message({
  PlaybackStatusMessage status = PlaybackStatusMessage.idle,
  int? currentIndex,
  String? title,
  double volume = 0.5,
  RadioPlayerErrorMessage? error,
}) {
  return RadioPlayerStateMessage(
    status: status,
    currentIndex: currentIndex,
    nowPlayingTitle: title,
    volume: volume,
    error: error,
  );
}

const _sources = [
  RadioSource(url: 'https://a.example/stream', title: 'A'),
  RadioSource(url: 'https://b.example/stream', title: 'B'),
];

void main() {
  late FakeHostApi hostApi;
  late StreamController<RadioPlayerStateMessage> events;
  late int nativeSubscriptions;
  late FlutterRadioPlayerAndroid player;

  setUp(() {
    hostApi = FakeHostApi();
    nativeSubscriptions = 0;
    events = StreamController<RadioPlayerStateMessage>.broadcast();
    player = FlutterRadioPlayerAndroid(
      hostApi: hostApi,
      stateEvents: () {
        nativeSubscriptions++;
        return events.stream;
      },
    );
  });

  tearDown(() async {
    await events.close();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('registerWith sets platform instance', () {
    FlutterRadioPlayerAndroid.registerWith();
    expect(
      FlutterRadioPlayerPlatform.instance,
      isA<FlutterRadioPlayerAndroid>(),
    );
  });

  group('delegation', () {
    test('forwards transport calls to the host api', () async {
      await player.initialize(_sources, playWhenReady: true);
      await player.play();
      await player.pause();
      await player.playOrPause();
      await player.setVolume(0.3);
      expect(await player.getVolume(), 0.25);
      await player.nextSource();
      await player.previousSource();
      await player.jumpToSourceAtIndex(1);
      expect(hostApi.calls, [
        'initialize:2:true',
        'play',
        'pause',
        'playOrPause',
        'setVolume:0.3',
        'getVolume',
        'nextSource',
        'previousSource',
        'jumpToSourceAtIndex:1',
      ]);
    });
  });

  group('state mapping', () {
    test('state is the default before any snapshot', () {
      expect(player.state, const RadioPlayerState());
    });

    test('maps all five statuses', () async {
      final states = <RadioPlayerState>[];
      player.stateStream.listen(states.add);
      for (final status in PlaybackStatusMessage.values) {
        events.add(_message(status: status));
      }
      await pump();
      expect(states.map((s) => s.status), PlaybackStatus.values);
    });

    test('resolves the current source from the index', () async {
      await player.initialize(_sources);
      final states = <RadioPlayerState>[];
      player.stateStream.listen(states.add);
      events.add(_message(currentIndex: 1));
      events.add(_message(currentIndex: 5));
      events.add(_message(currentIndex: -1));
      events.add(_message());
      await pump();
      expect(states[0].currentIndex, 1);
      expect(states[0].currentSource, _sources[1]);
      expect(states[1].currentIndex, 5);
      expect(states[1].currentSource, isNull);
      expect(states[2].currentSource, isNull);
      expect(states[3].currentIndex, isNull);
      expect(states[3].currentSource, isNull);
    });

    test('maps title and volume', () async {
      final states = <RadioPlayerState>[];
      player.stateStream.listen(states.add);
      events.add(_message(title: 'Song', volume: 0.8));
      events.add(_message());
      await pump();
      expect(states[0].nowPlaying, const NowPlayingInfo(title: 'Song'));
      expect(states[0].volume, 0.8);
      expect(states[1].nowPlaying, isNull);
    });

    test('maps every error code and message', () async {
      final states = <RadioPlayerState>[];
      player.stateStream.listen(states.add);
      for (final code in RadioPlayerErrorCodeMessage.values) {
        events.add(
          _message(
            status: PlaybackStatusMessage.error,
            error: RadioPlayerErrorMessage(code: code, message: 'm-$code'),
          ),
        );
      }
      events.add(_message(status: PlaybackStatusMessage.paused));
      await pump();
      for (var i = 0; i < RadioPlayerErrorCodeMessage.values.length; i++) {
        expect(states[i].status, PlaybackStatus.error);
        expect(states[i].error?.code, RadioPlayerErrorCode.values[i]);
        expect(
          states[i].error?.message,
          'm-${RadioPlayerErrorCodeMessage.values[i]}',
        );
      }
      expect(states.last.error, isNull);
    });
  });

  group('stateStream', () {
    test('uses a single native subscription', () async {
      player.stateStream.listen((_) {});
      player.stateStream.listen((_) {});
      player.isPlayingStream.listen((_) {});
      player.nowPlayingStream.listen((_) {});
      player.volumeStream.listen((_) {});
      await player.initialize(_sources);
      expect(player.state, const RadioPlayerState());
      expect(nativeSubscriptions, 1);
    });

    test('is the same stream object on every access', () {
      expect(identical(player.stateStream, player.stateStream), isTrue);
      expect(player.stateStream.isBroadcast, isTrue);
    });

    test('cancelling one listener keeps the other receiving', () async {
      final first = <RadioPlayerState>[];
      final second = <RadioPlayerState>[];
      final firstSub = player.stateStream.listen(first.add);
      player.stateStream.listen(second.add);
      events.add(_message(status: PlaybackStatusMessage.loading));
      await pump();
      await firstSub.cancel();
      events.add(_message(status: PlaybackStatusMessage.playing));
      await pump();
      expect(first.length, 1);
      expect(second.map((s) => s.status), [
        PlaybackStatus.loading,
        PlaybackStatus.playing,
      ]);
    });

    test('a late subscriber receives the latest snapshot first', () async {
      player.stateStream.listen((_) {});
      events.add(_message(status: PlaybackStatusMessage.loading));
      events.add(_message(status: PlaybackStatusMessage.playing));
      await pump();
      final late = <RadioPlayerState>[];
      player.stateStream.listen(late.add);
      await pump();
      expect(late.map((s) => s.status), [PlaybackStatus.playing]);
      events.add(_message(status: PlaybackStatusMessage.paused));
      await pump();
      expect(late.map((s) => s.status), [
        PlaybackStatus.playing,
        PlaybackStatus.paused,
      ]);
      expect(player.state.status, PlaybackStatus.paused);
    });

    test('a subscriber before any snapshot gets nothing until one arrives',
        () async {
      final states = <RadioPlayerState>[];
      player.stateStream.listen(states.add);
      await pump();
      expect(states, isEmpty);
    });

    test('does not emit a snapshot equal to the previous one', () async {
      final states = <RadioPlayerState>[];
      player.stateStream.listen(states.add);
      events.add(_message(status: PlaybackStatusMessage.playing));
      events.add(_message(status: PlaybackStatusMessage.playing));
      events.add(_message(status: PlaybackStatusMessage.paused));
      events.add(_message(status: PlaybackStatusMessage.playing));
      await pump();
      expect(states.map((s) => s.status), [
        PlaybackStatus.playing,
        PlaybackStatus.paused,
        PlaybackStatus.playing,
      ]);
    });

    test('a refresh after dispose does not repeat an identical snapshot',
        () async {
      final states = <RadioPlayerState>[];
      player.stateStream.listen(states.add);
      events.add(_message());
      await pump();
      await player.dispose();
      await pump();
      expect(states, [const RadioPlayerState()]);
    });
  });

  group('legacy streams', () {
    test('are cached broadcast streams', () {
      expect(identical(player.isPlayingStream, player.isPlayingStream), isTrue);
      expect(
        identical(player.nowPlayingStream, player.nowPlayingStream),
        isTrue,
      );
      expect(identical(player.volumeStream, player.volumeStream), isTrue);
      expect(player.isPlayingStream.isBroadcast, isTrue);
      expect(player.nowPlayingStream.isBroadcast, isTrue);
      expect(player.volumeStream.isBroadcast, isTrue);
    });

    test('two listeners behave the same and none replays', () async {
      player.stateStream.listen((_) {});
      events.add(_message());
      await pump();

      final playingA = <bool>[];
      final playingB = <bool>[];
      final titleA = <String?>[];
      final titleB = <String?>[];
      final volumeA = <VolumeInfo>[];
      final volumeB = <VolumeInfo>[];
      player.isPlayingStream.listen(playingA.add);
      player.isPlayingStream.listen(playingB.add);
      player.nowPlayingStream.listen((e) => titleA.add(e.title));
      player.nowPlayingStream.listen((e) => titleB.add(e.title));
      player.volumeStream.listen(volumeA.add);
      player.volumeStream.listen(volumeB.add);
      await pump();
      expect(playingA, isEmpty);
      expect(titleA, isEmpty);
      expect(volumeA, isEmpty);

      events.add(
        _message(
          status: PlaybackStatusMessage.playing,
          title: 'X',
          volume: 0.7,
        ),
      );
      await pump();
      expect(playingA, [true]);
      expect(playingB, [true]);
      expect(titleA, ['X']);
      expect(titleB, ['X']);
      expect(volumeA, [const VolumeInfo(volume: 0.7, isMuted: false)]);
      expect(volumeB, volumeA);
    });

    test('the first snapshot is only a baseline', () async {
      final playing = <bool>[];
      final titles = <String?>[];
      final volumes = <VolumeInfo>[];
      player.isPlayingStream.listen(playing.add);
      player.nowPlayingStream.listen((e) => titles.add(e.title));
      player.volumeStream.listen(volumes.add);
      events.add(
        _message(
          status: PlaybackStatusMessage.playing,
          title: 'X',
          volume: 0.9,
        ),
      );
      await pump();
      expect(playing, isEmpty);
      expect(titles, isEmpty);
      expect(volumes, isEmpty);
    });

    test('loading and playing on isPlayingStream', () async {
      final playing = <bool>[];
      player.isPlayingStream.listen(playing.add);
      events.add(_message(status: PlaybackStatusMessage.paused));
      events.add(_message(status: PlaybackStatusMessage.loading));
      await pump();
      expect(playing, isEmpty);
      events.add(_message(status: PlaybackStatusMessage.playing));
      events.add(_message(status: PlaybackStatusMessage.playing, volume: 0.6));
      events.add(_message(status: PlaybackStatusMessage.paused));
      await pump();
      expect(playing, [true, false]);
    });

    test('a later playing snapshot emits true', () async {
      final playing = <bool>[];
      player.isPlayingStream.listen(playing.add);
      events.add(_message(status: PlaybackStatusMessage.paused));
      events.add(_message(status: PlaybackStatusMessage.playing));
      await pump();
      expect(playing, [true]);
    });

    test('an error snapshot counts as not playing', () async {
      final playing = <bool>[];
      player.isPlayingStream.listen(playing.add);
      events.add(_message(status: PlaybackStatusMessage.playing));
      events.add(
        _message(
          status: PlaybackStatusMessage.error,
          error: RadioPlayerErrorMessage(
            code: RadioPlayerErrorCodeMessage.network,
            message: 'offline',
          ),
        ),
      );
      await pump();
      expect(playing, [false]);
    });

    test('title null then X emits twice and a repeated X once', () async {
      final titles = <String?>[];
      player.nowPlayingStream.listen((e) => titles.add(e.title));
      events.add(_message(title: 'Old'));
      events.add(_message());
      events.add(_message(title: 'X'));
      events.add(_message(title: 'X', volume: 0.4));
      await pump();
      expect(titles, [null, 'X']);
    });

    test('volume zero is muted', () async {
      final volumes = <VolumeInfo>[];
      player.volumeStream.listen(volumes.add);
      events.add(_message());
      events.add(_message(volume: 0));
      await pump();
      expect(volumes, [const VolumeInfo(volume: 0, isMuted: true)]);
    });
  });

  group('dispose', () {
    test('calls the host api then refreshes the state', () async {
      await player.dispose();
      expect(hostApi.calls, ['dispose', 'getState']);
    });

    test('clears sources and refreshes the cached state', () async {
      await player.initialize(_sources);
      events.add(
        _message(status: PlaybackStatusMessage.playing, currentIndex: 0),
      );
      await pump();
      expect(player.state.currentSource, _sources[0]);

      hostApi.stateOnGet = _message();
      await player.dispose();
      expect(hostApi.calls.last, 'getState');
      expect(player.state, const RadioPlayerState());

      events
          .add(_message(status: PlaybackStatusMessage.paused, currentIndex: 0));
      await pump();
      expect(player.state.currentSource, isNull);
    });

    test('initialize with a new list re-derives the current source', () async {
      const other = [RadioSource(url: 'https://c.example/stream', title: 'C')];
      final states = <RadioPlayerState>[];
      player.stateStream.listen(states.add);
      await player.initialize(_sources);
      events.add(
        _message(status: PlaybackStatusMessage.paused, currentIndex: 0),
      );
      await pump();
      expect(player.state.currentSource, _sources[0]);

      await player.initialize(other);
      await pump();
      expect(player.state.currentSource, other[0]);
      expect(states.map((s) => s.currentSource), [_sources[0], other[0]]);
    });

    test('dispose re-derives the current source from an equal snapshot',
        () async {
      final states = <RadioPlayerState>[];
      player.stateStream.listen(states.add);
      await player.initialize(_sources);
      final message =
          _message(status: PlaybackStatusMessage.paused, currentIndex: 0);
      events.add(message);
      await pump();
      expect(player.state.currentSource, _sources[0]);

      hostApi.stateOnGet = message;
      await player.dispose();
      await pump();
      expect(player.state.currentIndex, 0);
      expect(player.state.currentSource, isNull);
      expect(states.last.currentSource, isNull);
    });
  });
}
