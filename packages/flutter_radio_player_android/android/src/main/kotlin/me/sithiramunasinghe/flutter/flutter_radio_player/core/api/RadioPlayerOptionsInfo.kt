package me.sithiramunasinghe.flutter.flutter_radio_player.core.api

public class RadioPlayerOptionsInfo(
    public val wrapAround: Boolean = true,
    public val reconnectGiveUpAfterMillis: Long = 5 * 60 * 1000L,
    public val stopOnTaskRemoved: Boolean = true,
    public val notificationIcon: String? = null,
) {
    override fun equals(other: Any?): Boolean =
        this === other || other is RadioPlayerOptionsInfo &&
            wrapAround == other.wrapAround &&
            reconnectGiveUpAfterMillis == other.reconnectGiveUpAfterMillis &&
            stopOnTaskRemoved == other.stopOnTaskRemoved &&
            notificationIcon == other.notificationIcon

    override fun hashCode(): Int =
        listOf(wrapAround, reconnectGiveUpAfterMillis, stopOnTaskRemoved, notificationIcon).hashCode()

    override fun toString(): String =
        "RadioPlayerOptionsInfo(wrapAround=$wrapAround, reconnectGiveUpAfterMillis=$reconnectGiveUpAfterMillis, " +
            "stopOnTaskRemoved=$stopOnTaskRemoved, notificationIcon=$notificationIcon)"
}
