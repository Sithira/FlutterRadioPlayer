package me.sithiramunasinghe.flutter.flutter_radio_player.core

import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class CommandQueueTest {
    @Test
    fun runsNothingUntilReadyThenInOrder() {
        val queue = CommandQueue()
        val log = mutableListOf<String>()
        queue.enqueue { log += "a"; it() }
        queue.enqueue { log += "b"; it() }
        assertEquals(emptyList(), log)
        queue.ready = true
        queue.enqueue { log += "c"; it() }
        assertEquals(listOf("a", "b", "c"), log)
        assertTrue(queue.isIdle)
    }

    @Test
    fun anUnfinishedCommandHoldsTheRest() {
        val queue = CommandQueue().apply { ready = true }
        val log = mutableListOf<String>()
        var finishFirst: () -> Unit = {}
        queue.enqueue { log += "custom"; finishFirst = it }
        queue.enqueue { log += "play"; it() }
        assertEquals(listOf("custom"), log)
        finishFirst()
        assertEquals(listOf("custom", "play"), log)
    }

    @Test
    fun finishingTwiceRunsTheNextCommandOnce() {
        val queue = CommandQueue().apply { ready = true }
        val log = mutableListOf<String>()
        var finish: () -> Unit = {}
        queue.enqueue { finish = it }
        queue.enqueue { log += "next" }
        finish()
        finish()
        assertEquals(listOf("next"), log)
    }

    @Test
    fun notReadyStopsDraining() {
        val queue = CommandQueue().apply { ready = true }
        val log = mutableListOf<String>()
        var finish: () -> Unit = {}
        queue.enqueue { log += "a"; finish = it }
        queue.enqueue { log += "b"; it() }
        queue.ready = false
        finish()
        assertEquals(listOf("a"), log)
        queue.ready = true
        assertEquals(listOf("a", "b"), log)
    }
}
