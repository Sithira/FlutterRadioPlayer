package me.sithiramunasinghe.flutter.flutter_radio_player.core.data

import com.google.gson.annotations.SerializedName

data class FRPVolumeChangeEvent(
        @SerializedName("volume")
        val volume: Float = 0.5F
)
