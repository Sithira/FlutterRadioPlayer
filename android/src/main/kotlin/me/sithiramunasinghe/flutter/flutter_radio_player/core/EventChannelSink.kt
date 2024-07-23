package me.sithiramunasinghe.flutter.flutter_radio_player.core

import io.flutter.plugin.common.EventChannel


class EventChannelSink private constructor() {
    lateinit var playbackEventChannel: EventChannel
    lateinit var nowPlayingEventChannel: EventChannel
    lateinit var playbackVolumeChannel: EventChannel
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