package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.audiofx.AudioEffect
import android.media.session.MediaSession
import android.net.Uri
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.support.v4.media.session.MediaSessionCompat
import androidx.annotation.Nullable
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.google.android.exoplayer2.*
import com.google.android.exoplayer2.ext.mediasession.MediaSessionConnector
import com.google.android.exoplayer2.source.MediaSource
import com.google.android.exoplayer2.source.ProgressiveMediaSource
import com.google.android.exoplayer2.source.hls.HlsMediaSource
import com.google.android.exoplayer2.ui.PlayerNotificationManager
import com.google.android.exoplayer2.upstream.DefaultAllocator
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory
import com.google.android.exoplayer2.util.Util
import me.sithiramunasinghe.flutter.flutter_radio_player.FlutterRadioPlayerPlugin.Companion.broadcastActionName
import me.sithiramunasinghe.flutter.flutter_radio_player.FlutterRadioPlayerPlugin.Companion.broadcastChangedMetaDataName
import me.sithiramunasinghe.flutter.flutter_radio_player.R
import me.sithiramunasinghe.flutter.flutter_radio_player.core.enums.PlaybackStatus
import java.util.concurrent.TimeUnit
import java.util.logging.Logger

class StreamingCore : Service(), AudioManager.OnAudioFocusChangeListener {

    private var logger = Logger.getLogger(StreamingCore::javaClass.name)
    var activity: Activity? = null
    var iconBitmap: Bitmap? = null


    private var isBound = false
    private val iBinder = LocalBinder()
    private lateinit var playbackStatus: PlaybackStatus
    private lateinit var dataSourceFactory: DefaultDataSourceFactory
    private lateinit var localBroadcastManager: LocalBroadcastManager

    // context
    private val context = this
    private val broadcastIntent = Intent(broadcastActionName)
    private val broadcastMetaDataIntent = Intent(broadcastChangedMetaDataName)


    // class instances
    private val handler = Handler();

    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var player: SimpleExoPlayer? = null
    private var mediaSessionConnector: MediaSessionConnector? = null
    private var mediaSession: MediaSession? = null
    private var playerNotificationManager: PlayerNotificationManager? = null

    var notificationTitle = ""
    var notificationSubTitle = ""

    val afChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                logger.info("AUDIOFOCUS_LOSS")

                pause()
                handler.postDelayed(delayedStopRunnable, TimeUnit.SECONDS.toMillis(30))
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                logger.info("AUDIOFOCUS_LOSS_TRANSIENT")
                pause()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                setVolume(0.1)
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                setVolume(1.0)
                newPlay()
            }
        }
    }

    // session keys
    private val playbackNotificationId = 1025
    private val mediaSessionId = "streaming_audio_player_media_session"
    private val playbackChannelId = "streaming_audio_player_channel_id"

    inner class LocalBinder : Binder() {
        internal val service: StreamingCore
            get() = this@StreamingCore
    }

    /*===========================
     *        Player APIS
     *===========================
     */

    fun play() {
        logger.info("playing audio $player ...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager!!.requestAudioFocus(focusRequest!!)
        } else {
            audioManager!!.requestAudioFocus(afChangeListener, AudioEffect.CONTENT_TYPE_MUSIC, 0);
        }
        player?.playWhenReady = true
        wasPlaying = false

    }

    fun newPlay() {
        logger.info("new Play audio $player ...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager!!.requestAudioFocus(focusRequest!!)
        } else {
            audioManager!!.requestAudioFocus(afChangeListener, AudioEffect.CONTENT_TYPE_MUSIC, 0);
        }
        player?.stop()
        player?.prepare()
        player?.playWhenReady = true
        wasPlaying = false

    }

    fun pause() {
        logger.info("pausing audio...")
        player?.playWhenReady = false
    }


    fun reEmmitSatus() {
        logger.info("reEmmtSatus ...")
        if (this::playbackStatus.isInitialized) {
            playbackStatus = when (playbackStatus) {
                PlaybackStatus.PAUSED -> {
                    pushEvent(FLUTTER_RADIO_PLAYER_PAUSED)
                    PlaybackStatus.PAUSED
                }
                PlaybackStatus.PLAYING -> {
                    pushEvent(FLUTTER_RADIO_PLAYER_PLAYING)
                    PlaybackStatus.PLAYING
                }
                PlaybackStatus.LOADING -> {
                    pushEvent(FLUTTER_RADIO_PLAYER_LOADING)
                    PlaybackStatus.LOADING

                }
                PlaybackStatus.STOPPED -> {
                    pushEvent(FLUTTER_RADIO_PLAYER_STOPPED)
                    PlaybackStatus.STOPPED
                }
                PlaybackStatus.ERROR -> {
                    pushEvent(FLUTTER_RADIO_PLAYER_ERROR)
                    PlaybackStatus.ERROR
                }
            }
        }
    }

    fun isPlaying(): Boolean {
        val isPlaying = this.playbackStatus == PlaybackStatus.PLAYING
        logger?.info("is playing status: $isPlaying")
        return isPlaying
    }

    var wasPlaying: Boolean = false

    fun stop() {
        logger.info("stopping audio $player ...")
        player?.stop()
        stopSelf()
        isBound = false
    }

    fun setTitle(title: String, subTitle: String) {
        logger.info("settingTitle $title,  $player ...")
        this.notificationTitle = title
        this.notificationSubTitle = subTitle
        logger.info("calling  playerNotificationManager.invalidate()...")
        playerNotificationManager?.invalidate()
    }

    fun setVolume(volume: Double) {
        logger.info("Changing volume to : $volume")
        player?.volume = volume.toFloat()
    }

    fun setUrl(streamUrl: String, playWhenReady: Boolean) {
        logger.info("ReadyPlay status: $playWhenReady")
        logger.info("Set stream URL: $streamUrl")
        player?.setMediaSource(buildMediaSource(dataSourceFactory, streamUrl))
        player?.prepare()
        player?.playWhenReady = playWhenReady
    }

    private var delayedStopRunnable = Runnable {
//        stop()
    }


    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        logger.info("Firing up service. (onStartCommand)...")

        localBroadcastManager = LocalBroadcastManager.getInstance(context)

        logger.info("LocalBroadCastManager Received...")

        // get details
        notificationTitle = intent!!.getStringExtra("appName")
        notificationSubTitle = intent.getStringExtra("subTitle")
        val streamUrl = intent.getStringExtra("streamUrl")
        val playWhenReady = intent.getStringExtra("playWhenReady") == "true"
        player = SimpleExoPlayer
                .Builder(context)
                .setLoadControl(CustomLoadControl
                        .Builder()
                        .setPrioritizeTimeOverSizeThresholds(true)
                        .setBufferDurationsMs(10000,
                                10000,
                                10000,
                                10000)
                        .build()
                ).build()



        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).run {
                setAudioAttributes(android.media.AudioAttributes.Builder().run {
                    setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                    setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                    build()
                })
                setAcceptsDelayedFocusGain(true)
                setOnAudioFocusChangeListener(this@StreamingCore, handler)
                build()
            }
        }

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager!!.requestAudioFocus(focusRequest)
        } else {
            audioManager!!.requestAudioFocus(afChangeListener, AudioEffect.CONTENT_TYPE_MUSIC, 0);
        }

        dataSourceFactory = DefaultDataSourceFactory(context, Util.getUserAgent(context, notificationTitle))

        val audioSource = buildMediaSource(dataSourceFactory, streamUrl)

        val playerEvents = object : Player.EventListener {

            override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {
                playbackStatus = when (playbackState) {
                    Player.STATE_ENDED -> {
                        pushEvent(FLUTTER_RADIO_PLAYER_STOPPED)
                        PlaybackStatus.STOPPED
                    }
                    Player.STATE_BUFFERING -> {
                        pushEvent(FLUTTER_RADIO_PLAYER_LOADING)
                        PlaybackStatus.LOADING
                    }
                    Player.STATE_IDLE -> {
                        pushEvent(FLUTTER_RADIO_PLAYER_STOPPED)
                        PlaybackStatus.STOPPED
                    }
                    Player.STATE_READY -> {
                        setPlayWhenReady(playWhenReady)
                    }
                    else -> if (this@StreamingCore::playbackStatus.isInitialized) this@StreamingCore.playbackStatus else PlaybackStatus.STOPPED

                }
                if (playbackStatus == PlaybackStatus.PLAYING) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        this@StreamingCore.audioManager!!.requestAudioFocus(this@StreamingCore.focusRequest!!)
                    } else {
                        this@StreamingCore.audioManager!!.requestAudioFocus(this@StreamingCore.afChangeListener, AudioEffect.CONTENT_TYPE_MUSIC, 0);
                    }
                } else {
                    logger.info("Remove player as a foreground notification...")
                    stopForeground(false)
                }
                logger.info("onPlayerStateChanged: $playbackStatus")

            }

            override fun onPlayerError(error: ExoPlaybackException) {
                pushEvent(FLUTTER_RADIO_PLAYER_ERROR)
                playbackStatus = PlaybackStatus.ERROR
                error.printStackTrace()
            }
        }

        // set exo player configs
        player?.let {
            it.addListener(playerEvents)
            it.playWhenReady = playWhenReady
            it.setMediaSource(audioSource)
            it.prepare()
        }

        // register our meta data listener
        player?.addMetadataOutput {
            val metaData = it.get(0).toString()
            localBroadcastManager.sendBroadcast(broadcastMetaDataIntent.putExtra("meta_data", metaData))
        }

        val playerNotificationManager = PlayerNotificationManager.createWithNotificationChannel(
                context,
                playbackChannelId,
                R.string.channel_name,
                R.string.channel_description,
                playbackNotificationId,
                object : PlayerNotificationManager.MediaDescriptionAdapter {

                    override fun getCurrentContentTitle(player: Player): String {
                        logger.info("updating title = $notificationTitle")
                        return notificationTitle
                    }

                    @Nullable
                    override fun createCurrentContentIntent(player: Player): PendingIntent {
                        val intent = Intent(this@StreamingCore, activity!!.javaClass)
                        val contentPendingIntent = PendingIntent.getActivity(this@StreamingCore, 0, intent, 0);
                        return contentPendingIntent;
                    }

                    @Nullable
                    override fun getCurrentContentText(player: Player): String? {
                        return null//notificationSubTitle
                    }

                    @Nullable
                    override fun getCurrentLargeIcon(player: Player, callback: PlayerNotificationManager.BitmapCallback): Bitmap? {
                        return this@StreamingCore.iconBitmap; // OS will use the application icon.
                    }

                },
                object : PlayerNotificationManager.NotificationListener {
                    override fun onNotificationCancelled(notificationId: Int, dismissedByUser: Boolean) {
                        logger.info("Notification Cancelled. Stopping player...")
                        stop()
                    }

                    override fun onNotificationPosted(notificationId: Int, notification: Notification, ongoing: Boolean) {
                        logger.info("Attaching player as a foreground notification...ongoing:$ongoing")
                        startForeground(notificationId, notification)
                        if (!ongoing) {
                            stopForeground(false)
                        }
                    }
                }
        )
        this.playerNotificationManager = playerNotificationManager
        logger.info("Building Media Session and Player Notification.")

        val mediaSession = MediaSessionCompat(context, mediaSessionId)
        mediaSession.isActive = true

        mediaSessionConnector = MediaSessionConnector(mediaSession)
        mediaSessionConnector?.setPlayer(player)

        val dispatcher = CustomControlDispatcher()
        dispatcher.fastForwardIncrementMs = 0
        dispatcher.rewindIncrementMs = 0

        playerNotificationManager.setControlDispatcher(dispatcher)
        playerNotificationManager.setUseStopAction(true)
        playerNotificationManager.setFastForwardIncrementMs(0)
        playerNotificationManager.setRewindIncrementMs(0)
        playerNotificationManager.setUsePlayPauseActions(true)
        playerNotificationManager.setUseNavigationActions(false)
        playerNotificationManager.setDefaults(Notification.DEFAULT_ALL)
        playerNotificationManager.setUseNavigationActionsInCompactView(false)
        playerNotificationManager.setPlayer(player)
        playerNotificationManager.setMediaSessionToken(mediaSession.sessionToken)

//        playerNotificationManager.
        playbackStatus = PlaybackStatus.PLAYING

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return iBinder
    }

    override fun onDestroy() {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            mediaSession?.release()
        }

        mediaSessionConnector?.setPlayer(null)
        playerNotificationManager?.setPlayer(null)
        player?.release()

        super.onDestroy()
    }

    override fun onAudioFocusChange(audioFocus: Int) {
        when (audioFocus) {

            AudioManager.AUDIOFOCUS_GAIN -> {
                player?.volume = 0.8f
                if (wasPlaying) {
                    newPlay()
                }
            }

            AudioManager.AUDIOFOCUS_LOSS -> {
                logger.info("AudioManager.AUDIOFOCUS_LOSS")
                if (isPlaying()) {
                    pause()
                }
            }

            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                if (isPlaying()) {
                    logger.info("AudioManager.AUDIOFOCUS_LOSS_TRANSIENT")
                    pause()
                    wasPlaying = true
                }
            }

            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                if (isPlaying()) {
                    player?.volume = 0.1f
                }
            }
        }
    }

    /**
     * Push events to local broadcaster service.
     */
    private fun pushEvent(eventName: String) {
        logger.info("Pushing Event: $eventName")
        localBroadcastManager.sendBroadcast(Intent(broadcastActionName).putExtra("status", eventName))
    }

    /**
     * Build the media source depending of the URL content type.
     */
    private fun buildMediaSource(dataSourceFactory: DefaultDataSourceFactory, streamUrl: String): MediaSource {

        val uri = Uri.parse(streamUrl)

        return when (val type = Util.inferContentType(uri)) {
//            C.TYPE_DASH -> DashMediaSource.Factory(dataSourceFactory).createMediaSource(MediaItem.fromUri(uri))
            C.TYPE_HLS -> HlsMediaSource.Factory(dataSourceFactory).createMediaSource(MediaItem.fromUri(uri))
            C.TYPE_OTHER -> ProgressiveMediaSource.Factory(dataSourceFactory)
//                    .setContinueLoadingCheckIntervalBytes(1024*32)
                    .createMediaSource(MediaItem.fromUri(uri))
            else -> {
                throw IllegalStateException("Unsupported type: $type")
            }
        }
    }

    private fun setPlayWhenReady(playWhenReady: Boolean): PlaybackStatus {
        return if (playWhenReady) {
            pushEvent(FLUTTER_RADIO_PLAYER_PLAYING)
            PlaybackStatus.PLAYING
        } else {
            pushEvent(FLUTTER_RADIO_PLAYER_PAUSED)
            PlaybackStatus.PAUSED
        }
    }

}
