import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform extends FlutterRadioPlayerPlatform
    with MockPlatformInterfaceMixin {}

class _ImplementsPlatform implements FlutterRadioPlayerPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('accepts an implementation that extends the interface', () {
    final fake = _FakePlatform();
    FlutterRadioPlayerPlatform.instance = fake;
    expect(FlutterRadioPlayerPlatform.instance, same(fake));
  });

  test('rejects an implementation that only implements the interface', () {
    expect(
      () => FlutterRadioPlayerPlatform.instance = _ImplementsPlatform(),
      throwsA(isA<AssertionError>()),
    );
  });

  test('every member throws UnimplementedError by default', () {
    final platform = _FakePlatform();
    expect(() => platform.stateStream, throwsUnimplementedError);
    expect(() => platform.setSources(const []), throwsUnimplementedError);
    expect(
      () => platform.setOptions(const RadioPlayerOptions()),
      throwsUnimplementedError,
    );
    expect(() => platform.play(), throwsUnimplementedError);
    expect(() => platform.play(index: 1), throwsUnimplementedError);
    expect(() => platform.pause(), throwsUnimplementedError);
    expect(() => platform.playOrPause(), throwsUnimplementedError);
    expect(() => platform.stop(), throwsUnimplementedError);
    expect(() => platform.next(), throwsUnimplementedError);
    expect(() => platform.previous(), throwsUnimplementedError);
    expect(() => platform.setVolume(0.5), throwsUnimplementedError);
  });
}
