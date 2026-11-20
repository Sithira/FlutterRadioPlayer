package me.sithiramunasinghe.flutter.flutter_radio_player.core

import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.test.utils.TestExoPlayerBuilder
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import android.os.Looper

@RunWith(RobolectricTestRunner::class)
class RadioPolicyPlayerTest {
    private lateinit var exo: ExoPlayer
    private lateinit var player: RadioPolicyPlayer

    @Before
    fun setUp() {
        exo = TestExoPlayerBuilder(RuntimeEnvironment.getApplication()).build()
        player = RadioPolicyPlayer(exo)
    }

    @After
    fun tearDown() = player.release()

    private fun items(count: Int) {
        exo.setMediaItems((0 until count).map { MediaItem.fromUri("https://s$it.example/s") })
        idle()
    }

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    @Test
    fun wrapsAtBothEndsWhenWrapAroundIsOn() {
        items(3)
        player.seekToDefaultPosition(2)
        idle()
        assertTrue(player.isCommandAvailable(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM))
        player.seekToNextMediaItem()
        idle()
        assertEquals(0, exo.currentMediaItemIndex)
        player.seekToPreviousMediaItem()
        idle()
        assertEquals(2, exo.currentMediaItemIndex)
        assertEquals(Player.REPEAT_MODE_ALL, player.repeatMode)
        assertEquals(Player.REPEAT_MODE_OFF, exo.repeatMode)
    }

    @Test
    fun stopsAtBothEndsWhenWrapAroundIsOff() {
        player.wrapAround = false
        items(3)
        player.seekToDefaultPosition(2)
        idle()
        assertFalse(player.isCommandAvailable(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM))
        player.seekToNextMediaItem()
        assertEquals(2, exo.currentMediaItemIndex)
        player.seekToDefaultPosition(0)
        idle()
        assertFalse(player.isCommandAvailable(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM))
        assertTrue(player.isCommandAvailable(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM))
        assertEquals(Player.REPEAT_MODE_OFF, player.repeatMode)
    }

    @Test
    fun oneItemDisablesNextAndPrevious() {
        items(1)
        assertFalse(player.isCommandAvailable(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM))
        assertFalse(player.isCommandAvailable(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM))
        assertEquals(Player.REPEAT_MODE_OFF, player.repeatMode)
    }

    @Test
    fun steppingKeepsThePlayState() {
        items(2)
        player.seekToNextMediaItem()
        idle()
        assertFalse(exo.playWhenReady)
        exo.playWhenReady = true
        idle()
        player.seekToNextMediaItem()
        idle()
        assertTrue(exo.playWhenReady)
        assertEquals(0, exo.currentMediaItemIndex)
    }

    @Test
    fun repeatModeRequestsAreIgnored() {
        items(2)
        player.repeatMode = Player.REPEAT_MODE_ONE
        assertEquals(Player.REPEAT_MODE_OFF, exo.repeatMode)
        assertEquals(Player.REPEAT_MODE_ALL, player.repeatMode)
    }

    @Test
    fun seekBeyondTheListIsIgnored() {
        items(2)
        player.seekToDefaultPosition(1)
        player.seekToDefaultPosition(5)
        assertEquals(1, exo.currentMediaItemIndex)
    }
}
