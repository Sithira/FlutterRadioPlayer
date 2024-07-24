package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.content.Intent
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Player.STATE_IDLE
import androidx.media3.common.Player.STATE_READY
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.HttpDataSource.HttpDataSourceException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSession.ControllerInfo
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import me.sithiramunasinghe.flutter.flutter_radio_player.data.FlutterRadioVolumeChanged
import me.sithiramunasinghe.flutter.flutter_radio_player.data.NowPlayingInfo

class PlaybackService : MediaLibraryService() {

    private lateinit var player: Player
    private var mediaSession: MediaLibrarySession? = null
    private var playBackEventSink: EventSink? = null
    private var nowPlayingEventSink: EventSink? = null
    private var playbackVolumeControl: EventSink? = null

    override fun onCreate() {
        super.onCreate()
        initializeEventSink()
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

    override fun onGetSession(controllerInfo: ControllerInfo): MediaLibrarySession? {
        return mediaSession
    }

    @OptIn(UnstableApi::class)
    private fun initializeSessionAndPlayer() {

        player = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .build()

        mediaSession =
            MediaLibrarySession.Builder(this, player, object : MediaLibrarySession.Callback {
                override fun onAddMediaItems(
                    mediaSession: MediaSession,
                    controller: ControllerInfo,
                    mediaItems: MutableList<MediaItem>
                ): ListenableFuture<MutableList<MediaItem>> {
                    return Futures.immediateFuture(mediaItems)
                }
            }).build()

        val default = DefaultMediaNotificationProvider(this)
        val appInfo = packageManager.getApplicationInfo(packageName, 0)
        default.setSmallIcon(appInfo.icon)

        setMediaNotificationProvider(default)

        player.addListener(object : Player.Listener {
            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                nowPlayingEventSink?.success(null)
                super.onMediaItemTransition(mediaItem, reason)
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                println("is playing = $isPlaying")
                playBackEventSink?.success(isPlaying)
            }

            override fun onVolumeChanged(volume: Float) {
                println("Volume = $volume")
                if (playbackVolumeControl != null) {
                    playbackVolumeControl!!.success(
                        FlutterRadioVolumeChanged(
                            volume = volume,
                            isMuted = false
                        ).toJson()
                    )
                }
                super.onVolumeChanged(volume)
            }

            override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
                println("======== TITLE => ${mediaMetadata.title}")
                if (nowPlayingEventSink != null) {
                    var nowPlayingTitle: String? = null
                    if (mediaMetadata.title != null) {
                        nowPlayingTitle = mediaMetadata.title.toString()
                    }
                    nowPlayingEventSink!!.success(
                        NowPlayingInfo(
                            title = nowPlayingTitle,
                        ).toJson()
                    )
                }
                super.onMediaMetadataChanged(mediaMetadata)
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == STATE_IDLE) {
                    println("player is idle")
                }

                if (playbackState == STATE_READY) {
                    playBackEventSink?.success(false)
                    println("player is ready")
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                val cause = error.cause
                if (cause is HttpDataSourceException) {
                    println("Oh no")
                }
            }
        })
    }

    private fun initializeEventSink() {
        EventChannelSink.getInstance().playbackEventChannel.setStreamHandler(object :
            StreamHandler {
            override fun onListen(arguments: Any?, events: EventSink?) {
                playBackEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                playBackEventSink = null
            }
        })

        EventChannelSink.getInstance().nowPlayingEventChannel.setStreamHandler(object :
            StreamHandler {
            override fun onListen(arguments: Any?, events: EventSink?) {
                nowPlayingEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                nowPlayingEventSink = null
            }
        })

        EventChannelSink.getInstance().playbackVolumeChannel.setStreamHandler(object :
            StreamHandler {
            override fun onListen(arguments: Any?, events: EventSink?) {
                playbackVolumeControl = events
            }

            override fun onCancel(arguments: Any?) {
                playbackVolumeControl = null
            }
        })
    }
}