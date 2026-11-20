import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads are idle without a registered platform', () async {
    final player = FlutterRadioPlayer.instance;
    expect(player.state, const RadioPlayerState());
    expect(player.value, const RadioPlayerState());
    expect(await player.stateStream.first, const RadioPlayerState());
    expect(() => player.addListener(() {}), returnsNormally);
  });

  test('commands fail through the future without a platform', () {
    expect(FlutterRadioPlayer.instance.play(), throwsStateError);
  });
}
