# flutter_radio_player_platform_interface

A common platform interface for the [`flutter_radio_player`](https://pub.dev/packages/flutter_radio_player) plugin.

This interface allows platform-specific implementations of the `flutter_radio_player` plugin, as well as the plugin itself, to ensure they are supporting the same interface.

## Usage

To implement a new platform-specific implementation of `flutter_radio_player`, extend `FlutterRadioPlayerPlatform` with an implementation that performs the platform-specific behavior.

## Note

This package is not intended for direct use by app developers. Instead, use [`flutter_radio_player`](https://pub.dev/packages/flutter_radio_player) which provides the app-facing API.
