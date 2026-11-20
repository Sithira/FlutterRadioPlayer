package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.os.Bundle
import androidx.media3.session.MediaLibraryService.MediaLibrarySession
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSession.ControllerInfo
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * Who may do what: controllers of this app (same package and uid, which includes
 * Media3's notification controller) get the player commands and the plugin's custom
 * commands; every other controller gets Media3's default access.
 */
internal class RadioSessionCallback(
    private val ownPackage: String,
    private val ownUid: Int,
    private val host: Host,
) : MediaLibrarySession.Callback {

    interface Host {
        fun setSources(args: Bundle): SessionResult
        fun setOptions(args: Bundle): SessionResult
        fun stateBundle(): Bundle
    }

    fun isTrusted(controller: ControllerInfo): Boolean =
        controller.packageName == ownPackage && controller.uid == ownUid

    override fun onConnect(session: MediaSession, controller: ControllerInfo): MediaSession.ConnectionResult {
        if (!isTrusted(controller)) return super.onConnect(session, controller)
        return MediaSession.ConnectionResult.AcceptedResultBuilder(session, controller)
            .setAvailablePlayerCommands(MediaSession.ConnectionResult.DEFAULT_PLAYER_COMMANDS)
            .setAvailableSessionCommands(
                MediaSession.ConnectionResult.DEFAULT_SESSION_AND_LIBRARY_COMMANDS.buildUpon()
                    .add(SessionCommand(Wire.SET_SOURCES, Bundle.EMPTY))
                    .add(SessionCommand(Wire.SET_OPTIONS, Bundle.EMPTY))
                    .build(),
            )
            .build()
    }

    override fun onPostConnect(session: MediaSession, controller: ControllerInfo) {
        if (isTrusted(controller)) session.setSessionExtras(controller, host.stateBundle())
    }

    override fun onCustomCommand(
        session: MediaSession,
        controller: ControllerInfo,
        customCommand: SessionCommand,
        args: Bundle,
    ): ListenableFuture<SessionResult> {
        val result = when {
            !isTrusted(controller) -> SessionResult(SessionResult.RESULT_ERROR_PERMISSION_DENIED)
            customCommand.customAction == Wire.SET_SOURCES -> host.setSources(args)
            customCommand.customAction == Wire.SET_OPTIONS -> host.setOptions(args)
            else -> SessionResult(SessionResult.RESULT_ERROR_NOT_SUPPORTED)
        }
        return Futures.immediateFuture(result)
    }
}
