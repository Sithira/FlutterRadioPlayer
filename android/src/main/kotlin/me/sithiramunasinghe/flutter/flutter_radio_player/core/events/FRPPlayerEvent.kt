package me.sithiramunasinghe.flutter.flutter_radio_player.core.events

import com.google.gson.annotations.SerializedName
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPCurrentSource
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPVolumeChangeEvent

data class FRPPlayerEvent(
    @SerializedName("type")
    val type: String? = null,

    @SerializedName("currentSource")
    val currentSource: FRPCurrentSource? = null,

    @SerializedName("volumeChangeEvent")
    val volumeChangeEvent: FRPVolumeChangeEvent? = null,

    @SerializedName("playbackStatus")
    val playbackStatus: String? = null,

    @SerializedName("icyMetaDetails")
    val icyMetaDetails: String? = null
)