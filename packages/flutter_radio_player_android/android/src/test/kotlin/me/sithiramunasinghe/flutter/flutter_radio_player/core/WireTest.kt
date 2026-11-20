package me.sithiramunasinghe.flutter.flutter_radio_player.core

import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerError
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerErrorCode
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerOptionsInfo
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioSourceInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class WireTest {
    private val sources = listOf(
        RadioSourceInfo("https://a.example/s", id = "a", title = "A", headers = mapOf("Authorization" to "x")),
        RadioSourceInfo("https://b.example/s", artwork = "img.png").also { it.artworkUri = "asset:///flutter_assets/img.png" },
    )

    @Test
    fun optionsRoundTrip() {
        val options = RadioPlayerOptionsInfo(false, 90_000, false, "ic_radio")
        assertEquals(options, Wire.options(Wire.optionsArgs(options)))
        assertEquals(RadioPlayerOptionsInfo(), Wire.options(Wire.optionsArgs(RadioPlayerOptionsInfo())))
    }

    @Test
    fun setSourcesArgsRoundTrip() {
        val args = Wire.setSourcesArgs(sources, 1, true)
        assertEquals(sources, Wire.sources(args))
        assertEquals("asset:///flutter_assets/img.png", Wire.sources(args)[1].artworkUri)
        assertEquals(1, Wire.initialIndex(args))
        assertEquals(true, Wire.autoPlay(args))
        assertNull(Wire.initialIndex(Wire.setSourcesArgs(sources, null, false)))
    }

    @Test
    fun serviceStateRoundTrip() {
        val error = RadioPlayerError(RadioPlayerErrorCode.HTTP_STATUS, "503")
        val state = ServiceState(
            revision = 7,
            entries = sources.mapIndexed { i, s -> Entry("frp-$i", s) },
            options = RadioPlayerOptionsInfo(wrapAround = false),
            nowPlaying = Tagged("frp-0", "Song", 3),
            error = Tagged("frp-1", error, 4),
        )
        val decoded = Wire.serviceState(Wire.stateBundle(state))!!
        assertEquals(7, decoded.revision)
        assertEquals(listOf("frp-0", "frp-1"), decoded.entries.map { it.mediaId })
        assertEquals(sources, decoded.entries.map { it.source })
        assertEquals(state.options, decoded.options)
        assertEquals("Song", decoded.nowPlaying!!.value)
        assertEquals(3, decoded.nowPlaying!!.seq)
        assertEquals(error, decoded.error!!.value)
        assertEquals("frp-1", decoded.error!!.mediaId)
    }
}
