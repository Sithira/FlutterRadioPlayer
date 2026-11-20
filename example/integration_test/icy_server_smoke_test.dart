import 'dart:io' show Platform;

import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'fixtures/icy_server.dart';

const _timeout = Duration(seconds: 30);

Future<RadioPlayerState> _waitFor(
  FlutterRadioPlayer player,
  bool Function(RadioPlayerState state) test,
) {
  if (test(player.state)) return Future.value(player.state);
  return player.stateStream.firstWhere(test).timeout(_timeout);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late IcyServer server;
  final player = FlutterRadioPlayer.instance;

  setUp(() async => server = await IcyServer.start(title: 'Smoke Title'));

  tearDown(() async {
    await player.dispose();
    await server.close();
  });

  testWidgets('plays the local ICY stream and follows title changes',
      (tester) async {
    await player.initialize(
      [RadioSource(url: server.url(), title: 'Local Station')],
      playWhenReady: true,
    );

    final playing = await _waitFor(
      player,
      (s) =>
          s.status == PlaybackStatus.playing &&
          s.nowPlaying?.title == 'Smoke Title',
    );
    expect(playing.error, isNull);
    expect(server.requestCount, greaterThanOrEqualTo(1));

    server.setTitle('Second Title');
    await _waitFor(player, (s) => s.nowPlaying?.title == 'Second Title');

    // ignore: avoid_print
    print(
      'ICY_SMOKE[${Platform.operatingSystem}] requests=${server.requestCount} '
      'icy-metadata=${server.lastHeaders['icy-metadata']} '
      'user-agent=${server.lastHeaders['user-agent']}',
    );
  });
}
