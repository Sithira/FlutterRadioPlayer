package me.sithiramunasinghe.flutter.flutter_radio_player.core

import com.google.android.exoplayer2.C
import com.google.android.exoplayer2.LoadControl
import com.google.android.exoplayer2.Renderer
import com.google.android.exoplayer2.source.TrackGroupArray
import com.google.android.exoplayer2.trackselection.TrackSelectionArray
import com.google.android.exoplayer2.upstream.Allocator
import com.google.android.exoplayer2.upstream.DefaultAllocator
import com.google.android.exoplayer2.util.Assertions
import com.google.android.exoplayer2.util.Log
import com.google.android.exoplayer2.util.Util
//
//class CustomLoadControl {
//}


/**
 * The default [LoadControl] implementation.
 */
class CustomLoadControl protected constructor(
        allocator: DefaultAllocator,
        minBufferMs: Int,
        maxBufferMs: Int,
        bufferForPlaybackMs: Int,
        bufferForPlaybackAfterRebufferMs: Int,
        targetBufferBytes: Int,
        prioritizeTimeOverSizeThresholds: Boolean,
        backBufferDurationMs: Int,
        retainBackBufferFromKeyframe: Boolean) : LoadControl {
    /** Builder for [CustomLoadControl].  */
    class Builder {
        private var allocator: DefaultAllocator? = null
        private var minBufferMs: Int
        private var maxBufferMs: Int
        private var bufferForPlaybackMs: Int
        private var bufferForPlaybackAfterRebufferMs: Int
        private var targetBufferBytes: Int
        private var prioritizeTimeOverSizeThresholds: Boolean
        private var backBufferDurationMs: Int
        private var retainBackBufferFromKeyframe: Boolean
        private var buildCalled = false

        /**
         * Sets the [DefaultAllocator] used by the loader.
         *
         * @param allocator The [DefaultAllocator].
         * @return This builder, for convenience.
         * @throws IllegalStateException If [.build] has already been called.
         */
        fun setAllocator(allocator: DefaultAllocator?): Builder {
            Assertions.checkState(!buildCalled)
            this.allocator = allocator
            return this
        }

        /**
         * Sets the buffer duration parameters.
         *
         * @param minBufferMs The minimum duration of media that the player will attempt to ensure is
         * buffered at all times, in milliseconds.
         * @param maxBufferMs The maximum duration of media that the player will attempt to buffer, in
         * milliseconds.
         * @param bufferForPlaybackMs The duration of media that must be buffered for playback to start
         * or resume following a user action such as a seek, in milliseconds.
         * @param bufferForPlaybackAfterRebufferMs The default duration of media that must be buffered
         * for playback to resume after a rebuffer, in milliseconds. A rebuffer is defined to be
         * caused by buffer depletion rather than a user action.
         * @return This builder, for convenience.
         * @throws IllegalStateException If [.build] has already been called.
         */
        fun setBufferDurationsMs(
                minBufferMs: Int,
                maxBufferMs: Int,
                bufferForPlaybackMs: Int,
                bufferForPlaybackAfterRebufferMs: Int): Builder {
            Assertions.checkState(!buildCalled)
            assertGreaterOrEqual(bufferForPlaybackMs, 0, "bufferForPlaybackMs", "0")
            assertGreaterOrEqual(
                    bufferForPlaybackAfterRebufferMs, 0, "bufferForPlaybackAfterRebufferMs", "0")
            assertGreaterOrEqual(minBufferMs, bufferForPlaybackMs, "minBufferMs", "bufferForPlaybackMs")
            assertGreaterOrEqual(
                    minBufferMs,
                    bufferForPlaybackAfterRebufferMs,
                    "minBufferMs",
                    "bufferForPlaybackAfterRebufferMs")
            assertGreaterOrEqual(maxBufferMs, minBufferMs, "maxBufferMs", "minBufferMs")
            this.minBufferMs = minBufferMs
            this.maxBufferMs = maxBufferMs
            this.bufferForPlaybackMs = bufferForPlaybackMs
            this.bufferForPlaybackAfterRebufferMs = bufferForPlaybackAfterRebufferMs
            return this
        }

        /**
         * Sets the target buffer size in bytes. If set to [C.LENGTH_UNSET], the target buffer
         * size will be calculated based on the selected tracks.
         *
         * @param targetBufferBytes The target buffer size in bytes.
         * @return This builder, for convenience.
         * @throws IllegalStateException If [.build] has already been called.
         */
        fun setTargetBufferBytes(targetBufferBytes: Int): Builder {
            Assertions.checkState(!buildCalled)
            this.targetBufferBytes = targetBufferBytes
            return this
        }

        /**
         * Sets whether the load control prioritizes buffer time constraints over buffer size
         * constraints.
         *
         * @param prioritizeTimeOverSizeThresholds Whether the load control prioritizes buffer time
         * constraints over buffer size constraints.
         * @return This builder, for convenience.
         * @throws IllegalStateException If [.build] has already been called.
         */
        fun setPrioritizeTimeOverSizeThresholds(prioritizeTimeOverSizeThresholds: Boolean): Builder {
            Assertions.checkState(!buildCalled)
            this.prioritizeTimeOverSizeThresholds = prioritizeTimeOverSizeThresholds
            return this
        }

        /**
         * Sets the back buffer duration, and whether the back buffer is retained from the previous
         * keyframe.
         *
         * @param backBufferDurationMs The back buffer duration in milliseconds.
         * @param retainBackBufferFromKeyframe Whether the back buffer is retained from the previous
         * keyframe.
         * @return This builder, for convenience.
         * @throws IllegalStateException If [.build] has already been called.
         */
        fun setBackBuffer(backBufferDurationMs: Int, retainBackBufferFromKeyframe: Boolean): Builder {
            Assertions.checkState(!buildCalled)
            assertGreaterOrEqual(backBufferDurationMs, 0, "backBufferDurationMs", "0")
            this.backBufferDurationMs = backBufferDurationMs
            this.retainBackBufferFromKeyframe = retainBackBufferFromKeyframe
            return this
        }

        @Deprecated("use {@link #build} instead. ")
        fun createCustomLoadControl(): CustomLoadControl {
            return build()
        }

        /** Creates a [CustomLoadControl].  */
        fun build(): CustomLoadControl {
            Assertions.checkState(!buildCalled)
            buildCalled = true
            if (allocator == null) {
                allocator = DefaultAllocator( /* trimOnReset= */true, C.DEFAULT_BUFFER_SEGMENT_SIZE)
            }
            return CustomLoadControl(
                    allocator!!,
                    minBufferMs,
                    maxBufferMs,
                    bufferForPlaybackMs,
                    bufferForPlaybackAfterRebufferMs,
                    targetBufferBytes,
                    prioritizeTimeOverSizeThresholds,
                    backBufferDurationMs,
                    retainBackBufferFromKeyframe)
        }

        /** Constructs a new instance.  */
        init {
            minBufferMs = DEFAULT_MIN_BUFFER_MS
            maxBufferMs = DEFAULT_MAX_BUFFER_MS
            bufferForPlaybackMs = DEFAULT_BUFFER_FOR_PLAYBACK_MS
            bufferForPlaybackAfterRebufferMs = DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS
            targetBufferBytes = DEFAULT_TARGET_BUFFER_BYTES
            prioritizeTimeOverSizeThresholds = DEFAULT_PRIORITIZE_TIME_OVER_SIZE_THRESHOLDS
            backBufferDurationMs = DEFAULT_BACK_BUFFER_DURATION_MS
            retainBackBufferFromKeyframe = DEFAULT_RETAIN_BACK_BUFFER_FROM_KEYFRAME
        }
    }

    private val allocator: DefaultAllocator
    private val minBufferUs: Long
    private val maxBufferUs: Long
    private val bufferForPlaybackUs: Long
    private val bufferForPlaybackAfterRebufferUs: Long
    private val targetBufferBytesOverwrite: Int
    private val prioritizeTimeOverSizeThresholds: Boolean
    private val backBufferDurationUs: Long
    private val retainBackBufferFromKeyframe: Boolean
    private var targetBufferBytes: Int
    private var isBuffering = false

    /** Constructs a new instance, using the `DEFAULT_*` constants defined in this class.  */
    constructor() : this(DefaultAllocator(true, C.DEFAULT_BUFFER_SEGMENT_SIZE)) {}

    @Deprecated("Use {@link Builder} instead. ")
    constructor(allocator: DefaultAllocator) : this(
            allocator,
            DEFAULT_MIN_BUFFER_MS,
            DEFAULT_MAX_BUFFER_MS,
            DEFAULT_BUFFER_FOR_PLAYBACK_MS,
            DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS,
            DEFAULT_TARGET_BUFFER_BYTES,
            DEFAULT_PRIORITIZE_TIME_OVER_SIZE_THRESHOLDS,
            DEFAULT_BACK_BUFFER_DURATION_MS,
            DEFAULT_RETAIN_BACK_BUFFER_FROM_KEYFRAME) {
    }

    @Deprecated("Use {@link Builder} instead. ")
    constructor(
            allocator: DefaultAllocator,
            minBufferMs: Int,
            maxBufferMs: Int,
            bufferForPlaybackMs: Int,
            bufferForPlaybackAfterRebufferMs: Int,
            targetBufferBytes: Int,
            prioritizeTimeOverSizeThresholds: Boolean) : this(
            allocator,
            minBufferMs,
            maxBufferMs,
            bufferForPlaybackMs,
            bufferForPlaybackAfterRebufferMs,
            targetBufferBytes,
            prioritizeTimeOverSizeThresholds,
            DEFAULT_BACK_BUFFER_DURATION_MS,
            DEFAULT_RETAIN_BACK_BUFFER_FROM_KEYFRAME) {
    }

    override fun onPrepared() {
        reset(false)
    }

    override fun onTracksSelected(renderers: Array<Renderer>, trackGroups: TrackGroupArray,
                                  trackSelections: TrackSelectionArray) {
        targetBufferBytes = if (targetBufferBytesOverwrite == C.LENGTH_UNSET) calculateTargetBufferBytes(renderers, trackSelections) else targetBufferBytesOverwrite
        allocator.setTargetBufferSize(targetBufferBytes)
    }

    override fun onStopped() {
        reset(true)
    }

    override fun onReleased() {
        reset(true)
    }

    override fun getAllocator(): Allocator {
        return allocator
    }

    override fun getBackBufferDurationUs(): Long {
        return backBufferDurationUs
    }

    override fun retainBackBufferFromKeyframe(): Boolean {
        return retainBackBufferFromKeyframe
    }

    override fun shouldContinueLoading(
            playbackPositionUs: Long, bufferedDurationUs: Long, playbackSpeed: Float): Boolean {

        val targetBufferSizeReached = allocator.totalBytesAllocated >= targetBufferBytes
        var minBufferUs = minBufferUs
        if (playbackSpeed > 1) {
            // The playback speed is faster than real time, so scale up the minimum required media
            // duration to keep enough media buffered for a playout duration of minBufferUs.
            val mediaDurationMinBufferUs = Util.getMediaDurationForPlayoutDuration(minBufferUs, playbackSpeed)
            minBufferUs = Math.min(mediaDurationMinBufferUs, maxBufferUs)
        }

        // Prevent playback from getting stuck if minBufferUs is too small.
        minBufferUs = Math.max(minBufferUs, 500000)
        if (bufferedDurationUs < minBufferUs) {
            isBuffering = prioritizeTimeOverSizeThresholds || !targetBufferSizeReached
            if (!isBuffering && bufferedDurationUs < 500000) {
                Log.w(
                        "CustomLoadControl",
                        "Target buffer size reached with less than 500ms of buffered media data.")
            }
        } else if (bufferedDurationUs >= maxBufferUs || targetBufferSizeReached) {
            isBuffering = false
        } // Else don't change the buffering state
        Log.d("CustomLoadControl", "bufferedDurationUs:$bufferedDurationUs," +
                " playbackPositionUs:$playbackPositionUs," +
                " maxBufferUs:$maxBufferUs," +
                " isBuffering:$isBuffering," +
                " targetBufferSizeReached:$targetBufferSizeReached")
        return isBuffering
    }

    override fun shouldStartPlayback(
            bufferedDurationUs: Long, playbackSpeed: Float, rebuffering: Boolean): Boolean {
        var bufferedDurationUs = bufferedDurationUs
        bufferedDurationUs = Util.getPlayoutDurationForMediaDuration(bufferedDurationUs, playbackSpeed)
        val minBufferDurationUs = if (rebuffering) bufferForPlaybackAfterRebufferUs else bufferForPlaybackUs
        val shouldStart = minBufferDurationUs <= 0 || bufferedDurationUs >= minBufferDurationUs || (!prioritizeTimeOverSizeThresholds
                && allocator.totalBytesAllocated >= targetBufferBytes)
        Log.d("CustomLoadControl:shouldStartPlayback", "bufferedDurationUs:$bufferedDurationUs, shouldStart:$shouldStart")

        return  shouldStart
    }

    /**
     * Calculate target buffer size in bytes based on the selected tracks. The player will try not to
     * exceed this target buffer. Only used when `targetBufferBytes` is [C.LENGTH_UNSET].
     *
     * @param renderers The renderers for which the track were selected.
     * @param trackSelectionArray The selected tracks.
     * @return The target buffer size in bytes.
     */
    protected fun calculateTargetBufferBytes(
            renderers: Array<Renderer>, trackSelectionArray: TrackSelectionArray): Int {
        var targetBufferSize = 0
        for (i in renderers.indices) {
            if (trackSelectionArray[i] != null) {
                targetBufferSize += getDefaultBufferSize(renderers[i].trackType)
            }
        }
        Log.d("calculateTargetBufferBytes","${Math.max(DEFAULT_MIN_BUFFER_SIZE, targetBufferSize)}")
        return Math.max(DEFAULT_MIN_BUFFER_SIZE, targetBufferSize)
    }

    private fun reset(resetAllocator: Boolean) {
        targetBufferBytes = if (targetBufferBytesOverwrite == C.LENGTH_UNSET) DEFAULT_MIN_BUFFER_SIZE else targetBufferBytesOverwrite
        isBuffering = false
        if (resetAllocator) {
            allocator.reset()
        }
    }

    companion object {
        /**
         * The default minimum duration of media that the player will attempt to ensure is buffered at all
         * times, in milliseconds.
         */
        const val DEFAULT_MIN_BUFFER_MS = 50000

        /**
         * The default maximum duration of media that the player will attempt to buffer, in milliseconds.
         */
        const val DEFAULT_MAX_BUFFER_MS = 50000

        /**
         * The default duration of media that must be buffered for playback to start or resume following a
         * user action such as a seek, in milliseconds.
         */
        const val DEFAULT_BUFFER_FOR_PLAYBACK_MS = 2500

        /**
         * The default duration of media that must be buffered for playback to resume after a rebuffer, in
         * milliseconds. A rebuffer is defined to be caused by buffer depletion rather than a user action.
         */
        const val DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS = 5000

        /**
         * The default target buffer size in bytes. The value ([C.LENGTH_UNSET]) means that the load
         * control will calculate the target buffer size based on the selected tracks.
         */
        const val DEFAULT_TARGET_BUFFER_BYTES = C.LENGTH_UNSET

        /** The default prioritization of buffer time constraints over size constraints.  */
        const val DEFAULT_PRIORITIZE_TIME_OVER_SIZE_THRESHOLDS = false

        /** The default back buffer duration in milliseconds.  */
        const val DEFAULT_BACK_BUFFER_DURATION_MS = 0

        /** The default for whether the back buffer is retained from the previous keyframe.  */
        const val DEFAULT_RETAIN_BACK_BUFFER_FROM_KEYFRAME = false

        /** A default size in bytes for a video buffer.  */
        const val DEFAULT_VIDEO_BUFFER_SIZE = 2000 * C.DEFAULT_BUFFER_SEGMENT_SIZE

        /** A default size in bytes for an audio buffer.  */
        const val DEFAULT_AUDIO_BUFFER_SIZE = 200 * C.DEFAULT_BUFFER_SEGMENT_SIZE

        /** A default size in bytes for a text buffer.  */
        const val DEFAULT_TEXT_BUFFER_SIZE = 2 * C.DEFAULT_BUFFER_SEGMENT_SIZE

        /** A default size in bytes for a metadata buffer.  */
        const val DEFAULT_METADATA_BUFFER_SIZE = 2 * C.DEFAULT_BUFFER_SEGMENT_SIZE

        /** A default size in bytes for a camera motion buffer.  */
        const val DEFAULT_CAMERA_MOTION_BUFFER_SIZE = 2 * C.DEFAULT_BUFFER_SEGMENT_SIZE

        /** A default size in bytes for a muxed buffer (e.g. containing video, audio and text).  */
        const val DEFAULT_MUXED_BUFFER_SIZE = DEFAULT_VIDEO_BUFFER_SIZE + DEFAULT_AUDIO_BUFFER_SIZE + DEFAULT_TEXT_BUFFER_SIZE

        /**
         * The buffer size in bytes that will be used as a minimum target buffer in all cases. This is
         * also the default target buffer before tracks are selected.
         */
        const val DEFAULT_MIN_BUFFER_SIZE = 200 * C.DEFAULT_BUFFER_SEGMENT_SIZE
        private fun getDefaultBufferSize(trackType: Int): Int {
            return when (trackType) {
                C.TRACK_TYPE_DEFAULT -> DEFAULT_MUXED_BUFFER_SIZE
                C.TRACK_TYPE_AUDIO -> DEFAULT_AUDIO_BUFFER_SIZE
                C.TRACK_TYPE_VIDEO -> DEFAULT_VIDEO_BUFFER_SIZE
                C.TRACK_TYPE_TEXT -> DEFAULT_TEXT_BUFFER_SIZE
                C.TRACK_TYPE_METADATA -> DEFAULT_METADATA_BUFFER_SIZE
                C.TRACK_TYPE_CAMERA_MOTION -> DEFAULT_CAMERA_MOTION_BUFFER_SIZE
                C.TRACK_TYPE_NONE -> 0
                else -> throw IllegalArgumentException()
            }
        }

        private fun assertGreaterOrEqual(value1: Int, value2: Int, name1: String, name2: String) {
            Assertions.checkArgument(value1 >= value2, "$name1 cannot be less than $name2")
        }
    }

    init {
        assertGreaterOrEqual(bufferForPlaybackMs, 0, "bufferForPlaybackMs", "0")
        assertGreaterOrEqual(
                bufferForPlaybackAfterRebufferMs, 0, "bufferForPlaybackAfterRebufferMs", "0")
        assertGreaterOrEqual(minBufferMs, bufferForPlaybackMs, "minBufferMs", "bufferForPlaybackMs")
        assertGreaterOrEqual(
                minBufferMs,
                bufferForPlaybackAfterRebufferMs,
                "minBufferMs",
                "bufferForPlaybackAfterRebufferMs")
        assertGreaterOrEqual(maxBufferMs, minBufferMs, "maxBufferMs", "minBufferMs")
        assertGreaterOrEqual(backBufferDurationMs, 0, "backBufferDurationMs", "0")
        this.allocator = allocator
        minBufferUs = C.msToUs(minBufferMs.toLong())
        maxBufferUs = C.msToUs(maxBufferMs.toLong())
        bufferForPlaybackUs = C.msToUs(bufferForPlaybackMs.toLong())
        bufferForPlaybackAfterRebufferUs = C.msToUs(bufferForPlaybackAfterRebufferMs.toLong())
        targetBufferBytesOverwrite = targetBufferBytes
        this.targetBufferBytes = if (targetBufferBytesOverwrite != C.LENGTH_UNSET) targetBufferBytesOverwrite else DEFAULT_MIN_BUFFER_SIZE
        this.prioritizeTimeOverSizeThresholds = prioritizeTimeOverSizeThresholds
        backBufferDurationUs = C.msToUs(backBufferDurationMs.toLong())
        this.retainBackBufferFromKeyframe = retainBackBufferFromKeyframe
    }
}