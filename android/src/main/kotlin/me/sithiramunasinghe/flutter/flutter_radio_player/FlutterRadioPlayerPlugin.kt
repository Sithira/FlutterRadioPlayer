package me.sithiramunasinghe.flutter.flutter_radio_player

import android.app.Activity
import android.content.*
import android.os.IBinder
import androidx.annotation.NonNull
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter;
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import me.sithiramunasinghe.flutter.flutter_radio_player.core.PlayerItem
import me.sithiramunasinghe.flutter.flutter_radio_player.core.StreamingCore
import me.sithiramunasinghe.flutter.flutter_radio_player.core.enums.PlayerMethods
import java.util.logging.Logger


/** FlutterRadioPlayerPlugin */
public class FlutterRadioPlayerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var logger = Logger.getLogger(FlutterRadioPlayerPlugin::javaClass.name)
    public var activity: Activity? = null

    private lateinit var methodChannel: MethodChannel

    private var mEventSink: EventSink? = null
    private var mEventMetaDataSink: EventSink? = null

    companion object {

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val instance = FlutterRadioPlayerPlugin()
            instance.buildEngine(registrar.activeContext()!!, registrar.messenger()!!)
        }

        const val broadcastActionName = "playback_status"
        const val broadcastChangedMetaDataName = "changed_meta_data"
        const val methodChannelName = "flutter_radio_player"
        const val eventChannelName = methodChannelName + "_stream"
        const val eventChannelMetaDataName = methodChannelName + "_meta_stream"


        var isBound = false
        lateinit var applicationContext: Context
        lateinit var coreService: StreamingCore
        lateinit var serviceIntent: Intent
    }


    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        buildEngine(flutterPluginBinding.applicationContext, flutterPluginBinding.binaryMessenger)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        logger.info("Calling to method: " + call.method)
        when (call.method) {
            PlayerMethods.IS_PLAYING.value -> {
                val playStatus = isPlaying()
                logger.info("is playing service invoked with result: $playStatus")
                result.success(playStatus)
            }
            PlayerMethods.PLAY_PAUSE.value -> {
                playOrPause()
                result.success(null)
            }
            PlayerMethods.PLAY.value -> {
                logger.info("play service invoked")
                play()
                result.success(null)
            }
            PlayerMethods.PAUSE.value -> {
                logger.info("pause service invoked")
                pause()
                result.success(null)
            }
            PlayerMethods.STOP.value -> {
                logger.info("stop service invoked")
                stop()
                result.success(null)
            }
            PlayerMethods.INIT.value -> {
                logger.info("start service invoked")
                init(call)
                result.success(null)
            }
            PlayerMethods.SET_VOLUME.value -> {
                val volume = call.argument<Double>("volume")!!
                logger.info("Changing volume to: $volume")
                setVolume(volume)
                result.success(null)
            }
            PlayerMethods.SET_URL.value -> {
                logger.info("Set url invoked")
                val url = call.argument<String>("streamUrl")!!
                val playWhenReady = call.argument<String>("playWhenReady")!!
                setUrl(url, playWhenReady)
            }
            else -> result.notImplemented()
        }

    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        LocalBroadcastManager.getInstance(applicationContext).unregisterReceiver(broadcastReceiver)
        LocalBroadcastManager.getInstance(applicationContext).unregisterReceiver(broadcastReceiverMetaDetails)
    }


    private fun buildEngine(context: Context, messenger: BinaryMessenger) {

        logger.info("Building Streaming Audio Core...")
        methodChannel = MethodChannel(messenger, methodChannelName)
        methodChannel.setMethodCallHandler(this)

        logger.info("Setting Application Context")
        applicationContext = context
        serviceIntent = Intent(applicationContext, StreamingCore::class.java)

        initEventChannelStatus(messenger)
        initEventChannelMetaData(messenger)


        logger.info("Setting up broadcast receiver with event sink")
        LocalBroadcastManager.getInstance(context).registerReceiver(broadcastReceiver, IntentFilter(broadcastActionName))
        LocalBroadcastManager.getInstance(context).registerReceiver(broadcastReceiverMetaDetails, IntentFilter(broadcastChangedMetaDataName))

        logger.info("Streaming Audio Player Engine Build Complete...")

    }

    private fun initEventChannelStatus(messenger: BinaryMessenger) {
        logger.info("Setting up event channel to receive events")
        val eventChannel = EventChannel(messenger, eventChannelName)
        eventChannel.setStreamHandler(object : StreamHandler {
            override fun onListen(arguments: Any?, events: EventSink?) {
                mEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                mEventSink = null
            }
        })
    }

    private fun initEventChannelMetaData(messenger: BinaryMessenger) {
        logger.info("Setting up event channel to receive metadata")
        val eventChannel = EventChannel(messenger, eventChannelMetaDataName)
        eventChannel.setStreamHandler(object : StreamHandler {
            override fun onListen(arguments: Any?, events: EventSink?) {
                mEventMetaDataSink = events
            }

            override fun onCancel(arguments: Any?) {
                mEventMetaDataSink = null
            }
        })
    }


    private fun buildPlayerDetailsMeta(methodCall: MethodCall): PlayerItem {

        logger.info("Mapping method call to player item object")

        val url = methodCall.argument<String>("streamURL")
        val appName = methodCall.argument<String>("appName")
        val subTitle = methodCall.argument<String>("subTitle")
        val playWhenReady = methodCall.argument<String>("playWhenReady")
        val primaryColor = methodCall.argument<Long>("primaryColor")?.toInt()

        return PlayerItem(appName!!, subTitle!!, url!!, playWhenReady!!, primaryColor)
    }

    /*===========================
     *     Player methods
     *===========================
     */

    private fun init(methodCall: MethodCall) {
        logger.info("Attempting to initialize service...")
        if (!isBound) {
            logger.info("Service not bound, binding now....")
            serviceIntent = setIntentData(serviceIntent, buildPlayerDetailsMeta(methodCall))
            applicationContext.bindService(serviceIntent, serviceConnection, Context.BIND_IMPORTANT)
            applicationContext.startService(serviceIntent)
        }
    }

    private fun isPlaying(): Boolean {
        logger.info("Attempting to get playing status....")
        val playingStatus = coreService.isPlaying()
        logger.info("Payback-status: $playingStatus")
        return playingStatus
    }

    private fun playOrPause() {
        logger.info("Attempting to either play or pause...")
        if (isPlaying()) pause() else play()
    }

    private fun play() {
        if (isBound) {
            logger.info("Attempting to play music....")
            coreService.play()
        }
    }

    private fun pause() {
        logger.info("Attempting to pause music....")
        if (isBound) {
            coreService.pause()
        }
    }

    private fun stop() {
        logger.info("Attempting to stop music and unbind services....")
        isBound = false
        applicationContext.unbindService(serviceConnection)
        coreService.stop()
    }

    private fun setUrl(streamUrl: String, playWhenReady: String) {
        val playStatus: Boolean = playWhenReady == "true"
        coreService.setUrl(streamUrl, playStatus)
    }

    private fun setVolume(volume: Double) {
        if (isBound) {
            logger.info("Attempting to change volume...")
            coreService.setVolume(volume)
        }
    }

    /**
     * Build the player meta information for Stream service
     */
    private fun setIntentData(intent: Intent, playerItem: PlayerItem): Intent {
        intent.putExtra("streamUrl", playerItem.streamUrl)
        intent.putExtra("appName", playerItem.appName)
        intent.putExtra("subTitle", playerItem.subTitle)
        intent.putExtra("playWhenReady", playerItem.playWhenReady)
        intent.putExtra("primaryColor", playerItem.primaryColor)
        return intent
    }

    /**
     * Initializes the connection
     */
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceDisconnected(name: ComponentName?) {
            isBound = false
            // coreService = null
        }

        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val localBinder = binder as StreamingCore.LocalBinder
            coreService = localBinder.service
            coreService.activity = this@FlutterRadioPlayerPlugin.activity
            isBound = true
            logger.info("Service Connection Established...")
            logger.info("Service bounded...")
        }
    }

    /**
     * Broadcast receiver for the playback callbacks
     */
    private var broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {

            if (intent != null) {
                val returnStatus = intent.getStringExtra("status")
                logger.info("Received status: $returnStatus")
                mEventSink?.success(returnStatus)

            }
        }
    }

    /**
     * Broadcast receiver for changed track and metadata
     */
    private var broadcastReceiverMetaDetails = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent != null) {
                val receivedMeta = intent.getStringExtra("meta_data")
                logger.info("Received meta: $receivedMeta")
                mEventMetaDataSink?.success(receivedMeta)
            }
        }
    }

    /**
     * Get android activity instance and listen for destroy event
     */
    override fun onAttachedToActivity(p0: ActivityPluginBinding) {
        this.activity = p0.activity
        val lifecycle: Lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(p0);
        lifecycle.addObserver(object : LifecycleObserver {
            @OnLifecycleEvent(Lifecycle.Event.ON_DESTROY)
            fun onDestroy() {
                stop();
                logger.info("Stopping foregroundservice since app is about to get destroyed")
            }
        })
    }

    /**
     * These functions are unused but required by ActivityAware
     * And we need ActivityAware for onAttachedToActivity function
     */
    override fun onDetachedFromActivity() {}
    override fun onReattachedToActivityForConfigChanges(p0: ActivityPluginBinding) {}
    override fun onDetachedFromActivityForConfigChanges() {}
}
