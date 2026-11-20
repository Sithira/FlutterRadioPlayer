package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.os.Bundle
import androidx.media3.common.Player
import androidx.media3.session.MediaLibraryService.MediaLibrarySession
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSession.ControllerInfo
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import androidx.media3.test.utils.TestExoPlayerBuilder
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class RadioSessionCallbackTest {
    private val calls = mutableListOf<String>()
    private val host = object : RadioSessionCallback.Host {
        override fun setSources(args: Bundle): SessionResult {
            calls += "setSources"
            return SessionResult(SessionResult.RESULT_SUCCESS)
        }

        override fun setOptions(args: Bundle): SessionResult {
            calls += "setOptions"
            return SessionResult(SessionResult.RESULT_SUCCESS)
        }

        override fun stateBundle(): Bundle = Bundle.EMPTY
    }
    private val callback = RadioSessionCallback("my.app", 1000, host)
    private lateinit var session: MediaSession

    @Before
    fun setUp() {
        val context = RuntimeEnvironment.getApplication()
        val service = Robolectric.setupService(PlaybackServiceStub::class.java)
        session = MediaLibrarySession.Builder(service, TestExoPlayerBuilder(context).build(), callback).build()
    }

    @After
    fun tearDown() {
        session.player.release()
        session.release()
    }

    private fun controller(packageName: String, uid: Int): ControllerInfo =
        ControllerInfo.createTestOnlyControllerInfo(packageName, 1, uid, 0, 0, false, Bundle.EMPTY, true)

    @Test
    fun ownAppGetsPlayerAndCustomCommands() {
        val result = callback.onConnect(session, controller("my.app", 1000))
        assertTrue(result.isAccepted)
        assertTrue(result.availablePlayerCommands.contains(Player.COMMAND_PLAY_PAUSE))
        assertTrue(result.availableSessionCommands.contains(SessionCommand(Wire.SET_SOURCES, Bundle.EMPTY)))
        assertTrue(result.availableSessionCommands.contains(SessionCommand(Wire.SET_OPTIONS, Bundle.EMPTY)))
    }

    @Test
    fun otherAppsNeverGetCustomCommands() {
        for (other in listOf(controller("other.app", 2000), controller("my.app", 2000), controller("other.app", 1000))) {
            val result = callback.onConnect(session, other)
            assertFalse(result.availableSessionCommands.contains(SessionCommand(Wire.SET_SOURCES, Bundle.EMPTY)))
            assertFalse(result.availableSessionCommands.contains(SessionCommand(Wire.SET_OPTIONS, Bundle.EMPTY)))
        }
    }

    @Test
    fun customCommandsFromOtherAppsAreRejected() {
        val result = callback.onCustomCommand(
            session,
            controller("other.app", 2000),
            SessionCommand(Wire.SET_SOURCES, Bundle.EMPTY),
            Bundle.EMPTY,
        ).get()
        assertEquals(SessionResult.RESULT_ERROR_PERMISSION_DENIED, result.resultCode)
        assertTrue(calls.isEmpty())
    }

    @Test
    fun customCommandsFromOwnAppReachTheService() {
        val own = controller("my.app", 1000)
        callback.onCustomCommand(session, own, SessionCommand(Wire.SET_SOURCES, Bundle.EMPTY), Bundle.EMPTY).get()
        callback.onCustomCommand(session, own, SessionCommand(Wire.SET_OPTIONS, Bundle.EMPTY), Bundle.EMPTY).get()
        val unknown = callback.onCustomCommand(session, own, SessionCommand("x", Bundle.EMPTY), Bundle.EMPTY).get()
        assertEquals(listOf("setSources", "setOptions"), calls)
        assertEquals(SessionResult.RESULT_ERROR_NOT_SUPPORTED, unknown.resultCode)
    }
}

class PlaybackServiceStub : android.app.Service() {
    override fun onBind(intent: android.content.Intent?) = null
}
