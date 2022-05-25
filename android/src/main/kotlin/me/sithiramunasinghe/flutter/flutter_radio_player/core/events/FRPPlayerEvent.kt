package me.sithiramunasinghe.flutter.flutter_radio_player.core.events

import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPIcyMetaData

data class FRPPlayerEvent(
    val data: String? = null,
    val playbackStatus: String? = null,
    val FRPIcyMetaData: FRPIcyMetaData? = null
)