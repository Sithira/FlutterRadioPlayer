package me.sithiramunasinghe.flutter.flutter_radio_player.core

import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.PlaybackStatus
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerSnapshot
import me.sithiramunasinghe.flutter.flutter_radio_player.core.logic.PlayerFacts
import me.sithiramunasinghe.flutter.flutter_radio_player.core.logic.statusOf

/** The player facts a snapshot is built from; implemented over a `MediaController`. */
internal interface PlayerView {
    val mediaItemCount: Int
    fun mediaIdAt(index: Int): String
    val currentIndex: Int
    val playWhenReady: Boolean
    val isPlaying: Boolean
    val volume: Float
}

internal class StateHolder {
    var service: ServiceState? = null
    private var titleClearedThrough = -1L
    private var errorClearedThrough = -1L

    /** `null` while the controller's timeline and the service's list disagree. */
    fun snapshot(view: PlayerView): RadioPlayerSnapshot? {
        val entries = service?.entries.orEmpty()
        val count = view.mediaItemCount
        if (count != entries.size || (0 until count).any { view.mediaIdAt(it) != entries[it].mediaId }) return null
        if (count == 0) return RadioPlayerSnapshot(PlaybackStatus.IDLE, emptyList(), null, null, view.volume, null)

        val index = view.currentIndex.coerceIn(0, count - 1)
        val mediaId = entries[index].mediaId
        val title = service?.nowPlaying?.takeIf { it.mediaId == mediaId && it.seq > titleClearedThrough }?.value
        val error = service?.error?.takeIf { it.mediaId == mediaId && it.seq > errorClearedThrough }?.value
        val status = statusOf(
            PlayerFacts(
                hasSources = true,
                reconnectPending = false,
                failed = error != null,
                playRequested = view.playWhenReady,
                rendering = view.isPlaying,
            ),
        )
        return RadioPlayerSnapshot(status, entries.map { it.source }, index, title, view.volume, error)
    }

    /** Hides the error the service has not cleared yet, after a command that clears it. */
    fun clearErrorLocally() {
        service?.error?.let { errorClearedThrough = maxOf(errorClearedThrough, it.seq) }
    }

    /** Hides the title the service has not cleared yet, after `stop`. */
    fun clearTitleLocally() {
        service?.nowPlaying?.let { titleClearedThrough = maxOf(titleClearedThrough, it.seq) }
    }
}
