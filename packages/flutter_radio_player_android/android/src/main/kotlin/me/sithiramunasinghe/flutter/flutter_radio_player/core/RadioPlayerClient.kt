package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.PlaybackStatus
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerCallback
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerIndexException
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerListener
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerOptionsInfo
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerSnapshot
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioSourceInfo
import java.util.concurrent.CopyOnWriteArrayList

/**
 * A handle on the shared radio player. Create one per user (a Flutter engine, a
 * screen); all of them control the same player. Call every method on the main
 * thread. Commands apply in call order; each callback gets the snapshot after its
 * command was applied.
 *
 * Adding a listener attaches to a running player but never starts one; the first
 * command does.
 */
public class RadioPlayerClient(context: Context) {
    private val context = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val mainExecutor = ContextCompat.getMainExecutor(this.context)
    private val holder = StateHolder()
    private val queue = CommandQueue()
    private val listeners = CopyOnWriteArrayList<RadioPlayerListener>()

    private var controllerFuture: ListenableFuture<MediaController>? = null
    private var controller: MediaController? = null
    private var current: RadioPlayerSnapshot = RadioPlayerSnapshot.IDLE
    private var waiter: (() -> Unit)? = null
    private var released = false

    private val onServiceStarted: () -> Unit = { main.post { if (listeners.isNotEmpty()) connect() } }

    init {
        PlaybackService.addRunningListener(onServiceStarted)
    }

    /** The latest snapshot; idle until connected to a running player. */
    public val snapshot: RadioPlayerSnapshot get() = current

    public fun addListener(listener: RadioPlayerListener) {
        listeners += listener
        if (PlaybackService.isRunning) connect()
    }

    public fun removeListener(listener: RadioPlayerListener) {
        listeners -= listener
    }

    public fun setSources(
        sources: List<RadioSourceInfo>,
        initialIndex: Int?,
        autoPlay: Boolean,
        callback: RadioPlayerCallback,
    ) {
        sendCustom(Wire.SET_SOURCES, Wire.setSourcesArgs(sources, initialIndex, autoPlay), callback)
    }

    public fun setSources(sources: List<RadioSourceInfo>, callback: RadioPlayerCallback) {
        setSources(sources, null, false, callback)
    }

    public fun setOptions(options: RadioPlayerOptionsInfo, callback: RadioPlayerCallback) {
        sendCustom(Wire.SET_OPTIONS, Wire.optionsArgs(options), callback)
    }

    public fun play(index: Int?, callback: RadioPlayerCallback) {
        command(callback) { c ->
            val count = c.mediaItemCount
            if (count == 0) return@command null
            if (index != null) {
                if (index !in 0 until count) {
                    return@command RadioPlayerIndexException("Index $index is out of range for $count sources")
                }
                if (index != c.currentMediaItemIndex) c.seekToDefaultPosition(index)
            }
            startPlaying(c)
            null
        }
    }

    public fun play(callback: RadioPlayerCallback) {
        play(null, callback)
    }

    public fun pause(callback: RadioPlayerCallback) {
        command(callback) { c ->
            if (c.mediaItemCount > 0) {
                c.pause()
                holder.clearErrorLocally()
            }
            null
        }
    }

    public fun playOrPause(callback: RadioPlayerCallback) {
        command(callback) { c ->
            if (c.mediaItemCount > 0) {
                if (c.playWhenReady && current.status != PlaybackStatus.ERROR) {
                    c.pause()
                    holder.clearErrorLocally()
                } else {
                    startPlaying(c)
                }
            }
            null
        }
    }

    public fun stop(callback: RadioPlayerCallback) {
        command(callback) { c ->
            if (c.mediaItemCount > 0) {
                c.pause()
                c.stop()
                holder.clearErrorLocally()
                holder.clearTitleLocally()
            }
            null
        }
    }

    public fun next(callback: RadioPlayerCallback) {
        command(callback) { c -> step(c, 1) }
    }

    public fun previous(callback: RadioPlayerCallback) {
        command(callback) { c -> step(c, -1) }
    }

    public fun setVolume(volume: Float, callback: RadioPlayerCallback) {
        command(callback) { c ->
            c.volume = volume.coerceIn(0f, 1f)
            null
        }
    }

    /** Detaches from the player. Playback continues; other clients are not affected. */
    public fun release() {
        if (released) return
        released = true
        PlaybackService.removeRunningListener(onServiceStarted)
        listeners.clear()
        val future = controllerFuture
        controllerFuture = null
        controller = null
        if (future != null) main.post { MediaController.releaseFuture(future) }
    }

    private fun startPlaying(c: MediaController) {
        holder.clearErrorLocally()
        if (c.playbackState == Player.STATE_IDLE) c.prepare()
        c.play()
    }

    private fun step(c: MediaController, delta: Int): RadioPlayerIndexException? {
        val count = c.mediaItemCount
        if (count < 2) return null
        var target = c.currentMediaItemIndex + delta
        if (target !in 0 until count) {
            if (holder.service?.options?.wrapAround == false) return null
            target = (target + count) % count
        }
        val wasPlaying = current.status == PlaybackStatus.PLAYING || current.status == PlaybackStatus.LOADING
        if (!wasPlaying) {
            c.pause()
            if (c.playbackState != Player.STATE_IDLE) c.stop()
        }
        c.seekToDefaultPosition(target)
        holder.clearErrorLocally()
        if (wasPlaying && c.playbackState == Player.STATE_IDLE) c.prepare()
        return null
    }

    private fun command(callback: RadioPlayerCallback, block: (MediaController) -> RadioPlayerIndexException?) {
        queue.enqueue { done ->
            val c = controller
            val error = if (c != null) block(c) else null
            finish(done, callback, error)
        }
        connect()
    }

    private fun sendCustom(action: String, args: Bundle, callback: RadioPlayerCallback) {
        queue.enqueue { done ->
            val c = controller ?: return@enqueue finish(done, callback, null)
            val future = c.sendCustomCommand(SessionCommand(action, Bundle.EMPTY), args)
            future.addListener({
                val result = runCatching { future.get() }.getOrNull()
                when {
                    result == null -> finish(done, callback, null)
                    result.resultCode == SessionResult.RESULT_ERROR_BAD_VALUE ->
                        finish(done, callback, RadioPlayerIndexException("initialIndex is out of range"))
                    else -> awaitRevision(Wire.revision(result.extras)) { finish(done, callback, null) }
                }
            }, mainExecutor)
        }
        connect()
    }

    private fun awaitRevision(revision: Long, then: () -> Unit) {
        val timeout = Runnable {
            waiter = null
            then()
        }
        val check = {
            val c = controller
            val arrived = c == null ||
                ((holder.service?.revision ?: -1) >= revision && holder.snapshot(ControllerView(c)) != null)
            if (arrived) {
                main.removeCallbacks(timeout)
                waiter = null
                then()
            }
        }
        waiter = check
        main.postDelayed(timeout, REVISION_TIMEOUT_MS)
        check()
    }

    private fun finish(done: () -> Unit, callback: RadioPlayerCallback, error: RadioPlayerIndexException?) {
        refresh()
        callback.onComplete(current, error)
        done()
    }

    private fun refresh() {
        val c = controller
        val next = if (c == null) RadioPlayerSnapshot.IDLE else holder.snapshot(ControllerView(c)) ?: return
        if (next == current) return
        current = next
        listeners.forEach { it.onSnapshot(next) }
    }

    private fun onPlayerChanged() {
        waiter?.invoke()
        if (queue.isIdle) refresh()
    }

    private fun connect() {
        if (released || controllerFuture != null) return
        val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
        val future = MediaController.Builder(context, token).setListener(controllerListener).buildAsync()
        controllerFuture = future
        future.addListener({
            val c = runCatching { future.get() }.getOrNull()
            if (released || c == null) {
                if (c == null) controllerFuture = null
                c?.release()
                runQueueWithoutController()
                return@addListener
            }
            controller = c
            c.addListener(playerListener)
            holder.service = Wire.serviceState(c.sessionExtras)
            refresh()
            queue.ready = true
        }, mainExecutor)
    }

    private fun runQueueWithoutController() {
        queue.ready = true
        queue.ready = false
    }

    private val playerListener = object : Player.Listener {
        override fun onEvents(player: Player, events: Player.Events) = onPlayerChanged()
    }

    private val controllerListener = object : MediaController.Listener {
        override fun onExtrasChanged(controller: MediaController, extras: Bundle) {
            holder.service = Wire.serviceState(extras) ?: holder.service
            onPlayerChanged()
        }

        override fun onDisconnected(controller: MediaController) {
            if (this@RadioPlayerClient.controller !== controller) return
            this@RadioPlayerClient.controller = null
            controllerFuture = null
            holder.service = null
            queue.ready = false
            waiter?.invoke()
            refresh()
        }
    }

    private class ControllerView(private val c: MediaController) : PlayerView {
        override val mediaItemCount: Int get() = c.mediaItemCount
        override fun mediaIdAt(index: Int): String = c.getMediaItemAt(index).mediaId
        override val currentIndex: Int get() = c.currentMediaItemIndex
        override val playWhenReady: Boolean get() = c.playWhenReady
        override val isPlaying: Boolean get() = c.isPlaying
        override val volume: Float get() = c.volume
    }

    private companion object {
        const val REVISION_TIMEOUT_MS = 3000L
    }
}
