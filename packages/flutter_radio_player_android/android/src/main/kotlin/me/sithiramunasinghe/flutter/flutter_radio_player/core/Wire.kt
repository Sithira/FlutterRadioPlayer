package me.sithiramunasinghe.flutter.flutter_radio_player.core

import android.os.Bundle
import androidx.core.os.BundleCompat
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerError
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerErrorCode
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioPlayerOptionsInfo
import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.RadioSourceInfo

/** A source in the service's list, keyed by an opaque media id that never carries the url. */
internal class Entry(val mediaId: String, val source: RadioSourceInfo)

/** A value that belongs to one media item, ordered by [seq] across the service's lifetime. */
internal class Tagged<T>(val mediaId: String, val value: T, val seq: Long)

/** What the service pushes to same-package controllers as session extras. */
internal class ServiceState(
    val revision: Long,
    val entries: List<Entry>,
    val options: RadioPlayerOptionsInfo,
    val nowPlaying: Tagged<String>?,
    val error: Tagged<RadioPlayerError>?,
)

internal object Wire {
    const val SET_SOURCES = "frp.setSources"
    const val SET_OPTIONS = "frp.setOptions"

    private const val SOURCES = "sources"
    private const val INITIAL_INDEX = "initialIndex"
    private const val AUTO_PLAY = "autoPlay"
    private const val OPTIONS = "options"
    private const val REVISION = "revision"
    private const val ENTRIES = "entries"
    private const val NOW_PLAYING = "nowPlaying"
    private const val ERROR = "error"

    fun setSourcesArgs(sources: List<RadioSourceInfo>, initialIndex: Int?, autoPlay: Boolean): Bundle =
        Bundle().apply {
            putParcelableArrayList(SOURCES, ArrayList(sources.map(::sourceBundle)))
            initialIndex?.let { putInt(INITIAL_INDEX, it) }
            putBoolean(AUTO_PLAY, autoPlay)
        }

    fun sources(args: Bundle): List<RadioSourceInfo> = bundles(args, SOURCES).map(::source)

    fun initialIndex(args: Bundle): Int? = if (args.containsKey(INITIAL_INDEX)) args.getInt(INITIAL_INDEX) else null

    fun autoPlay(args: Bundle): Boolean = args.getBoolean(AUTO_PLAY)

    fun optionsArgs(options: RadioPlayerOptionsInfo): Bundle = Bundle().apply { putBundle(OPTIONS, optionsBundle(options)) }

    fun options(args: Bundle): RadioPlayerOptionsInfo = args.getBundle(OPTIONS)?.let(::decodeOptions) ?: RadioPlayerOptionsInfo()

    fun revisionResult(revision: Long): Bundle = Bundle().apply { putLong(REVISION, revision) }

    fun revision(bundle: Bundle): Long = bundle.getLong(REVISION, -1)

    fun stateBundle(state: ServiceState): Bundle = Bundle().apply {
        putLong(REVISION, state.revision)
        putParcelableArrayList(
            ENTRIES,
            ArrayList(state.entries.map { Bundle().apply { putString("mediaId", it.mediaId); putBundle("source", sourceBundle(it.source)) } }),
        )
        putBundle(OPTIONS, optionsBundle(state.options))
        state.nowPlaying?.let { putBundle(NOW_PLAYING, tagged(it) { putString("title", it) }) }
        state.error?.let { error ->
            putBundle(ERROR, tagged(error) { putString("code", it.code.name); putString("message", it.message) })
        }
    }

    fun serviceState(bundle: Bundle): ServiceState? {
        if (!bundle.containsKey(REVISION)) return null
        return ServiceState(
            revision = bundle.getLong(REVISION),
            entries = bundles(bundle, ENTRIES).map { Entry(it.getString("mediaId")!!, source(it.getBundle("source")!!)) },
            options = bundle.getBundle(OPTIONS)?.let(::decodeOptions) ?: RadioPlayerOptionsInfo(),
            nowPlaying = bundle.getBundle(NOW_PLAYING)?.let { untagged(it) { b -> b.getString("title")!! } },
            error = bundle.getBundle(ERROR)?.let {
                untagged(it) { b -> RadioPlayerError(RadioPlayerErrorCode.valueOf(b.getString("code")!!), b.getString("message")!!) }
            },
        )
    }

    private fun sourceBundle(source: RadioSourceInfo): Bundle = Bundle().apply {
        putString("id", source.id)
        putString("url", source.url)
        putString("title", source.title)
        putString("artwork", source.artwork)
        putString("artworkUri", source.artworkUri)
        putBundle("headers", Bundle().apply { source.headers.forEach { (k, v) -> putString(k, v) } })
    }

    private fun source(bundle: Bundle): RadioSourceInfo {
        val headers = bundle.getBundle("headers")
        return RadioSourceInfo(
            url = bundle.getString("url")!!,
            id = bundle.getString("id"),
            title = bundle.getString("title"),
            artwork = bundle.getString("artwork"),
            headers = headers?.keySet()?.associateWith { headers.getString(it)!! }.orEmpty(),
        ).also { it.artworkUri = bundle.getString("artworkUri") }
    }

    private fun optionsBundle(options: RadioPlayerOptionsInfo): Bundle = Bundle().apply {
        putBoolean("wrapAround", options.wrapAround)
        putLong("giveUpAfterMillis", options.reconnectGiveUpAfterMillis)
        putBoolean("stopOnTaskRemoved", options.stopOnTaskRemoved)
        putString("notificationIcon", options.notificationIcon)
    }

    private fun decodeOptions(bundle: Bundle): RadioPlayerOptionsInfo = RadioPlayerOptionsInfo(
        wrapAround = bundle.getBoolean("wrapAround", true),
        reconnectGiveUpAfterMillis = bundle.getLong("giveUpAfterMillis"),
        stopOnTaskRemoved = bundle.getBoolean("stopOnTaskRemoved", true),
        notificationIcon = bundle.getString("notificationIcon"),
    )

    private fun <T> tagged(value: Tagged<T>, write: Bundle.(T) -> Unit): Bundle = Bundle().apply {
        putString("mediaId", value.mediaId)
        putLong("seq", value.seq)
        write(value.value)
    }

    private fun <T> untagged(bundle: Bundle, read: (Bundle) -> T): Tagged<T> =
        Tagged(bundle.getString("mediaId")!!, read(bundle), bundle.getLong("seq"))

    private fun bundles(bundle: Bundle, key: String): List<Bundle> =
        BundleCompat.getParcelableArrayList(bundle, key, Bundle::class.java).orEmpty()
}
