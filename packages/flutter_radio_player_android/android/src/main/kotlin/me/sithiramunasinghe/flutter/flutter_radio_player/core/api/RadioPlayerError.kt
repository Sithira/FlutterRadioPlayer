package me.sithiramunasinghe.flutter.flutter_radio_player.core.api

public enum class RadioPlayerErrorCode {
    INVALID_SOURCE,
    NETWORK,
    HTTP_STATUS,
    UNSUPPORTED_FORMAT,
    BACKGROUND_RESTRICTED,
    TIMEOUT,
    UNKNOWN,
}

public class RadioPlayerError(public val code: RadioPlayerErrorCode, public val message: String) {
    override fun equals(other: Any?): Boolean =
        this === other || other is RadioPlayerError && code == other.code && message == other.message

    override fun hashCode(): Int = 31 * code.hashCode() + message.hashCode()

    override fun toString(): String = "RadioPlayerError(code=$code, message=$message)"
}

/** An index outside the source list the player holds. */
public class RadioPlayerIndexException(message: String) : IllegalArgumentException(message)
