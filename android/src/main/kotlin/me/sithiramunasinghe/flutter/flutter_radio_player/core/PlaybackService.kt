package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.annotation.OptIn
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Player.STATE_IDLE
import androidx.media3.common.Player.STATE_READY
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.HttpDataSource.HttpDataSourceException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.CommandButton
import androidx.media3.session.MediaNotification
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSession.Builder
import androidx.media3.session.MediaSession.Callback
import androidx.media3.session.MediaSession.ControllerInfo
import androidx.media3.session.MediaSessionService
import androidx.media3.session.MediaStyleNotificationHelper
import com.google.common.collect.ImmutableList
import me.sithiramunasinghe.flutter.flutter_radio_player.R


class PlaybackService : MediaSessionService(), Callback {
    @RequiresApi(Build.VERSION_CODES.O)
    var channel: NotificationChannel =
        NotificationChannel("", "PennSkanvTicChannel", NotificationManager.IMPORTANCE_MAX)

    private lateinit var player: Player
    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        initializeSessionAndPlayer()
    }

    override fun onDestroy() {
        if (mediaSession != null) {
            mediaSession?.run {
                player.release()
                mediaSession?.release()
                release()
                mediaSession = null
            }
        }
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val player = mediaSession?.player
        if (player != null) {
            if (!player.playWhenReady && player.mediaItemCount == 0) {
                stopSelf()
            }
        }
    }

    override fun onGetSession(controllerInfo: ControllerInfo): MediaSession? {
        return mediaSession
    }

    @OptIn(UnstableApi::class)
    private fun initializeSessionAndPlayer() {
        player = ExoPlayer.Builder(this).build()
        mediaSession = Builder(this, player)
            .setCallback(this)
            .build()
        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (isPlaying) {
                    println("IsPlaying")
                } else {
                    println("IsStopped")
                }
            }
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == STATE_IDLE) {
                    println("STOPPEDDDDDDDDDD")
                }

                if (playbackState == STATE_READY) {
                    println("PLAYIIINGGGGGGGGG")
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                val cause = error.cause
                if (cause is HttpDataSourceException) {
                    println("Oh no")
                }
            }
        })
        setMediaNotificationProvider(object : MediaNotification.Provider{
            override fun createNotification(
                mediaSession: MediaSession,
                customLayout: ImmutableList<CommandButton>,
                actionFactory: MediaNotification.ActionFactory,
                onNotificationChangedCallback: MediaNotification.Provider.Callback
            ): MediaNotification {
                return updateNotification(mediaSession)
            }

            override fun handleCustomCommand(
                session: MediaSession,
                action: String,
                extras: Bundle
            ): Boolean {
                return false
            }

        })
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun updateNotification(session: MediaSession): MediaNotification {

        val notify = NotificationCompat.Builder(this,"fsdfdsfsdfs")
            // This is globally changed every time when
            // I add a new MediaItem from background service
            .setContentTitle("Test")
            .setContentText("Aaaa")
            .setSmallIcon(R.drawable.media3_notification_small_icon)
            .setStyle(MediaStyleNotificationHelper.MediaStyle(session))
            .build()

        return MediaNotification(9876, notify)
    }

}