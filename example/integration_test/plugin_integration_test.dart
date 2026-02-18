import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_radio_player/flutter_radio_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FlutterRadioPlayer can be instantiated', (WidgetTester tester) async {
    final player = FlutterRadioPlayer();
    expect(player, isNotNull);
  });
}
