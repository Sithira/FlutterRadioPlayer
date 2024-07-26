package me.sithiramunasinghe.flutter.flutter_radio_player.core

import io.flutter.plugin.common.EventChannel


class EventChannelSink private constructor() {
    var playbackEventChannel: EventChannel? = null
    var nowPlayingEventChannel: EventChannel? = null
    var playbackVolumeChannel: EventChannel? = null
    companion object {

        @Volatile
        private var instance: EventChannelSink? = null

        fun getInstance(): EventChannelSink {
            if (instance == null) {
                synchronized(this) {
                    if (instance == null) {
                        instance = EventChannelSink()
                    }
                }
            }
            return instance!!
        }
    }
}