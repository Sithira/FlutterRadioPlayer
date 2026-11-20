package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import android.os.Process
import androidx.annotation.OptIn
import androidx.core.net.toUri
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Metadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.extractor.metadata.icy.IcyInfo
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaSession.ControllerInfo
import androidx.media3.session.SessionResult
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerError
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerErrorCode
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerOptionsInfo
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioSourceInfo
import me.sithiramunasinghe.flutter.flutter_radio_player.core.logic.selectSource
import java.util.concurrent.CopyOnWriteArraySet

@OptIn(UnstableApi::class)
public class PlaybackService : MediaLibraryService() {

    internal companion object {
        @Volatile
        var isRunning: Boolean = false
            private set

        private val runningListeners = CopyOnWriteArraySet<() -> Unit>()

        fun addRunningListener(listener: () -> Unit) {
            runningListeners += listener
        }

        fun removeRunningListener(listener: () -> Unit) {
            runningListeners -= listener
        }
    }

    private lateinit var exoPlayer: ExoPlayer
    private lateinit var policyPlayer: RadioPolicyPlayer
    private lateinit var sessionCallback: RadioSessionCallback
    private var session: MediaLibrarySession? = null

    private var entries: List<Entry> = emptyList()
    private var options = RadioPlayerOptionsInfo()
    private var revision = 0L
    private var nextMediaId = 0L
    private var seq = 0L
    private var nowPlaying: Tagged<String>? = null
    private var error: Tagged<RadioPlayerError>? = null
    private var currentMediaId: String? = null

    override fun onCreate() {
        super.onCreate()
        exoPlayer = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .setHandleAudioBecomingNoisy(true)
            .build()
        exoPlayer.addListener(playerListener)

        policyPlayer = RadioPolicyPlayer(exoPlayer)
        sessionCallback = RadioSessionCallback(packageName, Process.myUid(), sessionHost)
        val builder = MediaLibrarySession.Builder(this, policyPlayer, sessionCallback)
        packageManager.getLaunchIntentForPackage(packageName)?.let { launchIntent ->
            builder.setSessionActivity(
                PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
            )
        }
        session = builder.build()

        val notificationProvider = DefaultMediaNotificationProvider(this)
        notificationProvider.setSmallIcon(packageManager.getApplicationInfo(packageName, 0).icon)
        setMediaNotificationProvider(notificationProvider)

        isRunning = true
        runningListeners.forEach { it() }
    }

    override fun onGetSession(controllerInfo: ControllerInfo): MediaLibrarySession? = session

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (options.stopOnTaskRemoved) pauseAllPlayersAndStopSelf()
    }

    override fun onDestroy() {
        isRunning = false
        exoPlayer.removeListener(playerListener)
        session?.run {
            player.release()
            release()
        }
        session = null
        super.onDestroy()
    }

    private val sessionHost = object : RadioSessionCallback.Host {
        override fun setSources(args: Bundle): SessionResult =
            this@PlaybackService.setSources(Wire.sources(args), Wire.initialIndex(args), Wire.autoPlay(args))

        override fun setOptions(args: Bundle): SessionResult {
            options = Wire.options(args)
            policyPlayer.wrapAround = options.wrapAround
            return published()
        }

        override fun stateBundle(): Bundle = this@PlaybackService.stateBundle()
    }

    private fun setSources(sources: List<RadioSourceInfo>, initialIndex: Int?, autoPlay: Boolean): SessionResult {
        if (initialIndex != null && initialIndex !in sources.indices) {
            return SessionResult(SessionResult.RESULT_ERROR_BAD_VALUE)
        }
        val oldIndex = if (exoPlayer.mediaItemCount > 0) exoPlayer.currentMediaItemIndex else null
        val selection = selectSource(
            old = entries.map { it.source },
            oldIndex = oldIndex,
            new = sources,
            initialIndex = initialIndex,
            id = RadioSourceInfo::id,
            sameStream = RadioSourceInfo::sameStream,
        )
        val index = selection.index
        when {
            index == null -> {
                exoPlayer.pause()
                exoPlayer.stop()
                exoPlayer.clearMediaItems()
                entries = emptyList()
                clearTagged()
            }
            selection.keepStream -> keepCurrent(sources, oldIndex!!, index)
            else -> {
                exoPlayer.pause()
                exoPlayer.stop()
                entries = sources.map { Entry(newMediaId(), it) }
                exoPlayer.setMediaItems(entries.map(::mediaItem), index, C.TIME_UNSET)
                clearTagged()
            }
        }
        if (autoPlay && entries.isNotEmpty()) {
            if (exoPlayer.playbackState == Player.STATE_IDLE) exoPlayer.prepare()
            exoPlayer.play()
        }
        return published()
    }

    private fun keepCurrent(sources: List<RadioSourceInfo>, current: Int, index: Int) {
        val kept = entries[current]
        val newEntries = sources.mapIndexed { i, source ->
            if (i == index) Entry(kept.mediaId, source) else Entry(newMediaId(), source)
        }
        if (current + 1 < exoPlayer.mediaItemCount) exoPlayer.removeMediaItems(current + 1, exoPlayer.mediaItemCount)
        if (current > 0) exoPlayer.removeMediaItems(0, current)
        exoPlayer.addMediaItems(0, newEntries.subList(0, index).map(::mediaItem))
        exoPlayer.addMediaItems(newEntries.subList(index + 1, newEntries.size).map(::mediaItem))
        val newCurrent = newEntries[index].source
        if (newCurrent.title != kept.source.title || newCurrent.artwork != kept.source.artwork) {
            exoPlayer.replaceMediaItem(index, mediaItem(newEntries[index]))
        }
        entries = newEntries
    }

    private fun mediaItem(entry: Entry): MediaItem {
        val source = entry.source
        val artwork = source.artworkUri ?: source.artwork?.takeIf { it.startsWith("http://") || it.startsWith("https://") }
        return MediaItem.Builder()
            .setMediaId(entry.mediaId)
            .setUri(source.url)
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(source.title)
                    .setArtworkUri(artwork?.toUri())
                    .build(),
            )
            .build()
    }

    private fun newMediaId(): String = "frp-${nextMediaId++}"

    private fun clearTagged() {
        nowPlaying = null
        error = null
    }

    private fun published(): SessionResult {
        revision++
        publish()
        return SessionResult(SessionResult.RESULT_SUCCESS, Wire.revisionResult(revision))
    }

    private fun stateBundle(): Bundle =
        Wire.stateBundle(ServiceState(revision, entries, options, nowPlaying, error))

    private fun publish() {
        val session = session ?: return
        val extras = stateBundle()
        session.connectedControllers.filter(sessionCallback::isTrusted).forEach { session.setSessionExtras(it, extras) }
    }

    private val playerListener = object : Player.Listener {
        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            val mediaId = mediaItem?.mediaId
            if (mediaId == currentMediaId) return
            currentMediaId = mediaId
            if (nowPlaying != null || error != null) {
                clearTagged()
                publish()
            }
        }

        override fun onMetadata(metadata: Metadata) {
            val mediaId = currentMediaId ?: return
            for (i in 0 until metadata.length()) {
                val title = (metadata[i] as? IcyInfo)?.title
                if (!title.isNullOrEmpty()) {
                    nowPlaying = Tagged(mediaId, title, ++seq)
                    publish()
                    return
                }
            }
        }

        override fun onPlayerError(playbackError: PlaybackException) {
            val mediaId = currentMediaId ?: return
            error = Tagged(mediaId, RadioPlayerError(errorCodeOf(playbackError), messageOf(playbackError)), ++seq)
            publish()
        }

        override fun onPlaybackStateChanged(playbackState: Int) {
            when {
                playbackState == Player.STATE_IDLE && exoPlayer.playerError == null && nowPlaying != null -> {
                    nowPlaying = null
                    publish()
                }
                playbackState != Player.STATE_IDLE && error != null -> {
                    error = null
                    publish()
                }
            }
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            if (error != null) {
                error = null
                publish()
            }
        }
    }

    private fun errorCodeOf(error: PlaybackException): RadioPlayerErrorCode = when (error.errorCode) {
        PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED -> RadioPlayerErrorCode.NETWORK
        PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT -> RadioPlayerErrorCode.TIMEOUT
        PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS -> RadioPlayerErrorCode.HTTP_STATUS
        PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED,
        PlaybackException.ERROR_CODE_PARSING_CONTAINER_MALFORMED,
        PlaybackException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED -> RadioPlayerErrorCode.UNSUPPORTED_FORMAT
        else -> RadioPlayerErrorCode.UNKNOWN
    }

    private fun messageOf(error: PlaybackException): String =
        error.message?.takeIf { it.isNotBlank() }?.let { "${error.errorCodeName}: $it" } ?: error.errorCodeName
}
