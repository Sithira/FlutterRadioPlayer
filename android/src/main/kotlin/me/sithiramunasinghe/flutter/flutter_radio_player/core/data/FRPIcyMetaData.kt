package me.sithiramunasinghe.flutter.flutter_radio_player.core.data

import com.google.android.exoplayer2.MediaMetadata

data class FRPIcyMetaData(private val meta: MediaMetadata?) {
    var title: String? = null
    var artistName: String? = null

    init {
        this.title = meta?.title?.toString()
        this.artistName = meta?.albumArtist?.toString()
    }
}