package me.sithiramunasinghe.flutter.flutter_radio_player.core

import java.util.concurrent.CopyOnWriteArraySet

/** Whether the playback service runs in this process; the only process-wide state. */
internal object ServiceLiveness {
    @Volatile
    var isRunning: Boolean = false
        private set

    private val listeners = CopyOnWriteArraySet<() -> Unit>()

    fun addListener(listener: () -> Unit) {
        listeners += listener
    }

    fun removeListener(listener: () -> Unit) {
        listeners -= listener
    }

    fun started() {
        isRunning = true
        listeners.forEach { it() }
    }

    fun stopped() {
        isRunning = false
    }
}
