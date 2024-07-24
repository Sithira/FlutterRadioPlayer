package me.sithiramunasinghe.flutter.flutter_radio_player.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class FlutterRadioVolumeChanged(var volume: Float, var isMuted: Boolean) {
    fun toJson(): String {
        return Json.encodeToString(this)
    }
}