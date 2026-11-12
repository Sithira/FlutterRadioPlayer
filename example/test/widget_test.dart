import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_radio_player_example/main.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePlatform extends FlutterRadioPlayerPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<RadioPlayerState> states =
      StreamController<RadioPlayerState>.broadcast();
  List<RadioSource> sources = const [];

  @override
  RadioPlayerState get state => const RadioPlayerState();

  @override
  Stream<RadioPlayerState> get stateStream => states.stream;

  @override
  Future<void> initialize(
    List<RadioSource> sources, {
    bool playWhenReady = false,
  }) async {
    this.sources = sources;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('renders the station titles', (tester) async {
    final platform = FakePlatform();
    FlutterRadioPlayerPlatform.instance = platform;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());

    expect(platform.sources, isNotEmpty);
    for (final source in platform.sources) {
      expect(find.text(source.title!), findsOneWidget);
    }
  });
}
