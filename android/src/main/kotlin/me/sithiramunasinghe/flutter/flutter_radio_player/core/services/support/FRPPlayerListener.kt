package me.sithiramunasinghe.flutter.flutter_radio_player.core.services.support

import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaMetadata
import com.google.android.exoplayer2.PlaybackException
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.ui.PlayerNotificationManager
import io.flutter.Log
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.*
import me.sithiramunasinghe.flutter.flutter_radio_player.core.enums.FRPPlaybackStatus
import me.sithiramunasinghe.flutter.flutter_radio_player.core.events.FRPPlayerEvent
import me.sithiramunasinghe.flutter.flutter_radio_player.core.services.FRPCoreService
import org.greenrobot.eventbus.EventBus

class FRPPlayerListener(
    private val frpCoreService: FRPCoreService,
    private val exoPlayer: ExoPlayer?,
    private val playerNotificationManager: PlayerNotificationManager?,
    private val eventBus: EventBus
) : Player.Listener {

    companion object {
        private const val TAG = "FRPPlayerListener"
    }

    override fun onDeviceVolumeChanged(volume: Int, muted: Boolean) {
        if (muted) {
            eventBus.post(FRPPlayerEvent(data = FRP_VOLUME_MUTE))
        } else {
            eventBus.post(FRPPlayerEvent(data = FRP_VOLUME_CHANGED))
        }
    }

    override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
        Log.i(TAG, ":::: meta details changed ::::")
        frpCoreService.currentMetaData = mediaMetadata
        eventBus.post(FRPPlayerEvent(FRPIcyMetaData = FRPIcyMetaData(frpCoreService.currentMetaData)))
        playerNotificationManager?.invalidate()
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        Log.i(TAG, " :::: isPlaying status changed :::: ")
        if (isPlaying) {
            eventBus.post(FRPPlayerEvent(playbackStatus = FRP_PLAYING))
            FRPPlaybackStatus.PLAYING
        } else {
            if (frpCoreService.playbackStatus != FRPPlaybackStatus.STOPPED) {
                eventBus.post(FRPPlayerEvent(playbackStatus = FRP_PAUSED))
                FRPPlaybackStatus.PAUSED
            }
        }
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        Log.i(TAG, ":::: PlayerEvent CHANGED ::::")
        frpCoreService.playbackStatus = when (playbackState) {
            Player.STATE_BUFFERING -> {
                eventBus.post(FRPPlayerEvent(playbackStatus = FRP_LOADING))
                FRPPlaybackStatus.LOADING
            }
            Player.STATE_IDLE -> {
                frpCoreService.stopForeground(true)
                Log.i(TAG, "Notification Removed")
                frpCoreService.stopSelf()
                frpCoreService.onDestroy()
                eventBus.post(FRPPlayerEvent(playbackStatus = FRP_STOPPED))
                FRPPlaybackStatus.STOPPED
            }
            Player.STATE_READY -> {
                if (exoPlayer!!.playWhenReady) {
                    eventBus.post(FRPPlayerEvent(playbackStatus = FRP_PLAYING))
                    FRPPlaybackStatus.PLAYING
                } else {
                    eventBus.post(FRPPlayerEvent(playbackStatus = FRP_PAUSED))
                    FRPPlaybackStatus.PAUSED
                }
            }
            else -> {
                eventBus.post(FRPPlayerEvent(playbackStatus = FRP_STOPPED))
                frpCoreService.stopForeground(true)
                Log.i(TAG, "Notification Removed")
                frpCoreService.stopSelf()
                FRPPlaybackStatus.STOPPED
            }
        }
        Log.i(TAG, "Current PlayBackStatus = ${frpCoreService.playbackStatus}")
    }

    override fun onPlayerError(error: PlaybackException) {
        eventBus.post(FRPPlayerEvent(playbackStatus = FRP_STOPPED))
        frpCoreService.playbackStatus = FRPPlaybackStatus.ERROR
        Log.e(TAG, error.message!!)
    }
}