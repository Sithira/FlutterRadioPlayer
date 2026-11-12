package me.sithiramunasinghe.flutter.flutter_radio_player

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.AssetManager
import android.util.Log
import androidx.annotation.OptIn
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.io.ByteStreams
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import me.sithiramunasinghe.flutter.flutter_radio_player.core.PlaybackService
import me.sithiramunasinghe.flutter.flutter_radio_player.core.RadioStateStore
import java.io.InputStream
import java.util.concurrent.Executor

class FlutterRadioPlayerPlugin : FlutterPlugin, RadioPlayerHostApi {

    private var applicationContext: Context? = null
    private var controllerFuture: ListenableFuture<MediaController>? = null
    private lateinit var mainExecutor: Executor

    companion object {
        private const val LOG_TAG = "FlutterRadioPlayer"
        private const val DEFAULT_VOLUME = 0.5
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        mainExecutor = ContextCompat.getMainExecutor(flutterPluginBinding.applicationContext)
        RadioPlayerHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
        setupEventChannels(flutterPluginBinding)
    }

    private fun ensureController() {
        if (controllerFuture != null) return
        val context = applicationContext ?: return
        val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
        controllerFuture = MediaController.Builder(context, token).buildAsync()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RadioPlayerHostApi.setUp(binding.binaryMessenger, null)
        RadioStateStore.detachSink()
        releaseController()
    }

    @OptIn(UnstableApi::class)
    override fun initialize(
        sources: List<RadioSourceMessage>,
        playWhenReady: Boolean,
        callback: (Result<Unit>) -> Unit,
    ) {
        ensureController()
        RadioStateStore.clearError()
        runOnController(callback) { controller ->
            controller.volume = 0.5F
            controller.playWhenReady = playWhenReady
            if (sources.isNotEmpty()) {
                controller.setMediaItems(sources.map { buildMediaItem(it) })
                controller.prepare()
            }
            Result.success(Unit)
        }
    }

    override fun play(callback: (Result<Unit>) -> Unit) = runIfInitialized("play", callback) {
        playFromCurrentState(it)
    }

    override fun pause(callback: (Result<Unit>) -> Unit) = runIfInitialized("pause", callback) {
        it.pause()
    }

    override fun playOrPause(callback: (Result<Unit>) -> Unit) =
        runIfInitialized("playOrPause", callback) {
            if (it.mediaItemCount != 0) {
                if (it.isPlaying) it.pause() else playFromCurrentState(it)
            }
        }

    override fun setVolume(volume: Double, callback: (Result<Unit>) -> Unit) =
        runIfInitialized("setVolume", callback) {
            it.volume = volume.toFloat()
        }

    override fun getVolume(callback: (Result<Double>) -> Unit) {
        if (controllerFuture == null) {
            callback(Result.success(DEFAULT_VOLUME))
            return
        }
        runOnController(callback) {
            Result.success(it.volume.toDouble())
        }
    }

    override fun nextSource(callback: (Result<Unit>) -> Unit) =
        runIfInitialized("nextSource", callback) {
            it.seekToNextMediaItem()
        }

    override fun previousSource(callback: (Result<Unit>) -> Unit) =
        runIfInitialized("previousSource", callback) {
            it.seekToPreviousMediaItem()
        }

    override fun jumpToSourceAtIndex(index: Long, callback: (Result<Unit>) -> Unit) =
        runIfInitialized("jumpToSourceAtIndex", callback) {
            it.seekToDefaultPosition(index.toInt())
        }

    override fun dispose(callback: (Result<Unit>) -> Unit) {
        releaseController()
        applicationContext?.let {
            it.stopService(Intent(it, PlaybackService::class.java))
        }
        RadioStateStore.reset()
        callback(Result.success(Unit))
    }

    override fun getState(callback: (Result<RadioPlayerStateMessage>) -> Unit) {
        callback(Result.success(RadioStateStore.snapshot()))
    }

    private fun playFromCurrentState(controller: MediaController) {
        RadioStateStore.clearError()
        if (controller.mediaItemCount > 0 && controller.playbackState == Player.STATE_IDLE) {
            controller.prepare()
        }
        controller.play()
    }

    private fun runIfInitialized(
        method: String,
        callback: (Result<Unit>) -> Unit,
        block: (MediaController) -> Unit,
    ) {
        if (controllerFuture == null) {
            Log.w(LOG_TAG, "$method() called before initialize(); ignored")
            callback(Result.success(Unit))
            return
        }
        runOnController(callback) {
            block(it)
            Result.success(Unit)
        }
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
        OnStateChangedStreamHandler.register(
            binding.binaryMessenger,
            object : OnStateChangedStreamHandler() {
                override fun onListen(arguments: Any?, sink: PigeonEventSink<RadioPlayerStateMessage>) {
                    RadioStateStore.attachSink(sink)
                }
                override fun onCancel(arguments: Any?) {
                    RadioStateStore.detachSink()
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
