package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.os.Handler
import android.os.Looper
import me.sithiramunasinghe.flutter.flutter_radio_player.PigeonEventSink
import me.sithiramunasinghe.flutter.flutter_radio_player.PlaybackStatusMessage
import me.sithiramunasinghe.flutter.flutter_radio_player.RadioPlayerErrorMessage
import me.sithiramunasinghe.flutter.flutter_radio_player.RadioPlayerStateMessage

object RadioStateStore {

    private const val DEFAULT_VOLUME = 0.5

    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: PigeonEventSink<RadioPlayerStateMessage>? = null

    private var playerStatus = PlaybackStatusMessage.IDLE
    private var currentIndex: Long? = null
    private var volume = DEFAULT_VOLUME
    private var nowPlayingTitle: String? = null
    private var error: RadioPlayerErrorMessage? = null

    private var snapshot = compose()

    @Synchronized
    fun snapshot(): RadioPlayerStateMessage = snapshot

    @Synchronized
    fun attachSink(newSink: PigeonEventSink<RadioPlayerStateMessage>) {
        sink = newSink
        val current = snapshot
        mainHandler.post { newSink.success(current) }
    }

    @Synchronized
    fun detachSink() {
        sink = null
    }

    @Synchronized
    fun updatePlayer(status: PlaybackStatusMessage, index: Long?, newVolume: Double) {
        playerStatus = status
        currentIndex = index
        volume = newVolume
        publish()
    }

    @Synchronized
    fun setNowPlayingTitle(title: String?) {
        nowPlayingTitle = title
        publish()
    }

    @Synchronized
    fun setError(newError: RadioPlayerErrorMessage) {
        error = newError
        publish()
    }

    @Synchronized
    fun clearError() {
        error = null
        publish()
    }

    @Synchronized
    fun reset() {
        playerStatus = PlaybackStatusMessage.IDLE
        currentIndex = null
        volume = DEFAULT_VOLUME
        nowPlayingTitle = null
        error = null
        publish()
    }

    private fun compose() = RadioPlayerStateMessage(
        status = if (error != null) PlaybackStatusMessage.ERROR else playerStatus,
        currentIndex = currentIndex,
        nowPlayingTitle = nowPlayingTitle,
        volume = volume,
        error = error,
    )

    private fun publish() {
        val next = compose()
        if (next == snapshot) return
        snapshot = next
        val target = sink
        mainHandler.post { target?.success(next) }
    }
}
