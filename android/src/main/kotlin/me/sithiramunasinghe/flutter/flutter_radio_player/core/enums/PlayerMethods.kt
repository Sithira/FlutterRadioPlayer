package me.sithiramunasinghe.flutter.flutter_radio_player.core.enums

enum class PlayerMethods(val value: String) {
    INIT("initService"),
    PLAY_PAUSE("playOrPause"),
    PLAY("play"),
    PAUSE("pause"),
    STOP("stop"),
    SET_URL("setUrl"),
    IS_PLAYING("isPlaying"),
    SET_VOLUME("setVolume")
}