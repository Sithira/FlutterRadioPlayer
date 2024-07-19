package me.sithiramunasinghe.flutter.flutter_radio_player

import android.content.ComponentName
import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.MoreExecutors
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import me.sithiramunasinghe.flutter.flutter_radio_player.core.PlaybackService


/** FlutterRadioPlayerPlugin */
class FlutterRadioPlayerPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var mediaController: MediaController? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_radio_player")
        channel.setMethodCallHandler(this)
        applicationContext = flutterPluginBinding.applicationContext
        val token = SessionToken(
            flutterPluginBinding.applicationContext, ComponentName(
                flutterPluginBinding.applicationContext,
                PlaybackService::class.java
            )
        )
        val factory = MediaController.Builder(applicationContext!!, token)
            .buildAsync()
        factory.addListener({
            mediaController = factory.let {
                if (it.isDone) {
                    it.get()
                } else {
                    null
                }
            }
        }, MoreExecutors.directExecutor())
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else if (call.method == "play") {
            val mediaItem: MediaItem = MediaItem.fromUri("https://radio.lotustechnologieslk.net:2020/stream/hirufmgarden")
            mediaController!!.setMediaItem(mediaItem)
            mediaController!!.prepare()
            mediaController!!.play()
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

// https://github.com/oguzhaneksi/RadioRoam/tree/master
// https://medium.com/@ouzhaneki/basic-background-playback-implementation-with-media3-mediasessionservice-4d571f15bdc2
// https://developer.android.com/media/media3/session/background-playback
// https://medium.com/@debz_exe/implementation-of-media-3-mastering-background-playback-with-mediasessionservice-and-5e130272c39e