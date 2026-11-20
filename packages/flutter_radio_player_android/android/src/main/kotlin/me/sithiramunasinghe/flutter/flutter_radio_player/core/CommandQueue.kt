package me.sithiramunasinghe.flutter.flutter_radio_player.core

/**
 * Runs commands one at a time, in call order. A command finishes by calling its
 * `done` callback, synchronously or later; nothing runs while [ready] is false.
 */
internal class CommandQueue {
    private val commands = ArrayDeque<(done: () -> Unit) -> Unit>()
    private var busy = false
    private var draining = false

    var ready: Boolean = false
        set(value) {
            field = value
            drain()
        }

    val isIdle: Boolean get() = !busy && commands.isEmpty()

    fun enqueue(command: (done: () -> Unit) -> Unit) {
        commands.addLast(command)
        drain()
    }

    private fun drain() {
        if (draining) return
        draining = true
        try {
            while (ready && !busy && commands.isNotEmpty()) {
                val command = commands.removeFirst()
                busy = true
                var finished = false
                command {
                    if (!finished) {
                        finished = true
                        busy = false
                        drain()
                    }
                }
            }
        } finally {
            draining = false
        }
    }
}
