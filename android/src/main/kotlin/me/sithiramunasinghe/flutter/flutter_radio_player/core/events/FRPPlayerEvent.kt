package me.sithiramunasinghe.flutter.flutter_radio_player.core.events

import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPCurrentSource
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPIcyMetaData
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPVolumeChangeEvent

data class FRPPlayerEvent(
    val type: String? = null,
    val currentSource: FRPCurrentSource? = null,
    val volumeChangeEvent: FRPVolumeChangeEvent? = null,
    val playbackStatus: String? = null,
    val icyMetaDetails: String? = null
)