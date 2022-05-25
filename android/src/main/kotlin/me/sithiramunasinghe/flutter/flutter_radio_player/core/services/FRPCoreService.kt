package me.sithiramunasinghe.flutter.flutter_radio_player.core.services

import android.app.Activity
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.*
import android.support.v4.media.session.MediaSessionCompat
import com.google.android.exoplayer2.C
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.MediaMetadata
import com.google.android.exoplayer2.audio.AudioAttributes
import com.google.android.exoplayer2.ext.mediasession.MediaSessionConnector
import com.google.android.exoplayer2.source.DefaultMediaSourceFactory
import com.google.android.exoplayer2.ui.PlayerNotificationManager
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource
import com.google.android.exoplayer2.util.Util
import io.flutter.Log
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPAudioSource
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPIcyMetaData
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

    private var runnableMetaData: Runnable? = null
    var currentActivity: Activity? = null
    val context: Context = this

    // session keys
    private val playbackNotificationId = 1025
    private val mediaSessionId = "flutter_radio_player_media_session_id"
    private val playbackChannelId = "flutter_radio_player_pb_channel_id"

    //    private var audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

    var playbackStatus = FRPPlaybackStatus.STOPPED
    var currentMetaData: MediaMetadata? = null
    var mediaSourceList: List<FRPAudioSource> = emptyList()
    var useICYData: Boolean = false

    var handler: Handler = Handler(Looper.getMainLooper())

    private val binder = LocalBinder()
    private var exoPlayer: ExoPlayer? = null
    private val eventBus: EventBus = EventBus.getDefault()
    private var exoPlayerBuilder = ExoPlayer.Builder(context)
    private var mediaSessionConnector: MediaSessionConnector? = null
    private var playerNotificationManager: PlayerNotificationManager? = null

    private lateinit var mediaSession: MediaSessionCompat

    override fun onCreate() {

        Log.i(TAG, "FlutterRadioPlayerService::onCreate")

        // build exoplayer
        exoPlayer = exoPlayerBuilder
            .setLooper(handler.looper)
            .setMediaSourceFactory(DefaultMediaSourceFactory(DefaultHttpDataSource.Factory().apply {
                setUserAgent(Util.getUserAgent(context, "flutter-radio-player"))
                setDefaultRequestProperties(mapOf("Icy-MetaData" to "1"))
            }))
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.CONTENT_TYPE_MUSIC)
                    .build(), true
            )
            .setHandleAudioBecomingNoisy(true)
            .build()

        // exoplayer configuration
        exoPlayer?.let {
            it.addListener(FRPPlayerListener(this, exoPlayer, playerNotificationManager, eventBus))
            it.playWhenReady = false
        }

        Log.i(TAG, "::::: END FlutterRadioPlayerService::onCreate ::::")
    }

    override fun onDestroy() {

        Log.i(TAG, "::: onDestroy :::")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            mediaSession.release()
        }

        if (exoPlayer != null) {
            exoPlayer?.release()
        }

        mediaSessionConnector?.setPlayer(null)
        playerNotificationManager?.setPlayer(null)

        if (runnableMetaData != null) {
            handler.removeCallbacksAndMessages(null)
            runnableMetaData = null
        }

        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

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

        // set connector and player
        mediaSessionConnector = MediaSessionConnector(mediaSession)
        mediaSessionConnector?.setPlayer(exoPlayer)

        playerNotificationManager?.apply {

            Log.i(TAG, "Applying configurations...")

            // default buttons
            setUseStopAction(true)
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

        Log.i(TAG, ":::: END OF SERVICE ::::")

        return START_REDELIVER_INTENT
    }

    fun setMediaSources(sourceList: List<FRPAudioSource>, playDefault: Boolean = false) {

        if (sourceList.isEmpty()) {
            throw FRPException("Empty media sources")
        }

        this.mediaSourceList = sourceList
        var tempMediaSources = this.mediaSourceList

        if (tempMediaSources.none { frpAudioSource -> frpAudioSource.isPrimary }) {
            throw FRPException("No default source provided")
        }

        Log.i(TAG, "Current PlaybackStatus $playbackStatus")

        val defaultSource = tempMediaSources.firstOrNull { frp -> frp.isPrimary }

        if (playbackStatus == FRPPlaybackStatus.PAUSED || playbackStatus == FRPPlaybackStatus.STOPPED) {

            if (defaultSource != null) {
                Log.i(TAG, "Default media item added to exoplayer...")
                exoPlayer?.addMediaItem(0, MediaItem.fromUri(Uri.parse(defaultSource.url)))
                tempMediaSources = tempMediaSources.dropWhile { frp ->
                    frp.url.equals(defaultSource.url)
                }
            }

            tempMediaSources.forEach { frp ->
                run {
                    Log.i(TAG, "Added media source ${frp.title} with url ${frp.url}")
                    exoPlayer?.addMediaItem(MediaItem.fromUri(Uri.parse(frp.url)))
                }
            }

            Log.i(TAG, "Preparing player...")
            exoPlayer?.prepare()
        }

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

    fun playOrPause() {
        if (isPlaying()) {
            exoPlayer?.pause()
        } else {
            exoPlayer?.play()
        }
    }

    fun nextMediaItem() {
        Log.i(TAG, "Seeking to next media item...")
        eventBus.post(FRPPlayerEvent(data = "enqueue_next_source"))
        exoPlayer?.seekToNextMediaItem()
    }

    fun prevMediaItem() {
        Log.i(TAG, "Seeking to prev media item...")
        eventBus.post(FRPPlayerEvent(data = "enqueue_prev_source"))
        exoPlayer?.seekToPreviousMediaItem()
    }

    fun setVolume(volume: Float) {
        if (volume < 0) {
            throw FRPException("Volumes needs to be more than 0")
        }
        Log.i(TAG, "Changing volume")
        exoPlayer?.volume = volume
    }

    fun useIcyData(status: Boolean = false) {
        this.useICYData = status
    }

    fun initPeriodicMetaData(milliseconds: Float? = 30000F) {
        if (runnableMetaData == null) {
            runnableMetaData = object : Runnable {
                override fun run() {
                    currentMetaData = exoPlayer?.mediaMetadata
                    eventBus.post(FRPPlayerEvent(FRPIcyMetaData = FRPIcyMetaData(currentMetaData)))
                    handler.postDelayed(this, milliseconds!!.toLong())
                }
            }
            handler.postDelayed(runnableMetaData!!, milliseconds!!.toLong())
        }
    }

    fun getMetaData(): FRPIcyMetaData {
        return FRPIcyMetaData(currentMetaData)
    }

    inner class LocalBinder : Binder() {
        val service: FRPCoreService
            get() = this@FRPCoreService
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
}