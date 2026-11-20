import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_radio_player/testing.dart';
import 'package:flutter_radio_player_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late FakeRadioPlayer fake;

  setUp(() => fake = FakeRadioPlayer.install());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MyApp());
    await tester.pump();
  }

  testWidgets('lists the stations the player holds', (tester) async {
    await pumpApp(tester);
    expect(fake.calls, ['setSources(3)']);
    for (final station in stations) {
      expect(find.widgetWithText(ListTile, station.title!), findsOneWidget);
    }
  });

  testWidgets('tapping a station plays it', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(ListTile, 'River Radio'));
    await tester.pump();

    expect(fake.calls.last, 'play(index: 2)');
    expect(fake.state.currentIndex, 2);
    expect(fake.state.isPlaying, isTrue);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('shows the now-playing title pushed by the player', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    fake.state = fake.state.copyWith(
      nowPlaying: const NowPlayingInfo(title: 'Miles Davis - So What'),
    );
    await tester.pump();

    expect(find.text('Miles Davis - So What'), findsOneWidget);
  });

  testWidgets('shows a progress bar while loading and the error line', (
    tester,
  ) async {
    await pumpApp(tester);
    fake.state = fake.state.copyWith(
      status: PlaybackStatus.loading,
      error: const RadioPlayerError(
        code: RadioPlayerErrorCode.network,
        message: 'offline',
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Reconnecting: offline'), findsOneWidget);
  });
}
