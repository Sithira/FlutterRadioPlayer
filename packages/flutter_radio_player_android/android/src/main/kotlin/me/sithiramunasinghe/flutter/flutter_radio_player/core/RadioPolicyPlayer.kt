package me.sithiramunasinghe.flutter.flutter_radio_player.core

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.ForwardingSimpleBasePlayer
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/** The session's player: ExoPlayer plus the plugin's playback policies. */
@OptIn(UnstableApi::class)
internal class RadioPolicyPlayer(private val player: Player) : ForwardingSimpleBasePlayer(player) {

    override fun handleSeek(mediaItemIndex: Int, positionMs: Long, seekCommand: Int): ListenableFuture<*> {
        if (mediaItemIndex != C.INDEX_UNSET && mediaItemIndex >= player.mediaItemCount) {
            return Futures.immediateVoidFuture()
        }
        return super.handleSeek(mediaItemIndex, positionMs, seekCommand)
    }
}
