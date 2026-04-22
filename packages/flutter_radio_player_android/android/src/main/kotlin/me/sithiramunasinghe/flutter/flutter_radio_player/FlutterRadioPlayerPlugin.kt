package me.sithiramunasinghe.flutter.flutter_radio_player

import android.app.Activity
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.AssetManager
import androidx.annotation.OptIn
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.io.ByteStreams
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import me.sithiramunasinghe.flutter.flutter_radio_player.core.PlaybackService
import java.io.InputStream
import java.util.concurrent.Executor

class FlutterRadioPlayerPlugin : FlutterPlugin, ActivityAware, RadioPlayerHostApi {

    private var applicationContext: Context? = null
    private var controllerFuture: ListenableFuture<MediaController>? = null
    private lateinit var mainExecutor: Executor

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
        mainExecutor = ContextCompat.getMainExecutor(flutterPluginBinding.applicationContext)
        RadioPlayerHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
        setupEventChannels(flutterPluginBinding)

        val token = SessionToken(
            flutterPluginBinding.applicationContext,
            ComponentName(flutterPluginBinding.applicationContext, PlaybackService::class.java)
        )
        controllerFuture = MediaController.Builder(flutterPluginBinding.applicationContext, token)
            .buildAsync()
            .also { future ->
                future.addListener({
                    PlaybackService.playbackStateSink = playbackStateSink
                    PlaybackService.nowPlayingSink = nowPlayingSink
                    PlaybackService.volumeSink = volumeSink
                }, mainExecutor)
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RadioPlayerHostApi.setUp(binding.binaryMessenger, null)
        PlaybackService.playbackStateSink = null
        PlaybackService.nowPlayingSink = null
        PlaybackService.volumeSink = null
        playbackStateSink = null
        nowPlayingSink = null
        volumeSink = null
        releaseController()
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
    override fun initialize(
        sources: List<RadioSourceMessage>,
        playWhenReady: Boolean,
        callback: (Result<Unit>) -> Unit,
    ) = runOnController(callback) { controller ->
        controller.volume = 0.5F
        controller.playWhenReady = playWhenReady
        if (sources.isNotEmpty()) {
            PlaybackService.latestMetadata = null
            controller.setMediaItems(sources.map { buildMediaItem(it) })
            controller.prepare()
        }
        Result.success(Unit)
    }

    override fun play(callback: (Result<Unit>) -> Unit) = runOnController(callback) {
        it.play()
        Result.success(Unit)
    }

    override fun pause(callback: (Result<Unit>) -> Unit) = runOnController(callback) {
        it.pause()
        Result.success(Unit)
    }

    override fun playOrPause(callback: (Result<Unit>) -> Unit) = runOnController(callback) {
        if (it.mediaItemCount != 0) {
            if (it.isPlaying) it.pause() else it.play()
        }
        Result.success(Unit)
    }

    override fun setVolume(volume: Double, callback: (Result<Unit>) -> Unit) =
        runOnController(callback) {
            it.volume = volume.toFloat()
            Result.success(Unit)
        }

    override fun getVolume(callback: (Result<Double>) -> Unit) = runOnController(callback) {
        Result.success(it.volume.toDouble())
    }

    override fun nextSource(callback: (Result<Unit>) -> Unit) = runOnController(callback) {
        PlaybackService.latestMetadata = null
        it.seekToNextMediaItem()
        Result.success(Unit)
    }

    override fun previousSource(callback: (Result<Unit>) -> Unit) = runOnController(callback) {
        PlaybackService.latestMetadata = null
        it.seekToPreviousMediaItem()
        Result.success(Unit)
    }

    override fun jumpToSourceAtIndex(index: Long, callback: (Result<Unit>) -> Unit) =
        runOnController(callback) {
            PlaybackService.latestMetadata = null
            it.seekToDefaultPosition(index.toInt())
            Result.success(Unit)
        }

    override fun dispose(callback: (Result<Unit>) -> Unit) {
        releaseController()
        applicationContext?.let {
            it.stopService(Intent(it, PlaybackService::class.java))
        }
        callback(Result.success(Unit))
    }

    private fun <T> runOnController(
        callback: (Result<T>) -> Unit,
        block: (MediaController) -> Result<T>,
    ) {
        val future = controllerFuture
        if (future == null) {
            callback(Result.failure(notReadyError()))
            return
        }
        future.addListener({
            val outcome = try {
                val controller = future.get()
                if (controller == null) {
                    Result.failure(notReadyError())
                } else {
                    block(controller)
                }
            } catch (t: Throwable) {
                Result.failure(toFlutterError(t))
            }
            callback(outcome)
        }, mainExecutor)
    }

    private fun releaseController() {
        controllerFuture?.let { future ->
            if (future.isDone) {
                try {
                    future.get()?.run {
                        stop()
                        release()
                    }
                } catch (_: Throwable) {
                    // nothing usable to release
                }
            } else {
                future.cancel(false)
            }
        }
        controllerFuture = null
    }

    private fun notReadyError(): FlutterError =
        FlutterError("controller_unavailable", "MediaController is not available", null)

    private fun toFlutterError(t: Throwable): FlutterError {
        val cause = (t as? java.util.concurrent.ExecutionException)?.cause ?: t
        return FlutterError(
            cause::class.java.simpleName,
            cause.message ?: "MediaController operation failed",
            null,
        )
    }

    private fun setupEventChannels(binding: FlutterPlugin.FlutterPluginBinding) {
        OnPlaybackStateChangedStreamHandler.register(
            binding.binaryMessenger,
            object : OnPlaybackStateChangedStreamHandler() {
                override fun onListen(arguments: Any?, sink: PigeonEventSink<Boolean>) {
                    playbackStateSink = sink
                    PlaybackService.playbackStateSink = sink
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

    @OptIn(UnstableApi::class)
    private fun buildMediaItem(source: RadioSourceMessage): MediaItem {
        val metaBuilder = MediaMetadata.Builder()
        if (source.title.isNullOrEmpty()) {
            metaBuilder.setArtist(getAppName())
        } else {
            metaBuilder.setTitle(source.title)
            metaBuilder.setArtist(getAppName())
        }
        val artwork = source.artwork
        if (!artwork.isNullOrEmpty()) {
            if (artwork.startsWith("http://") || artwork.startsWith("https://")) {
                metaBuilder.setArtworkUri(artwork.toUri())
            } else {
                loadFlutterAsset(artwork)?.use { stream ->
                    metaBuilder.setArtworkData(
                        ByteStreams.toByteArray(stream),
                        MediaMetadata.PICTURE_TYPE_FRONT_COVER,
                    )
                }
            }
        }
        return MediaItem.Builder()
            .setUri(source.url)
            .setMediaMetadata(metaBuilder.build())
            .build()
    }

    private fun loadFlutterAsset(assetPath: String): InputStream? {
        return try {
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
            val assetManager: AssetManager = applicationContext!!.assets
            assetManager.open(key)
        } catch (_: Exception) {
            null
        }
    }

    private fun getAppName(): String? {
        val context = applicationContext ?: return null
        return try {
            val pm: PackageManager = context.packageManager
            val ai = pm.getApplicationInfo(context.packageName, 0)
            pm.getApplicationLabel(ai) as String
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }
}
