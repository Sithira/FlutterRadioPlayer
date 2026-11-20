package me.sithiramunasinghe.flutter.flutter_radio_player.core.logic

import me.sithiramunasinghe.flutter.flutter_radio_player.core.api.PlaybackStatus

internal class PlayerFacts(
    val hasSources: Boolean,
    val reconnectPending: Boolean,
    val failed: Boolean,
    val playRequested: Boolean,
    val rendering: Boolean,
)

internal fun statusOf(facts: PlayerFacts): PlaybackStatus = when {
    !facts.hasSources -> PlaybackStatus.IDLE
    facts.reconnectPending -> PlaybackStatus.LOADING
    facts.failed -> PlaybackStatus.ERROR
    facts.playRequested && !facts.rendering -> PlaybackStatus.LOADING
    facts.rendering -> PlaybackStatus.PLAYING
    else -> PlaybackStatus.PAUSED
}
