/// Online radio streaming with background playback, lock-screen controls and
/// ICY now-playing titles on Android and iOS.
library;

export 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart'
    show
        AndroidOptions,
        NowPlayingInfo,
        PlaybackStatus,
        RadioPlayerError,
        RadioPlayerErrorCode,
        RadioPlayerOptions,
        RadioPlayerState,
        RadioSource,
        ReconnectPolicy;

export 'src/flutter_radio_player.dart' show FlutterRadioPlayer;
