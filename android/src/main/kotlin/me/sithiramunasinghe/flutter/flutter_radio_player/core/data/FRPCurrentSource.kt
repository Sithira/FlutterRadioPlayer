package me.sithiramunasinghe.flutter.flutter_radio_player.core.data

import kotlinx.serialization.Serializable

@Serializable
data class FRPCurrentSource(
    val title: String? = null,
    val description: String? = null
)
