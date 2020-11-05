package me.sithiramunasinghe.flutter.flutter_radio_player.core

import com.google.android.exoplayer2.C
import com.google.android.exoplayer2.ControlDispatcher
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.Timeline

/*
* Copyright (C) 2017 The Android Open Source Project
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*      http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
/** Default [ControlDispatcher].  */
class CustomControlDispatcher @JvmOverloads constructor(
        /** Returns the fast forward increment in milliseconds.  */
        @set:Deprecated("""Create a new instance instead and pass the new instance to the UI component. This
        makes sure the UI gets updated and is in sync with the new values.""") var fastForwardIncrementMs: Long = CustomControlDispatcher.Companion.DEFAULT_FAST_FORWARD_MS.toLong(),
        /** Returns the rewind increment in milliseconds.  */
        @set:Deprecated("""Create a new instance instead and pass the new instance to the UI component. This
        makes sure the UI gets updated and is in sync with the new values.""") var rewindIncrementMs: Long = CustomControlDispatcher.Companion.DEFAULT_REWIND_MS.toLong()) : ControlDispatcher {
    private val window: Timeline.Window

    override fun dispatchSetPlayWhenReady(player: Player, playWhenReady: Boolean): Boolean {
        if (!playWhenReady)
            player.playWhenReady = playWhenReady
        else{
            player.stop()
            player.prepare()
            player.playWhenReady = playWhenReady
        }
        return true
    }

    override fun dispatchSeekTo(player: Player, windowIndex: Int, positionMs: Long): Boolean {
        player.seekTo(windowIndex, positionMs)
        return true
    }

    override fun dispatchPrevious(player: Player): Boolean {
        val timeline = player.currentTimeline
        if (timeline.isEmpty || player.isPlayingAd) {
            return true
        }
        val windowIndex = player.currentWindowIndex
        timeline.getWindow(windowIndex, window)
        val previousWindowIndex = player.previousWindowIndex
        if (previousWindowIndex != C.INDEX_UNSET
                && (player.currentPosition <= CustomControlDispatcher.Companion.MAX_POSITION_FOR_SEEK_TO_PREVIOUS
                        || window.isDynamic && !window.isSeekable)) {
            player.seekTo(previousWindowIndex, C.TIME_UNSET)
        } else {
            player.seekTo(windowIndex,  /* positionMs= */0)
        }
        return true
    }

    override fun dispatchNext(player: Player): Boolean {
        val timeline = player.currentTimeline
        if (timeline.isEmpty || player.isPlayingAd) {
            return true
        }
        val windowIndex = player.currentWindowIndex
        val nextWindowIndex = player.nextWindowIndex
        if (nextWindowIndex != C.INDEX_UNSET) {
            player.seekTo(nextWindowIndex, C.TIME_UNSET)
        } else if (timeline.getWindow(windowIndex, window).isLive) {
            player.seekTo(windowIndex, C.TIME_UNSET)
        }
        return true
    }

    override fun dispatchRewind(player: Player): Boolean {
        if (isRewindEnabled && player.isCurrentWindowSeekable) {
            CustomControlDispatcher.Companion.seekToOffset(player, -rewindIncrementMs)
        }
        return true
    }

    override fun dispatchFastForward(player: Player): Boolean {
        if (isFastForwardEnabled && player.isCurrentWindowSeekable) {
            CustomControlDispatcher.Companion.seekToOffset(player, fastForwardIncrementMs)
        }
        return true
    }

    override fun dispatchSetRepeatMode(player: Player, @Player.RepeatMode repeatMode: Int): Boolean {
        player.repeatMode = repeatMode
        return true
    }

    override fun dispatchSetShuffleModeEnabled(player: Player, shuffleModeEnabled: Boolean): Boolean {
        player.shuffleModeEnabled = shuffleModeEnabled
        return true
    }

    override fun dispatchStop(player: Player, reset: Boolean): Boolean {
        player.stop(reset)
        return true
    }

    override fun isRewindEnabled(): Boolean {
        return rewindIncrementMs > 0
    }

    override fun isFastForwardEnabled(): Boolean {
        return fastForwardIncrementMs > 0
    }

    companion object {
        /** The default fast forward increment, in milliseconds.  */
        const val DEFAULT_FAST_FORWARD_MS = 15000

        /** The default rewind increment, in milliseconds.  */
        const val DEFAULT_REWIND_MS = 5000
        private const val MAX_POSITION_FOR_SEEK_TO_PREVIOUS = 3000

        // Internal methods.
        private fun seekToOffset(player: Player, offsetMs: Long) {
            var positionMs = player.currentPosition + offsetMs
            val durationMs = player.duration
            if (durationMs != C.TIME_UNSET) {
                positionMs = Math.min(positionMs, durationMs)
            }
            positionMs = Math.max(positionMs, 0)
            player.seekTo(player.currentWindowIndex, positionMs)
        }
    }
    /**
     * Creates an instance with the given increments.
     *
     * @param fastForwardIncrementMs The fast forward increment in milliseconds. A non-positive value
     * disables the fast forward operation.
     * @param rewindIncrementMs The rewind increment in milliseconds. A non-positive value disables
     * the rewind operation.
     */
    /** Creates an instance.  */
    init {
        window = Timeline.Window()
    }
}