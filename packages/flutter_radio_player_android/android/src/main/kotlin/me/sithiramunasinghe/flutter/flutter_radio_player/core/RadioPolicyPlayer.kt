package me.sithiramunasinghe.flutter.flutter_radio_player.core

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.ForwardingSimpleBasePlayer
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * The session's player: ExoPlayer plus the plugin's playback policies.
 *
 * Wrap-around is reported to controllers as `REPEAT_MODE_ALL`, so the notification and
 * lock-screen buttons wrap, while ExoPlayer itself stays on `REPEAT_MODE_OFF` and never
 * advances on its own when a stream ends.
 */
@OptIn(UnstableApi::class)
internal class RadioPolicyPlayer(private val player: Player) : ForwardingSimpleBasePlayer(player) {

    var wrapAround: Boolean = true
        set(value) {
            if (field == value) return
            field = value
            invalidateState()
        }

    override fun getState(): State {
        val state = super.getState()
        val stepping = player.mediaItemCount >= 2
        val commands = state.availableCommands.buildUpon()
            .setAll(stepping, *STEP_COMMANDS)
            .build()
        return state.buildUpon()
            .setRepeatMode(if (wrapAround && stepping) Player.REPEAT_MODE_ALL else Player.REPEAT_MODE_OFF)
            .setAvailableCommands(if (stepping && !wrapAround) withEndsOf(commands) else commands)
            .build()
    }

    private fun withEndsOf(commands: Player.Commands): Player.Commands {
        val index = player.currentMediaItemIndex
        return commands.buildUpon()
            .setAll(index < player.mediaItemCount - 1, Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM, Player.COMMAND_SEEK_TO_NEXT)
            .setAll(index > 0, Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
            .build()
    }

    override fun handleSetRepeatMode(repeatMode: Int): ListenableFuture<*> = Futures.immediateVoidFuture()

    override fun handleSeek(mediaItemIndex: Int, positionMs: Long, seekCommand: Int): ListenableFuture<*> {
        if (mediaItemIndex != C.INDEX_UNSET && mediaItemIndex >= player.mediaItemCount) {
            return Futures.immediateVoidFuture()
        }
        // The base class re-issues next/previous on ExoPlayer, which runs with REPEAT_MODE_OFF
        // and would not wrap; seek to the index resolved with the reported repeat mode instead.
        if (seekCommand in STEP_COMMANDS || seekCommand == Player.COMMAND_SEEK_TO_PREVIOUS) {
            if (mediaItemIndex != C.INDEX_UNSET && mediaItemIndex != player.currentMediaItemIndex) {
                player.seekToDefaultPosition(mediaItemIndex)
                return Futures.immediateVoidFuture()
            }
        }
        return super.handleSeek(mediaItemIndex, positionMs, seekCommand)
    }

    private fun Player.Commands.Builder.setAll(available: Boolean, vararg commands: Int): Player.Commands.Builder =
        apply { commands.forEach { if (available) add(it) else remove(it) } }

    private companion object {
        val STEP_COMMANDS = intArrayOf(
            Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM,
            Player.COMMAND_SEEK_TO_NEXT,
            Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM,
        )
    }
}
