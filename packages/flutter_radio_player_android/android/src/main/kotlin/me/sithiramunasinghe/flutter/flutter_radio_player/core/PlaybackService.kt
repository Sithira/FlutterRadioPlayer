package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.app.PendingIntent
import android.content.Intent
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Metadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.extractor.metadata.icy.IcyInfo
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSession.ControllerInfo
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import me.sithiramunasinghe.flutter.flutter_radio_player.PlaybackStatusMessage
import me.sithiramunasinghe.flutter.flutter_radio_player.RadioPlayerErrorCodeMessage
import me.sithiramunasinghe.flutter.flutter_radio_player.RadioPlayerErrorMessage

class PlaybackService : MediaLibraryService() {

    private lateinit var player: Player
    private var mediaSession: MediaLibrarySession? = null

    companion object {
        private var instance: PlaybackService? = null

        fun shutdown(): Boolean {
            val service = instance ?: return false
            service.player.clearMediaItems()
            service.pauseAllPlayersAndStopSelf()
            return true
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        initializeSessionAndPlayer()
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        if (::player.isInitialized) player.removeListener(playerListener)
        mediaSession?.run {
            player.release()
            release()
        }
        mediaSession = null
        RadioStateStore.reset()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (mediaSession?.player != null) {
            stopSelf()
        }
    }

    override fun onGetSession(controllerInfo: ControllerInfo): MediaLibrarySession? = mediaSession

    @OptIn(UnstableApi::class)
    private fun initializeSessionAndPlayer() {
        player = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .setHandleAudioBecomingNoisy(true)
            .build()
        player.volume = 0.5f

        val sessionBuilder = MediaLibrarySession.Builder(this, player, object : MediaLibrarySession.Callback {
            override fun onAddMediaItems(
                mediaSession: MediaSession,
                controller: ControllerInfo,
                mediaItems: MutableList<MediaItem>
            ): ListenableFuture<MutableList<MediaItem>> {
                return Futures.immediateFuture(mediaItems)
            }
        })
        packageManager.getLaunchIntentForPackage(packageName)?.let { launchIntent ->
            sessionBuilder.setSessionActivity(
                PendingIntent.getActivity(
                    this, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
        mediaSession = sessionBuilder.build()

        val notificationProvider = DefaultMediaNotificationProvider(this)
        val appInfo = packageManager.getApplicationInfo(packageName, 0)
        notificationProvider.setSmallIcon(appInfo.icon)
        setMediaNotificationProvider(notificationProvider)

        player.addListener(playerListener)
    }

    private val playerListener = object : Player.Listener {
        override fun onEvents(player: Player, events: Player.Events) {
            publishPlayerState()
        }

        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            RadioStateStore.discardError()
            RadioStateStore.setNowPlayingTitle(null)
            publishPlayerState()
        }

        override fun onPlayerError(error: PlaybackException) {
            RadioStateStore.setError(
                RadioPlayerErrorMessage(
                    code = errorCodeOf(error),
                    message = error.message?.takeIf { it.isNotBlank() }
                        ?.let { "${error.errorCodeName}: $it" }
                        ?: error.errorCodeName,
                )
            )
            publishPlayerState()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                RadioStateStore.discardError()
                publishPlayerState()
            }
        }

        override fun onMetadata(metadata: Metadata) {
            for (i in 0 until metadata.length()) {
                val entry = metadata[i]
                if (entry is IcyInfo && !entry.title.isNullOrEmpty()) {
                    RadioStateStore.setNowPlayingTitle(entry.title)
                    publishPlayerState()
                    return
                }
            }
        }

        override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
            val title = mediaMetadata.title?.toString() ?: return
            RadioStateStore.setNowPlayingTitle(title)
            publishPlayerState()
        }
    }

    private fun publishPlayerState() {
        RadioStateStore.updatePlayer(
            status = playbackStatusOf(player),
            index = if (player.mediaItemCount == 0) null else player.currentMediaItemIndex.toLong(),
            newVolume = player.volume.toDouble(),
        )
    }

    private fun errorCodeOf(error: PlaybackException): RadioPlayerErrorCodeMessage =
        when (error.errorCode) {
            PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED,
            PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT -> RadioPlayerErrorCodeMessage.NETWORK
            else -> RadioPlayerErrorCodeMessage.UNKNOWN
        }

    private fun playbackStatusOf(player: Player): PlaybackStatusMessage = when {
        player.mediaItemCount == 0 -> PlaybackStatusMessage.IDLE
        player.playWhenReady &&
            (player.playbackState == Player.STATE_IDLE || player.playbackState == Player.STATE_BUFFERING) ->
            PlaybackStatusMessage.LOADING
        player.isPlaying -> PlaybackStatusMessage.PLAYING
        else -> PlaybackStatusMessage.PAUSED
    }
}
