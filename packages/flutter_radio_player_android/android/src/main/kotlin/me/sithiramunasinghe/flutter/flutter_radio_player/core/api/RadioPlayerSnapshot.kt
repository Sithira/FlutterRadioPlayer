package me.sithiramunasinghe.flutter.flutter_radio_player.core.api

public class RadioPlayerSnapshot(
    public val status: PlaybackStatus,
    sources: List<RadioSourceInfo>,
    public val currentIndex: Int?,
    public val nowPlayingTitle: String?,
    public val volume: Float,
    public val error: RadioPlayerError?,
) {
    public val sources: List<RadioSourceInfo> = sources.toList()

    public val currentSource: RadioSourceInfo?
        get() = currentIndex?.let(sources::getOrNull)

    override fun equals(other: Any?): Boolean =
        this === other || other is RadioPlayerSnapshot &&
            status == other.status && sources == other.sources &&
            currentIndex == other.currentIndex && nowPlayingTitle == other.nowPlayingTitle &&
            volume == other.volume && error == other.error

    override fun hashCode(): Int =
        listOf(status, sources, currentIndex, nowPlayingTitle, volume, error).hashCode()

    override fun toString(): String =
        "RadioPlayerSnapshot(status=$status, currentIndex=$currentIndex, sources=$sources, " +
            "nowPlayingTitle=$nowPlayingTitle, volume=$volume, error=$error)"

    public companion object {
        /** No sources, volume 1.0: the state before any command and of a fresh player. */
        @JvmField
        public val IDLE: RadioPlayerSnapshot =
            RadioPlayerSnapshot(PlaybackStatus.IDLE, emptyList(), null, null, 1f, null)
    }
}
