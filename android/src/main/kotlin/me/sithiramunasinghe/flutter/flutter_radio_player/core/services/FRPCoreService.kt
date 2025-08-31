package me.sithiramunasinghe.flutter.flutter_radio_player.core.services

import android.app.Activity
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.support.v4.media.session.MediaSessionCompat
import com.google.android.exoplayer2.C
import com.google.android.exoplayer2.DefaultLivePlaybackSpeedControl
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.MediaMetadata
import com.google.android.exoplayer2.audio.AudioAttributes
import com.google.android.exoplayer2.ext.mediasession.MediaSessionConnector
import com.google.android.exoplayer2.source.MediaSource
import com.google.android.exoplayer2.source.ProgressiveMediaSource
import com.google.android.exoplayer2.source.hls.HlsMediaSource
import com.google.android.exoplayer2.ui.PlayerNotificationManager
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource
import com.google.android.exoplayer2.util.EventLogger
import com.google.android.exoplayer2.util.MimeTypes
import com.google.android.exoplayer2.util.Util
import io.flutter.Log
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPAudioSource
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPCurrentSource
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPIcyMetaData
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPVolumeChangeEvent
import me.sithiramunasinghe.flutter.flutter_radio_player.core.enums.FRPPlaybackStatus
import me.sithiramunasinghe.flutter.flutter_radio_player.core.events.FRPPlayerEvent
import me.sithiramunasinghe.flutter.flutter_radio_player.core.exceptions.FRPException
import me.sithiramunasinghe.flutter.flutter_radio_player.core.services.support.FRPMediaDescriptionAdapter
import me.sithiramunasinghe.flutter.flutter_radio_player.core.services.support.FRPPlayerListener
import me.sithiramunasinghe.flutter.flutter_radio_player.core.services.support.FRPPlayerNotificationListener
import org.greenrobot.eventbus.EventBus


class FRPCoreService : Service(), PlayerNotificationManager.NotificationListener {

    companion object {
        private const val TAG = "FRPCoreService"
    }

    var currentActivity: Activity? = null
    val context: Context = this

    // session keys
    private val playbackNotificationId = 1025
    private val mediaSessionId = "flutter_radio_player_media_session_id"
    private val playbackChannelId = "flutter_radio_player_pb_channel_id"

    var playbackStatus = FRPPlaybackStatus.LOADING
    var currentMetaData: MediaMetadata? = null
    var mediaSourceList: List<FRPAudioSource> = emptyList()
    var useICYData: Boolean = false
    private var currentPlayingItem: FRPCurrentSource? = null
    private val binder = LocalBinder()
    private var exoPlayer: ExoPlayer? = null
    private val eventBus: EventBus = EventBus.getDefault()
    private var mediaSessionConnector: MediaSessionConnector? = null
    private var playerNotificationManager: PlayerNotificationManager? = null

    private lateinit var mediaSession: MediaSessionCompat

    override fun onCreate() {
        Log.i(TAG, "FlutterRadioPlayerService::onCreate")
    }

    override fun onDestroy() {

        Log.i(TAG, "::: onDestroy :::")

        mediaSessionConnector?.setPlayer(null)
        playerNotificationManager?.setPlayer(null)

        if (exoPlayer != null) {
            exoPlayer?.release()
            exoPlayer == null
        }

        if (mediaSessionConnector != null) {
            mediaSessionConnector = null
        }
        mediaSession.setActive(false)
        mediaSession.release()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i(TAG, ":::: FlutterRadioPlayerService.onTaskRemoved ::::")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(false)
        }
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {

        Log.i(TAG, ":::: FlutterRadioPlayerService.onStartCommand ::::")

        // player notification manager
        playerNotificationManager =
            PlayerNotificationManager.Builder(context, playbackNotificationId, playbackChannelId)
                .setChannelNameResourceId(me.sithiramunasinghe.flutter.flutter_radio_player.R.string.channel_name)
                .setChannelDescriptionResourceId(me.sithiramunasinghe.flutter.flutter_radio_player.R.string.channel_description)
                .setMediaDescriptionAdapter(FRPMediaDescriptionAdapter(this))
                .setNotificationListener(FRPPlayerNotificationListener(this))
                .build()

        // media session
        mediaSession = MediaSessionCompat(this, mediaSessionId)
        mediaSession.isActive = true

        val handler = Handler(Looper.getMainLooper())

        // build exoplayer
        exoPlayer = ExoPlayer.Builder(context)
            .setLooper(handler.looper)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(), true
            )
            .setLivePlaybackSpeedControl(
                DefaultLivePlaybackSpeedControl.Builder()
                    .setFallbackMaxPlaybackSpeed(1.04f)
                    .build()
            )
            .setHandleAudioBecomingNoisy(true)
            .build()

        // exoplayer configuration
        exoPlayer?.let {
            it.addListener(FRPPlayerListener(this, exoPlayer, playerNotificationManager, eventBus))
            it.playWhenReady = false
        }

        exoPlayer?.addAnalyticsListener(EventLogger())


        // set connector and player
        mediaSessionConnector = MediaSessionConnector(mediaSession)
        mediaSessionConnector?.setPlayer(exoPlayer)

        playerNotificationManager?.apply {

            Log.i(TAG, "Applying configurations...")

            // default buttons
            // TODO allow developer to choose actions on player init instead of hardcoding them here
            // ie. move true/false to Flutter side of the plugin and apply here
            // TODO fix stopping (not pausing) and resuming player before enabling stop button
            setUseStopAction(false)
            setUsePlayPauseActions(true)

            // next and prev buttons
            setUseNextAction(true)
            setUsePreviousAction(true)
            setUseNextActionInCompactView(true)
            setUsePreviousActionInCompactView(true)

            // disabled buttons
            setUseFastForwardAction(false)
            setUseRewindAction(false)
            setUseFastForwardActionInCompactView(false)
            setUseRewindActionInCompactView(false)

            setPlayer(exoPlayer)
            setMediaSessionToken(mediaSession.sessionToken)
        }

        Log.i(TAG, ":::: END OF onStartCommand IN SERVICE ::::")

        return START_REDELIVER_INTENT
    }

    fun setMediaSources(sourceList: List<FRPAudioSource>, playDefault: Boolean = false) {

        if (sourceList.isEmpty()) {
            throw FRPException("Empty media sources")
        }

        this.mediaSourceList = sourceList.sortedByDescending { it.isPrimary }

        if (this.mediaSourceList.none { frpAudioSource -> frpAudioSource.isPrimary }) {
            throw FRPException("No default source provided")
        }

        Log.i(TAG, "Current PlaybackStatus $playbackStatus")
        Log.i(TAG, "Current Player state ${exoPlayer?.playbackState}")

        val defaultSource = this.mediaSourceList.firstOrNull { frp -> frp.isPrimary }

        if (defaultSource != null) {
            Log.i(TAG, "Default media item added to exoplayer...")

            val mediaUrl = Uri.parse(defaultSource.url)

            val mediaBuilder =
                MediaItem.Builder().setUri(mediaUrl).setLiveConfiguration(
                    MediaItem.LiveConfiguration.Builder()
                        .setMaxPlaybackSpeed(1.02f)
                        .build()
                )

            if (defaultSource.isAcc == true) {
                mediaBuilder.setMimeType(MimeTypes.AUDIO_AAC)
                Log.d(TAG, "is an AAC media source")
            }

            exoPlayer?.addMediaSource(0, buildMediaSource(mediaUrl, mediaBuilder.build()))
            updateCurrentPlaying(defaultSource)
        }

        mediaSourceList.filter { source -> !source.isPrimary }.forEach { frp ->
            run {
                Log.i(TAG, "Added media source ${frp.title} with url ${frp.url}")

                val mediaUrl = Uri.parse(frp.url)

                val mediaBuilder = MediaItem.Builder()
                    .setUri(mediaUrl)
                    .setLiveConfiguration(
                        MediaItem.LiveConfiguration.Builder()
                            .setMaxPlaybackSpeed(1.02f)
                            .build()
                    )

                if (frp.isAcc!!) {
                    mediaBuilder.setMimeType(MimeTypes.AUDIO_AAC)
                }

                exoPlayer?.addMediaSource(buildMediaSource(mediaUrl, mediaBuilder.build()))
            }
        }

        Log.i(TAG, "Preparing player...")
        exoPlayer?.prepare()

        if (playDefault) {
            Log.i(TAG, "addMediaSources with default play")
            exoPlayer?.playWhenReady = true
            exoPlayer?.seekTo(0, C.TIME_UNSET)
            exoPlayer?.play()
            playbackStatus = FRPPlaybackStatus.PLAYING
        }
    }

    fun getPlayerState(): FRPPlaybackStatus {
        return playbackStatus
    }

    fun isPlaying(): Boolean {
        return exoPlayer?.isPlaying!!
    }

    fun play() {
        exoPlayer?.play()
    }

    fun pause() {
        exoPlayer?.pause()
    }

    fun stop() {
        exoPlayer?.stop()
    }

    fun playOrPause() {
        if (isPlaying()) {
            exoPlayer?.pause()
        } else {
            exoPlayer?.play()
        }
    }

    fun nextMediaItem() {
        Log.i(TAG, "Seeking to next media item...")
        exoPlayer?.seekToNext()
        exoPlayer?.prepare()
        exoPlayer?.play()
        val currentMedia = mediaSourceList[exoPlayer?.currentMediaItemIndex!!]
        eventBus.post(FRPPlayerEvent(currentSource = updateCurrentPlaying(currentMedia)))
    }

    fun prevMediaItem() {
        Log.i(TAG, "Seeking to prev media item...")
        exoPlayer?.seekToPrevious()
        exoPlayer?.prepare()
        exoPlayer?.play()
        val currentMedia = mediaSourceList[exoPlayer?.currentMediaItemIndex!!]
        eventBus.post(FRPPlayerEvent(currentSource = updateCurrentPlaying(currentMedia)))
    }

    fun seekToMediaItem(index: Int, playIfReady: Boolean) {
        Log.i(TAG, "Seeking to media item, pos: $index...")

        Log.d(TAG, "playbackState ${exoPlayer?.playbackState}")
        Log.d(TAG, "playbackLooper ${exoPlayer?.playbackLooper}")
        exoPlayer?.seekToDefaultPosition(index)
        exoPlayer?.apply {
            playWhenReady = playIfReady
        }
        exoPlayer?.prepare()
        val currentMedia = mediaSourceList[exoPlayer?.currentMediaItemIndex!!]
        eventBus.post(FRPPlayerEvent(currentSource = updateCurrentPlaying(currentMedia)))
    }

    fun setVolume(volume: Float) {
        if (volume < 0) {
            throw FRPException("Volumes needs to be more than 0")
        }
        Log.i(TAG, "Changing volume")
        exoPlayer?.volume = volume
        eventBus.post(FRPPlayerEvent(volumeChangeEvent = FRPVolumeChangeEvent(volume)))
    }

    fun useIcyData(status: Boolean = false) {
        this.useICYData = status
    }

    fun getMetaData(): FRPIcyMetaData {
        return FRPIcyMetaData(currentMetaData)
    }

    private fun updateCurrentPlaying(defaultSource: FRPAudioSource): FRPCurrentSource {
        currentPlayingItem =
            FRPCurrentSource(title = defaultSource.title, description = defaultSource.description)
        eventBus.post(FRPPlayerEvent(currentSource = currentPlayingItem))
        return currentPlayingItem!!
    }

    private fun buildMediaSource(mediaUrl: Uri, mediaItem: MediaItem): MediaSource {

        val defaultDataSource = DefaultHttpDataSource.Factory().apply {
            setUserAgent(Util.getUserAgent(context, "flutter-radio-player"))
            if (useICYData) {
                setDefaultRequestProperties(mapOf("Icy-MetaData" to "1"))
            }
        }

        return when (val type = Util.inferContentType(mediaUrl)) {
            C.CONTENT_TYPE_HLS -> HlsMediaSource.Factory(defaultDataSource)
                .createMediaSource(mediaItem)
            C.CONTENT_TYPE_OTHER -> ProgressiveMediaSource.Factory(defaultDataSource)
                .createMediaSource(mediaItem)
            else -> {
                throw FRPException("Unsupported type: $type")
            }
        }
    }

    inner class LocalBinder : Binder() {
        val service: FRPCoreService
            get() = this@FRPCoreService
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
}