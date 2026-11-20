package me.sithiramunasinghe.flutter.flutter_radio_player.core.logic

internal class Selection(val index: Int?, val keepStream: Boolean)

/**
 * `setSources` selection rules 1-3. [id] identifies a source; [sameStream] is
 * true when two sources have the same id, url and headers.
 */
internal fun <T> selectSource(
    old: List<T>,
    oldIndex: Int?,
    new: List<T>,
    initialIndex: Int?,
    id: (T) -> String,
    sameStream: (T, T) -> Boolean,
): Selection {
    if (new.isEmpty()) return Selection(null, false)
    val previous = oldIndex?.let(old::getOrNull)
    val index = initialIndex ?: followCurrent(previous, oldIndex, new, id)
    val keep = previous != null && sameStream(previous, new[index])
    return Selection(index, keep)
}

private fun <T> followCurrent(previous: T?, oldIndex: Int?, new: List<T>, id: (T) -> String): Int {
    if (previous == null || oldIndex == null) return 0
    val previousId = id(previous)
    if (oldIndex < new.size && id(new[oldIndex]) == previousId) return oldIndex
    return new.indexOfFirst { id(it) == previousId }.coerceAtLeast(0)
}
