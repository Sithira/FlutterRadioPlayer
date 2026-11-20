package me.sithiramunasinghe.flutter.flutter_radio_player.core.logic

import java.net.URI
import java.net.URISyntaxException

/** An absolute `http` or `https` URL with a host. */
internal fun isPlayableUrl(url: String): Boolean {
    val uri = try {
        URI(url)
    } catch (_: URISyntaxException) {
        return false
    }
    val scheme = uri.scheme?.lowercase() ?: return false
    if (scheme != "http" && scheme != "https") return false
    // java.net.URI leaves host null for names with '_'; the authority still has them.
    return !uri.host.isNullOrEmpty() || !uri.rawAuthority.isNullOrEmpty()
}
