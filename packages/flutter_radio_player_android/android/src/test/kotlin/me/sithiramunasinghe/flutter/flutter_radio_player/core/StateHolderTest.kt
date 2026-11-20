package me.sithiramunasinghe.flutter.flutter_radio_player.core

import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.PlaybackStatus
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerError
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerErrorCode
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerOptionsInfo
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioSourceInfo
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

private class FakeView(
    var ids: List<String> = emptyList(),
    override var currentIndex: Int = 0,
    override var playWhenReady: Boolean = false,
    override var isPlaying: Boolean = false,
    override var volume: Float = 1f,
) : PlayerView {
    override val mediaItemCount: Int get() = ids.size
    override fun mediaIdAt(index: Int): String = ids[index]
}

class StateHolderTest {
    private val a = RadioSourceInfo("https://a.example/s", title = "A")
    private val b = RadioSourceInfo("https://b.example/s", title = "B")
    private val entries = listOf(Entry("m1", a), Entry("m2", b))
    private val networkError = RadioPlayerError(RadioPlayerErrorCode.NETWORK, "down")

    private fun state(
        revision: Long = 1,
        nowPlaying: Tagged<String>? = null,
        error: Tagged<RadioPlayerError>? = null,
    ) = ServiceState(revision, entries, RadioPlayerOptionsInfo(), nowPlaying, error)

    @Test
    fun emptyPlayerIsIdleWithItsVolume() {
        val snapshot = StateHolder().snapshot(FakeView(volume = 0.4f))!!
        assertEquals(PlaybackStatus.IDLE, snapshot.status)
        assertEquals(0.4f, snapshot.volume)
        assertNull(snapshot.currentIndex)
    }

    @Test
    fun timelineAndListMustAgree() {
        val holder = StateHolder().apply { service = state() }
        assertNull(holder.snapshot(FakeView(ids = listOf("m1"))))
        assertNull(holder.snapshot(FakeView(ids = listOf("m2", "m1"))))
        assertEquals(listOf(a, b), holder.snapshot(FakeView(ids = listOf("m1", "m2")))!!.sources)
    }

    @Test
    fun statusFollowsPlayIntentAndRendering() {
        val holder = StateHolder().apply { service = state() }
        val view = FakeView(ids = listOf("m1", "m2"), currentIndex = 1)
        assertEquals(PlaybackStatus.PAUSED, holder.snapshot(view)!!.status)
        view.playWhenReady = true
        assertEquals(PlaybackStatus.LOADING, holder.snapshot(view)!!.status)
        view.isPlaying = true
        assertEquals(PlaybackStatus.PLAYING, holder.snapshot(view)!!.status)
        assertEquals(b, holder.snapshot(view)!!.currentSource)
    }

    @Test
    fun titleAndErrorOnlyForTheirItem() {
        val holder = StateHolder().apply {
            service = state(nowPlaying = Tagged("m1", "Song", 1), error = Tagged("m1", networkError, 2))
        }
        val view = FakeView(ids = listOf("m1", "m2"), playWhenReady = true)
        val first = holder.snapshot(view)!!
        assertEquals("Song", first.nowPlayingTitle)
        assertEquals(networkError, first.error)
        assertEquals(PlaybackStatus.ERROR, first.status)

        view.currentIndex = 1
        val second = holder.snapshot(view)!!
        assertNull(second.nowPlayingTitle)
        assertNull(second.error)
        assertEquals(PlaybackStatus.LOADING, second.status)
    }

    @Test
    fun localClearsHideUntilANewerValueArrives() {
        val holder = StateHolder().apply {
            service = state(nowPlaying = Tagged("m1", "Song", 3), error = Tagged("m1", networkError, 4))
        }
        val view = FakeView(ids = listOf("m1", "m2"))
        holder.clearErrorLocally()
        holder.clearTitleLocally()
        assertNull(holder.snapshot(view)!!.error)
        assertNull(holder.snapshot(view)!!.nowPlayingTitle)

        holder.service = state(nowPlaying = Tagged("m1", "Next", 5), error = Tagged("m1", networkError, 6))
        assertEquals("Next", holder.snapshot(view)!!.nowPlayingTitle)
        assertEquals(networkError, holder.snapshot(view)!!.error)
    }
}
