package me.sithiramunasinghe.flutter.flutter_radio_player.core.enums

enum class PlayerMethods(val value: String) {
    INIT("initService"),
//    INIT("setC"),

    PLAY_PAUSE("playOrPause"),
    PLAY("play"),
    NEW_PLAY("newPlay"),

    PAUSE("pause"),
    STOP("stop"),
    SET_TITLE("setTitle"),
    SET_URL("setUrl"),
    IS_PLAYING("isPlaying"),
    SET_VOLUME("setVolume")
}