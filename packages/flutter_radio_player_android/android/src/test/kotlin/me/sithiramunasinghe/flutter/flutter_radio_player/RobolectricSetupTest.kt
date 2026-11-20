package me.sithiramunasinghe.flutter.flutter_radio_player

import androidx.media3.common.Player
import androidx.media3.test.utils.TestExoPlayerBuilder
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class RobolectricSetupTest {
    @Test
    fun buildsTestExoPlayer() {
        val player = TestExoPlayerBuilder(RuntimeEnvironment.getApplication()).build()
        try {
            assertEquals(Player.STATE_IDLE, player.playbackState)
        } finally {
            player.release()
        }
    }
}
