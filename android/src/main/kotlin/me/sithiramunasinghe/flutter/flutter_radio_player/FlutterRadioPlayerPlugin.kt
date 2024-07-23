package me.sithiramunasinghe.flutter.flutter_radio_player

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.AssetManager
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.MoreExecutors
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.serialization.json.Json
import me.sithiramunasinghe.flutter.flutter_radio_player.core.EventChannelSink
import me.sithiramunasinghe.flutter.flutter_radio_player.core.PlaybackService
import me.sithiramunasinghe.flutter.flutter_radio_player.data.FlutterRadioPlayerSource
import java.io.InputStream

class FlutterRadioPlayerPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var mediaController: MediaController? = null
    private var isMediaControllerAvailable = false
    private val pendingCalls = mutableListOf<Pair<MethodCall, Result>>()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_radio_player")
        channel.setMethodCallHandler(this)
        applicationContext = flutterPluginBinding.applicationContext

        initEventChannels(flutterPluginBinding.binaryMessenger, EventChannelSink.getInstance())

        val token = SessionToken(
            flutterPluginBinding.applicationContext, ComponentName(
                flutterPluginBinding.applicationContext,
                PlaybackService::class.java
            )
        )

        val mediaControllerFuture = MediaController.Builder(applicationContext!!, token)
            .buildAsync()

        mediaControllerFuture.addListener({
            mediaController = mediaControllerFuture.get()
            isMediaControllerAvailable = true
            pendingCalls.forEach { (call, result) ->
                onMethodCall(call, result)
            }
        }, MoreExecutors.directExecutor())
    }

    @OptIn(UnstableApi::class)
    override fun onMethodCall(call: MethodCall, result: Result) {
        println("Media controller status = $isMediaControllerAvailable")
        if (!isMediaControllerAvailable) {
            pendingCalls.add(Pair(call, result))
            return
        }
        if (call.method == "initialize") {
            val sources = call.argument<String>("sources")
            val playWhenReady = call.argument<Boolean>("playWhenReady")
            val decodedSources: List<FlutterRadioPlayerSource> =
                Json.decodeFromString(sources!!)
            mediaController!!.volume = 0.5F
            mediaController!!.playWhenReady = playWhenReady!!
            if (decodedSources.isNotEmpty()) {
                mediaController!!.setMediaItems(decodedSources.map {
                    val mediaItemBuilder = MediaItem.Builder().setUri(it.url)
                    val mediaMeta = MediaMetadata.Builder()
                    if (it.title.isNullOrEmpty()) {
                        mediaMeta.setArtist(getAppName())
                    } else {
                        mediaMeta.setArtist(it.title)
                    }
                    if (!it.artwork.isNullOrEmpty()) {
                        if ((it.artwork!!.contains("http") || it.artwork!!.contains("https"))) {
                            mediaMeta.setArtworkUri(Uri.parse(it.artwork))
                        } else {
                            mediaMeta.setArtworkData(
                                Util.toByteArray(getBitmapFromAssets(it.artwork)!!),
                                MediaMetadata.PICTURE_TYPE_FRONT_COVER
                            )
                        }
                    }
                    mediaItemBuilder.setMediaMetadata(mediaMeta.build())
                    mediaItemBuilder.build()
                })
                mediaController!!.prepare()
            }
        } else if (call.method == "playOrPause") {
            if (mediaController!!.mediaItemCount != 0) {
                if (mediaController!!.isPlaying) {
                    mediaController!!.pause()
                    return
                }
                mediaController!!.play()
            }
        } else if (call.method == "play") {
            mediaController!!.play()
        } else if (call.method == "pause") {
            mediaController!!.pause()
        } else if (call.method == "changeVolume") {
            val volume = call.argument<Double>("volume")
            mediaController!!.volume = volume!!.toFloat()
        } else if (call.method == "getVolume") {
            result.success(mediaController!!.volume)
        } else if (call.method == "nextSource") {
            mediaController!!.seekToNextMediaItem()
        } else if (call.method == "prevSource") {
            mediaController!!.seekToPreviousMediaItem()
        } else {
            result.notImplemented()
        }

    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        mediaController!!.release()
    }

    private fun initEventChannels(
        binaryMessenger: BinaryMessenger,
        eventsChannelSink: EventChannelSink
    ) {
        val playbackEventChannel =
            EventChannel(
                binaryMessenger,
                "flutter_radio_player/playback_status"
            )

        val nowPlayingEventChannel = EventChannel(
            binaryMessenger,
            "flutter_radio_player/now_playing_info"
        )

        val playbackVolumeControl = EventChannel(
            binaryMessenger,
            "flutter_radio_player/volume_control"
        )

        eventsChannelSink.playbackEventChannel = playbackEventChannel
        eventsChannelSink.nowPlayingEventChannel = nowPlayingEventChannel
        eventsChannelSink.playbackVolumeChannel = playbackVolumeControl
    }

    /**
     * Load album artwork as an URI for from app bundle
     *
     * @param assetPath bundle resource path
     * @return InputStream of asset
     */
    private fun getBitmapFromAssets(assetPath: String?): InputStream? {
        try {
            // Initialize the FlutterLoader
            val flutterLoader = FlutterLoader()
            flutterLoader.startInitialization(applicationContext!!)
            flutterLoader.ensureInitializationComplete(applicationContext!!, null)

            // Get the asset path
            val assetLookupKey = flutterLoader.getLookupKeyForAsset(assetPath!!)

            // Access the asset manager and load the bitmap
            val assetManager: AssetManager = applicationContext!!.assets
            return assetManager.open(assetLookupKey)
//            val inputStream = assetManager.open(assetLookupKey)
//            return BitmapFactory.decodeStream(inputStream).
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun getAppName(): String? {
        try {
            val packageManager: PackageManager = applicationContext!!.packageManager
            val applicationInfo =
                packageManager.getApplicationInfo(applicationContext!!.packageName, 0)
            return packageManager.getApplicationLabel(applicationInfo) as String
        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
            return null
        }
    }
}

// https://github.com/oguzhaneksi/RadioRoam/tree/master
// https://medium.com/@ouzhaneki/basic-background-playback-implementation-with-media3-mediasessionservice-4d571f15bdc2
// https://developer.android.com/media/media3/session/background-playback
// https://medium.com/@debz_exe/implementation-of-media-3-mastering-background-playback-with-mediasessionservice-and-5e130272c39e