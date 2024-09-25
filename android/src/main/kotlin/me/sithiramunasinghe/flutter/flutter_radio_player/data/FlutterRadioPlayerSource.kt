package me.sithiramunasinghe.flutter.flutter_radio_player.data

import kotlinx.serialization.Serializable

@Serializable
data class FlutterRadioPlayerSource(
    var url: String,
    var title: String? = null,
    var artwork: String? = null,
    var playWhenReady: Boolean = false
)
