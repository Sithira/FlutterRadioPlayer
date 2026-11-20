package me.sithiramunasinghe.flutter.flutter_radio_player

import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import me.sithiramunasinghe.flutter.flutter_radio_player.core.RadioPlayerClient
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.PlaybackStatus
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerCallback
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerErrorCode
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerListener
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerOptionsInfo
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerSnapshot
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioSourceInfo

private typealias Reply = (Result<RadioPlayerStateMessage>) -> Unit

/** One instance per Flutter engine, each with its own client of the shared player. */
class FlutterRadioPlayerPlugin : FlutterPlugin, RadioPlayerHostApi {
    private var client: RadioPlayerClient? = null
    private var stateSink: PigeonEventSink<RadioPlayerStateMessage>? = null
    private val listener = RadioPlayerListener { stateSink?.success(it.toMessage()) }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        client = RadioPlayerClient(binding.applicationContext)
        RadioPlayerHostApi.setUp(binding.binaryMessenger, this)
        OnStateChangedStreamHandler.register(binding.binaryMessenger, object : OnStateChangedStreamHandler() {
            override fun onListen(p0: Any?, sink: PigeonEventSink<RadioPlayerStateMessage>) {
                val client = client ?: return
                stateSink = sink
                client.addListener(listener)
                sink.success(client.snapshot.toMessage())
            }

            override fun onCancel(p0: Any?) {
                client?.removeListener(listener)
                stateSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RadioPlayerHostApi.setUp(binding.binaryMessenger, null)
        stateSink = null
        client?.release()
        client = null
    }

    override fun setSources(sources: List<RadioSourceMessage>, initialIndex: Long?, autoPlay: Boolean, callback: Reply) {
        withClient(callback) { it.setSources(sources.map(::sourceInfo), initialIndex?.toInt(), autoPlay, reply(callback)) }
    }

    override fun setOptions(options: RadioPlayerOptionsMessage, callback: Reply) {
        withClient(callback) {
            it.setOptions(
                RadioPlayerOptionsInfo(
                    wrapAround = options.wrapAround,
                    reconnectGiveUpAfterMillis = options.reconnectGiveUpAfterMillis,
                    stopOnTaskRemoved = options.androidStopOnTaskRemoved,
                    notificationIcon = options.androidNotificationIcon,
                ),
                reply(callback),
            )
        }
    }

    override fun play(index: Long?, callback: Reply) {
        withClient(callback) { it.play(index?.toInt(), reply(callback)) }
    }

    override fun pause(callback: Reply) = withClient(callback) { it.pause(reply(callback)) }

    override fun playOrPause(callback: Reply) = withClient(callback) { it.playOrPause(reply(callback)) }

    override fun stop(callback: Reply) = withClient(callback) { it.stop(reply(callback)) }

    override fun next(callback: Reply) = withClient(callback) { it.next(reply(callback)) }

    override fun previous(callback: Reply) = withClient(callback) { it.previous(reply(callback)) }

    override fun setVolume(volume: Double, callback: Reply) {
        withClient(callback) { it.setVolume(volume.toFloat(), reply(callback)) }
    }

    private fun withClient(callback: Reply, block: (RadioPlayerClient) -> Unit) {
        val client = client ?: return callback(Result.success(RadioPlayerSnapshot.IDLE.toMessage()))
        block(client)
    }

    private fun reply(callback: Reply) = RadioPlayerCallback { snapshot, error ->
        callback(
            if (error != null) {
                Result.failure(FlutterError("invalid_index", error.message, null))
            } else {
                Result.success(snapshot.toMessage())
            },
        )
    }

    private fun sourceInfo(message: RadioSourceMessage): RadioSourceInfo =
        RadioSourceInfo(
            url = message.url,
            id = message.id,
            title = message.title,
            artwork = message.artwork,
            headers = message.headers,
        ).also { it.artworkUri = assetUri(message.artwork) }

    private fun assetUri(artwork: String?): String? {
        if (artwork.isNullOrEmpty() || artwork.startsWith("http://") || artwork.startsWith("https://")) return null
        return "asset:///" + FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(artwork)
    }
}

private fun RadioPlayerSnapshot.toMessage() = RadioPlayerStateMessage(
    status = when (status) {
        PlaybackStatus.IDLE -> PlaybackStatusMessage.IDLE
        PlaybackStatus.LOADING -> PlaybackStatusMessage.LOADING
        PlaybackStatus.PLAYING -> PlaybackStatusMessage.PLAYING
        PlaybackStatus.PAUSED -> PlaybackStatusMessage.PAUSED
        PlaybackStatus.ERROR -> PlaybackStatusMessage.ERROR
    },
    sources = sources.map {
        RadioSourceMessage(id = it.id, url = it.url, title = it.title, artwork = it.artwork, headers = it.headers)
    },
    currentIndex = currentIndex?.toLong(),
    nowPlayingTitle = nowPlayingTitle,
    volume = volume.toDouble(),
    error = error?.let {
        RadioPlayerErrorMessage(
            code = when (it.code) {
                RadioPlayerErrorCode.INVALID_SOURCE -> RadioPlayerErrorCodeMessage.INVALID_SOURCE
                RadioPlayerErrorCode.NETWORK -> RadioPlayerErrorCodeMessage.NETWORK
                RadioPlayerErrorCode.HTTP_STATUS -> RadioPlayerErrorCodeMessage.HTTP_STATUS
                RadioPlayerErrorCode.UNSUPPORTED_FORMAT -> RadioPlayerErrorCodeMessage.UNSUPPORTED_FORMAT
                RadioPlayerErrorCode.BACKGROUND_RESTRICTED -> RadioPlayerErrorCodeMessage.BACKGROUND_RESTRICTED
                RadioPlayerErrorCode.TIMEOUT -> RadioPlayerErrorCodeMessage.TIMEOUT
                RadioPlayerErrorCode.UNKNOWN -> RadioPlayerErrorCodeMessage.UNKNOWN
            },
            message = it.message,
        )
    },
)
