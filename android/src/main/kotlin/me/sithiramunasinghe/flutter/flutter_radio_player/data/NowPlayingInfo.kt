package me.sithiramunasinghe.flutter.flutter_radio_player.data

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
data class NowPlayingInfo(
    val title: String? = null,
    val album: String? = null
) {
    fun toJson(): String {
        return Json.encodeToString(this)
    }
}
