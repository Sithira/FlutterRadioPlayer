package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Metadata
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
import me.sithiramunasinghe.flutter.flutter_radio_player.FlutterRadioPlayerPlugin
import me.sithiramunasinghe.flutter.flutter_radio_player.NowPlayingInfoMessage
import me.sithiramunasinghe.flutter.flutter_radio_player.PigeonEventSink
import me.sithiramunasinghe.flutter.flutter_radio_player.VolumeInfoMessage

class PlaybackService : MediaLibraryService() {

    private lateinit var player: Player
    private var mediaSession: MediaLibrarySession? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        var latestMetadata: MediaMetadata? = null
        var playbackStateSink: PigeonEventSink<Boolean>? = null
        var nowPlayingSink: PigeonEventSink<NowPlayingInfoMessage>? = null
        var volumeSink: PigeonEventSink<VolumeInfoMessage>? = null
    }

    override fun onCreate() {
        super.onCreate()
        initializeSessionAndPlayer()
    }

    override fun onDestroy() {
        mediaSession?.run {
            player.release()
            release()
        }
        mediaSession = null
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
            .build()

        mediaSession = MediaLibrarySession.Builder(this, player, object : MediaLibrarySession.Callback {
            override fun onAddMediaItems(
                mediaSession: MediaSession,
                controller: ControllerInfo,
                mediaItems: MutableList<MediaItem>
            ): ListenableFuture<MutableList<MediaItem>> {
                return Futures.immediateFuture(mediaItems)
            }
        })
            .setSessionActivity(FlutterRadioPlayerPlugin.sessionActivity)
            .build()

        val notificationProvider = DefaultMediaNotificationProvider(this)
        val appInfo = packageManager.getApplicationInfo(packageName, 0)
        notificationProvider.setSmallIcon(appInfo.icon)
        setMediaNotificationProvider(notificationProvider)

        player.addListener(object : Player.Listener {
            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                mainHandler.post { nowPlayingSink?.success(NowPlayingInfoMessage(title = null)) }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                mainHandler.post { playbackStateSink?.success(isPlaying) }
            }

            override fun onVolumeChanged(volume: Float) {
                mainHandler.post {
                    volumeSink?.success(VolumeInfoMessage(volume = volume.toDouble(), isMuted = false))
                }
            }

            override fun onMetadata(metadata: Metadata) {
                for (i in 0 until metadata.length()) {
                    val entry = metadata[i]
                    if (entry is IcyInfo && !entry.title.isNullOrEmpty()) {
                        mainHandler.post {
                            nowPlayingSink?.success(NowPlayingInfoMessage(title = entry.title))
                        }
                        latestMetadata = null
                        return
                    }
                }
            }

            override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
                latestMetadata = mediaMetadata
                val title = mediaMetadata.title?.toString() ?: return
                mainHandler.post {
                    nowPlayingSink?.success(NowPlayingInfoMessage(title = title))
                }
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_READY) {
                    mainHandler.post { playbackStateSink?.success(false) }
                }
            }
        })
    }
}
