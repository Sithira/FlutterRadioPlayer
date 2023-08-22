package me.sithiramunasinghe.flutter.flutter_radio_player.core.data

import com.google.gson.annotations.SerializedName

data class FRPCurrentSource(
    @SerializedName("title")
    val title: String? = null,

    @SerializedName("description")
    val description: String? = null
)
