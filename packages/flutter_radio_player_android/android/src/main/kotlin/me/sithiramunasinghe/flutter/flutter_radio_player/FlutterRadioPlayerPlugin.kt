package me.sithiramunasinghe.flutter.flutter_radio_player

import android.app.Activity
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.AssetManager
import androidx.annotation.OptIn
import androidx.core.net.toUri
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.io.ByteStreams
import com.google.common.util.concurrent.MoreExecutors
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import me.sithiramunasinghe.flutter.flutter_radio_player.core.PlaybackService
import java.io.InputStream

class FlutterRadioPlayerPlugin : FlutterPlugin, ActivityAware, RadioPlayerHostApi {

    private var applicationContext: Context? = null
    private var mediaController: MediaController? = null
    private var isMediaControllerAvailable = false
    private val pendingOperations = mutableListOf<() -> Unit>()

    private var playbackStateSink: PigeonEventSink<Boolean>? = null
    private var nowPlayingSink: PigeonEventSink<NowPlayingInfoMessage>? = null
    private var volumeSink: PigeonEventSink<VolumeInfoMessage>? = null

    companion object {
        lateinit var sessionActivity: PendingIntent

        private fun getSessionActivity(context: Context, activity: Activity) {
            sessionActivity = PendingIntent.getActivity(
                context, 0, Intent(context, activity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        RadioPlayerHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
        setupEventChannels(flutterPluginBinding)

        val token = SessionToken(
            flutterPluginBinding.applicationContext,
            ComponentName(flutterPluginBinding.applicationContext, PlaybackService::class.java)
        )

        val mediaControllerFuture = MediaController.Builder(applicationContext!!, token).buildAsync()
        mediaControllerFuture.addListener({
            mediaController = mediaControllerFuture.get()
            isMediaControllerAvailable = true
            PlaybackService.playbackStateSink = playbackStateSink
            PlaybackService.nowPlayingSink = nowPlayingSink
            PlaybackService.volumeSink = volumeSink
            executePendingOperations()
        }, MoreExecutors.directExecutor())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RadioPlayerHostApi.setUp(binding.binaryMessenger, null)
        PlaybackService.playbackStateSink = null
        PlaybackService.nowPlayingSink = null
        PlaybackService.volumeSink = null
        playbackStateSink = null
        nowPlayingSink = null
        volumeSink = null
        mediaController?.release()
        mediaController = null
        isMediaControllerAvailable = false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        getSessionActivity(binding.activity.applicationContext, binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {}
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        getSessionActivity(binding.activity.applicationContext, binding.activity)
    }
    override fun onDetachedFromActivity() {}

    @OptIn(UnstableApi::class)
    override fun initialize(sources: List<RadioSourceMessage>, playWhenReady: Boolean) {
        withMediaController { controller ->
            if (controller.isPlaying) {
                playbackStateSink?.success(true)
                val title = PlaybackService.latestMetadata?.title?.toString()
                nowPlayingSink?.success(NowPlayingInfoMessage(title = title))
                return@withMediaController
            }

            controller.volume = 0.5F
            controller.playWhenReady = playWhenReady

            if (sources.isNotEmpty()) {
                controller.setMediaItems(sources.map { buildMediaItem(it) })
                controller.prepare()
            }
        }
    }

    override fun play() {
        withMediaController { it.play() }
    }

    override fun pause() {
        withMediaController { it.pause() }
    }

    override fun playOrPause() {
        withMediaController { controller ->
            if (controller.mediaItemCount != 0) {
                if (controller.isPlaying) controller.pause() else controller.play()
            }
        }
    }

    override fun setVolume(volume: Double) {
        withMediaController { it.volume = volume.toFloat() }
    }

    override fun getVolume(): Double {
        return mediaController?.volume?.toDouble() ?: 0.5
    }

    override fun nextSource() {
        withMediaController {
            PlaybackService.latestMetadata = null
            it.seekToNextMediaItem()
        }
    }

    override fun previousSource() {
        withMediaController {
            PlaybackService.latestMetadata = null
            it.seekToPreviousMediaItem()
        }
    }

    override fun jumpToSourceAtIndex(index: Long) {
        withMediaController {
            PlaybackService.latestMetadata = null
            it.seekToDefaultPosition(index.toInt())
        }
    }

    override fun dispose() {
        mediaController?.run {
            stop()
            release()
        }
        mediaController = null
        isMediaControllerAvailable = false
    }

    private fun setupEventChannels(binding: FlutterPlugin.FlutterPluginBinding) {
        OnPlaybackStateChangedStreamHandler.register(
            binding.binaryMessenger,
            object : OnPlaybackStateChangedStreamHandler() {
                override fun onListen(arguments: Any?, sink: PigeonEventSink<Boolean>) {
                    playbackStateSink = sink
                    PlaybackService.playbackStateSink = sink
                    executePendingOperations()
                }
                override fun onCancel(arguments: Any?) {
                    playbackStateSink = null
                    PlaybackService.playbackStateSink = null
                }
            }
        )

        OnNowPlayingChangedStreamHandler.register(
            binding.binaryMessenger,
            object : OnNowPlayingChangedStreamHandler() {
                override fun onListen(arguments: Any?, sink: PigeonEventSink<NowPlayingInfoMessage>) {
                    nowPlayingSink = sink
                    PlaybackService.nowPlayingSink = sink
                    executePendingOperations()
                }
                override fun onCancel(arguments: Any?) {
                    nowPlayingSink = null
                    PlaybackService.nowPlayingSink = null
                }
            }
        )

        OnVolumeChangedStreamHandler.register(
            binding.binaryMessenger,
            object : OnVolumeChangedStreamHandler() {
                override fun onListen(arguments: Any?, sink: PigeonEventSink<VolumeInfoMessage>) {
                    volumeSink = sink
                    PlaybackService.volumeSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    volumeSink = null
                    PlaybackService.volumeSink = null
                }
            }
        )
    }

    private fun withMediaController(action: (MediaController) -> Unit) {
        if (isMediaControllerAvailable && mediaController != null) {
            action(mediaController!!)
        } else {
            pendingOperations.add { action(mediaController!!) }
        }
    }

    private fun executePendingOperations() {
        if (!isMediaControllerAvailable || mediaController == null) return
        pendingOperations.forEach { it() }
        pendingOperations.clear()
    }

    @OptIn(UnstableApi::class)
    private fun buildMediaItem(source: RadioSourceMessage): MediaItem {
        val metaBuilder = MediaMetadata.Builder()
        if (source.title.isNullOrEmpty()) {
            metaBuilder.setArtist(getAppName())
        } else {
            metaBuilder.setTitle(source.title)
            metaBuilder.setArtist(getAppName())
        }
        if (!source.artwork.isNullOrEmpty()) {
            if (source.artwork!!.contains("http")) {
                metaBuilder.setArtworkUri(source.artwork!!.toUri())
            } else {
                val stream = loadFlutterAsset(source.artwork)
                if (stream != null) {
                    metaBuilder.setArtworkData(
                        ByteStreams.toByteArray(stream),
                        MediaMetadata.PICTURE_TYPE_FRONT_COVER
                    )
                }
            }
        }
        return MediaItem.Builder()
            .setUri(source.url)
            .setMediaMetadata(metaBuilder.build())
            .build()
    }

    private fun loadFlutterAsset(assetPath: String?): InputStream? {
        return try {
            val flutterLoader = FlutterLoader()
            flutterLoader.startInitialization(applicationContext!!)
            flutterLoader.ensureInitializationComplete(applicationContext!!, null)
            val key = flutterLoader.getLookupKeyForAsset(assetPath!!)
            val assetManager: AssetManager = applicationContext!!.assets
            assetManager.open(key)
        } catch (e: Exception) {
            null
        }
    }

    private fun getAppName(): String? {
        return try {
            val pm: PackageManager = applicationContext!!.packageManager
            val ai = pm.getApplicationInfo(applicationContext!!.packageName, 0)
            pm.getApplicationLabel(ai) as String
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }
}
