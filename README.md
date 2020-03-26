# Flutter Radio Player Plugin

Flutter radio plugin handles a single streaming media preciously. This plugin was developed with maximum usage in mind.
Flutter Radio player enables Streaming audio content on both Android and iOS natively, as an added feature this plugin supports
background music play as well. This plugin also integrate deeply with both core media capabilities such as MediaSession on Android and
RemoteControl capabilities (Control Center) on iOS. This plugin also support controlling the player via both wearOS and WatchOS.

## Features
* Supports both android and ios
* Supports background music playing
* Integrates well with watchOS and WearOS.
* Handles network interruptions.
* Reactive
* Developer friendly (Logs are placed though out the codebase, so it's easy to trace a bug)

## Reactivity ?
Unlike any other Music Playing plugin Flutter Radio Player is very reactive. It communicates with the native layer using Event and Streams, this
making the plugin very reactive to both Application (Flutter) side and the native side.

### Plugin events
This plugin utilises Android LocalBroadcaster and iOS Notification center for pushing out events. Names of the events are listed below.

* `flutter_radio_playing`
* `flutter_radio_paused`
* `flutter_radio_stopped`
* `flutter_radio_error`
* `flutter_radio_loading`

## Getting Started

Well formatted example is provided on the example application. Kindly refer it for the maximum usage of the plugin
