package me.sithiramunasinghe.flutter.flutter_radio_player.core.api

public class RadioSourceInfo(
    public val url: String,
    id: String? = null,
    public val title: String? = null,
    public val artwork: String? = null,
    headers: Map<String, String> = emptyMap(),
) {
    public val id: String = id ?: url
    public val headers: Map<String, String> = headers.toMap()

    /** Where the service loads artwork from; set by the Flutter plugin for asset paths. */
    internal var artworkUri: String? = null

    internal fun sameStream(other: RadioSourceInfo): Boolean =
        id == other.id && url == other.url && headers == other.headers

    override fun equals(other: Any?): Boolean =
        this === other || other is RadioSourceInfo &&
            id == other.id && url == other.url && title == other.title &&
            artwork == other.artwork && headers == other.headers

    override fun hashCode(): Int = listOf(id, url, title, artwork, headers).hashCode()

    override fun toString(): String =
        "RadioSourceInfo(id=$id, url=$url, title=$title, artwork=$artwork, headers=${headers.keys})"
}
