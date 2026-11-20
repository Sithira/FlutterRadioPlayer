package me.sithiramunasinghe.flutter.flutter_radio_player.core

import androidx.media3.common.MediaItem
import androidx.media3.test.utils.TestExoPlayerBuilder
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class RadioPolicyPlayerTest {
    @Test
    fun seekBeyondTheListIsIgnored() {
        val exo = TestExoPlayerBuilder(RuntimeEnvironment.getApplication()).build()
        val player = RadioPolicyPlayer(exo)
        try {
            exo.setMediaItems(listOf(MediaItem.fromUri("https://a.example/s"), MediaItem.fromUri("https://b.example/s")))
            player.seekToDefaultPosition(1)
            assertEquals(1, player.currentMediaItemIndex)
            player.seekToDefaultPosition(5)
            assertEquals(1, player.currentMediaItemIndex)
            assertEquals(1, exo.currentMediaItemIndex)
        } finally {
            player.release()
        }
    }
}
