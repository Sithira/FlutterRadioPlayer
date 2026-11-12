import 'dart:async';

import 'package:flutter_radio_player_ios/flutter_radio_player_ios.dart';
import 'package:flutter_radio_player_ios/src/messages.g.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHostApi implements RadioPlayerHostApi {
  final List<String> calls = [];
  RadioPlayerStateMessage stateToReturn = _message();

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
    return stateToReturn;
  }

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';

  @override
  // ignore: non_constant_identifier_names
  get pigeonVar_binaryMessenger => null;
}

RadioPlayerStateMessage _message({
  PlaybackStatusMessage status = PlaybackStatusMessage.idle,
  int? currentIndex,
  String? nowPlayingTitle,
  double volume = 0.5,
  RadioPlayerErrorMessage? error,
}) {
  return RadioPlayerStateMessage(
    status: status,
    currentIndex: currentIndex,
    nowPlayingTitle: nowPlayingTitle,
    volume: volume,
    error: error,
  );
}

const _sources = [
  RadioSource(url: 'https://a.example/stream', title: 'A'),
  RadioSource(url: 'https://b.example/stream', title: 'B'),
];

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeHostApi hostApi;
  late StreamController<RadioPlayerStateMessage> events;
  late FlutterRadioPlayerIos player;
  var nativeSubscriptions = 0;

  setUp(() {
    hostApi = _FakeHostApi();
    nativeSubscriptions = 0;
    events = StreamController<RadioPlayerStateMessage>.broadcast();
    player = FlutterRadioPlayerIos(
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

  test('registerWith sets platform instance', () {
    FlutterRadioPlayerIos.registerWith();
    expect(
      FlutterRadioPlayerPlatform.instance,
      isA<FlutterRadioPlayerIos>(),
    );
  });

  group('delegation', () {
    test('forwards transport calls to the host api', () async {
      await player.initialize(_sources, playWhenReady: true);
      await player.play();
      await player.pause();
      await player.playOrPause();
      await player.setVolume(0.7);
      expect(await player.getVolume(), 0.25);
      await player.nextSource();
      await player.previousSource();
      await player.jumpToSourceAtIndex(1);
      expect(hostApi.calls, [
        'initialize:2:true',
        'play',
        'pause',
        'playOrPause',
        'setVolume:0.7',
        'getVolume',
        'nextSource',
        'previousSource',
        'jumpToSourceAtIndex:1',
      ]);
    });

    test('dispose calls the host api then refreshes the state', () async {
      await player.dispose();
      expect(hostApi.calls, ['dispose', 'getState']);
    });
  });

  group('state mapping', () {
    test('state is the default before any snapshot arrives', () {
      expect(player.state, const RadioPlayerState());
    });

    test('maps all five statuses one to one', () async {
      final seen = <PlaybackStatus>[];
      player.stateStream.listen((s) => seen.add(s.status));
      for (final status in PlaybackStatusMessage.values) {
        events.add(_message(status: status));
      }
      await _pump();
      expect(seen, PlaybackStatus.values);
    });

    test('resolves the current source from the index', () async {
      player.state;
      await player.initialize(_sources);
      events
          .add(_message(status: PlaybackStatusMessage.paused, currentIndex: 1));
      await _pump();
      expect(player.state.currentIndex, 1);
      expect(player.state.currentSource, _sources[1]);
    });

    test('out-of-range and null index give a null source', () async {
      player.state;
      await player.initialize(_sources);
      events.add(_message(currentIndex: 5));
      await _pump();
      expect(player.state.currentIndex, 5);
      expect(player.state.currentSource, isNull);
      events.add(_message(currentIndex: -1));
      await _pump();
      expect(player.state.currentSource, isNull);
      events.add(_message());
      await _pump();
      expect(player.state.currentIndex, isNull);
      expect(player.state.currentSource, isNull);
    });

    test('maps the title to nowPlaying and null to null', () async {
      player.state;
      events.add(_message(nowPlayingTitle: 'Song'));
      await _pump();
      expect(player.state.nowPlaying, const NowPlayingInfo(title: 'Song'));
      events.add(_message());
      await _pump();
      expect(player.state.nowPlaying, isNull);
    });

    test('maps the error and every error code', () async {
      player.state;
      for (final code in RadioPlayerErrorCodeMessage.values) {
        events.add(_message(
          status: PlaybackStatusMessage.error,
          error: RadioPlayerErrorMessage(code: code, message: 'boom'),
        ));
        await _pump();
        expect(player.state.status, PlaybackStatus.error);
        expect(
          player.state.error,
          RadioPlayerError(
            code: RadioPlayerErrorCode.values.byName(code.name),
            message: 'boom',
          ),
        );
      }
      events.add(_message());
      await _pump();
      expect(player.state.error, isNull);
    });

    test('maps the volume', () async {
      player.state;
      events.add(_message(volume: 0.8));
      await _pump();
      expect(player.state.volume, 0.8);
    });

    test('dispose clears the sources', () async {
      await player.initialize(_sources);
      hostApi.stateToReturn = _message(currentIndex: 0);
      await player.dispose();
      expect(player.state.currentIndex, 0);
      expect(player.state.currentSource, isNull);
    });
  });

  group('stateStream', () {
    test('subscribes to the native stream once', () async {
      player.state;
      player.stateStream.listen((_) {});
      player.stateStream.listen((_) {});
      player.isPlayingStream.listen((_) {});
      await player.initialize(_sources);
      expect(nativeSubscriptions, 1);
    });

    test('is a cached broadcast stream', () {
      expect(identical(player.stateStream, player.stateStream), isTrue);
      expect(player.stateStream.isBroadcast, isTrue);
    });

    test('cancelling one listener leaves the other receiving', () async {
      final first = <PlaybackStatus>[];
      final second = <PlaybackStatus>[];
      final firstSub = player.stateStream.listen((s) => first.add(s.status));
      player.stateStream.listen((s) => second.add(s.status));
      events.add(_message(status: PlaybackStatusMessage.loading));
      await _pump();
      await firstSub.cancel();
      events.add(_message(status: PlaybackStatusMessage.playing));
      await _pump();
      expect(first, [PlaybackStatus.loading]);
      expect(second, [PlaybackStatus.loading, PlaybackStatus.playing]);
    });

    test('a late subscriber receives the latest snapshot first', () async {
      player.stateStream.listen((_) {});
      events.add(_message(status: PlaybackStatusMessage.loading));
      events.add(_message(status: PlaybackStatusMessage.playing));
      await _pump();
      final late = <PlaybackStatus>[];
      player.stateStream.listen((s) => late.add(s.status));
      await _pump();
      expect(late, [PlaybackStatus.playing]);
      events.add(_message(status: PlaybackStatusMessage.paused));
      await _pump();
      expect(late, [PlaybackStatus.playing, PlaybackStatus.paused]);
    });

    test('a subscriber before any snapshot gets nothing until one arrives',
        () async {
      final seen = <PlaybackStatus>[];
      player.stateStream.listen((s) => seen.add(s.status));
      await _pump();
      expect(seen, isEmpty);
      events.add(_message(status: PlaybackStatusMessage.paused));
      await _pump();
      expect(seen, [PlaybackStatus.paused]);
    });
  });

  group('legacy streams', () {
    test('are cached broadcast streams', () {
      expect(identical(player.isPlayingStream, player.isPlayingStream), isTrue);
      expect(
          identical(player.nowPlayingStream, player.nowPlayingStream), isTrue);
      expect(identical(player.volumeStream, player.volumeStream), isTrue);
      expect(player.isPlayingStream.isBroadcast, isTrue);
      expect(player.nowPlayingStream.isBroadcast, isTrue);
      expect(player.volumeStream.isBroadcast, isTrue);
    });

    test('two listeners behave the same and none replays on listen', () async {
      player.stateStream.listen((_) {});
      events.add(_message(status: PlaybackStatusMessage.paused, volume: 0.1));
      await _pump();

      final playingA = <bool>[];
      final playingB = <bool>[];
      final titleA = <String?>[];
      final titleB = <String?>[];
      final volumeA = <VolumeInfo>[];
      final volumeB = <VolumeInfo>[];
      final playingSub = player.isPlayingStream.listen(playingA.add);
      player.isPlayingStream.listen(playingB.add);
      final titleSub =
          player.nowPlayingStream.listen((i) => titleA.add(i.title));
      player.nowPlayingStream.listen((i) => titleB.add(i.title));
      final volumeSub = player.volumeStream.listen(volumeA.add);
      player.volumeStream.listen(volumeB.add);
      await _pump();
      expect(playingA, isEmpty);
      expect(titleA, isEmpty);
      expect(volumeA, isEmpty);

      events.add(_message(
        status: PlaybackStatusMessage.playing,
        nowPlayingTitle: 'X',
        volume: 0.6,
      ));
      await _pump();
      expect(playingA, [true]);
      expect(playingB, [true]);
      expect(titleA, ['X']);
      expect(titleB, ['X']);
      expect(volumeA, [const VolumeInfo(volume: 0.6, isMuted: false)]);
      expect(volumeB, volumeA);

      await playingSub.cancel();
      await titleSub.cancel();
      await volumeSub.cancel();
      events.add(_message(status: PlaybackStatusMessage.paused, volume: 0));
      await _pump();
      expect(playingA, [true]);
      expect(playingB, [true, false]);
      expect(volumeB.last, const VolumeInfo(volume: 0, isMuted: true));
    });

    test('the first snapshot is a baseline and emits nothing', () async {
      final playing = <bool>[];
      final titles = <String?>[];
      final volumes = <VolumeInfo>[];
      player.isPlayingStream.listen(playing.add);
      player.nowPlayingStream.listen((i) => titles.add(i.title));
      player.volumeStream.listen(volumes.add);
      events.add(_message(
        status: PlaybackStatusMessage.playing,
        nowPlayingTitle: 'X',
        volume: 0.9,
      ));
      await _pump();
      expect(playing, isEmpty);
      expect(titles, isEmpty);
      expect(volumes, isEmpty);
    });

    test('loading counts as playing and playing after loading adds nothing',
        () async {
      final playing = <bool>[];
      player.isPlayingStream.listen(playing.add);
      events.add(_message(status: PlaybackStatusMessage.paused));
      await _pump();
      events.add(_message(status: PlaybackStatusMessage.loading));
      await _pump();
      events.add(_message(status: PlaybackStatusMessage.playing));
      await _pump();
      events.add(_message(status: PlaybackStatusMessage.paused));
      await _pump();
      expect(playing, [true, false]);
    });

    test('a later playing snapshot emits true', () async {
      final playing = <bool>[];
      player.isPlayingStream.listen(playing.add);
      events.add(_message(status: PlaybackStatusMessage.paused));
      events.add(_message(status: PlaybackStatusMessage.playing));
      await _pump();
      expect(playing, [true]);
    });

    test('error counts as not playing', () async {
      final playing = <bool>[];
      player.isPlayingStream.listen(playing.add);
      events.add(_message(status: PlaybackStatusMessage.playing));
      events.add(_message(
        status: PlaybackStatusMessage.error,
        error: RadioPlayerErrorMessage(
          code: RadioPlayerErrorCodeMessage.network,
          message: 'offline',
        ),
      ));
      await _pump();
      expect(playing, [false]);
    });

    test('a null then X title sequence emits twice and a repeat once',
        () async {
      final titles = <String?>[];
      player.nowPlayingStream.listen((i) => titles.add(i.title));
      events.add(_message(nowPlayingTitle: 'X'));
      events.add(_message());
      events.add(_message(nowPlayingTitle: 'X'));
      events.add(_message(nowPlayingTitle: 'X', volume: 0.7));
      await _pump();
      expect(titles, [null, 'X']);
    });
  });
}
