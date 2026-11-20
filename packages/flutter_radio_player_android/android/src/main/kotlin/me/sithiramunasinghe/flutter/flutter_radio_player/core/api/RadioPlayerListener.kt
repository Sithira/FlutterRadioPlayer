package me.sithiramunasinghe.flutter.flutter_radio_player.core.api

/** Called on the main looper with every distinct snapshot. */
public fun interface RadioPlayerListener {
    public fun onSnapshot(snapshot: RadioPlayerSnapshot)
}

/**
 * Completion of a command, on the main looper: the snapshot after the command was
 * applied, or the current snapshot and a [RadioPlayerIndexException].
 */
public fun interface RadioPlayerCallback {
    public fun onComplete(snapshot: RadioPlayerSnapshot, error: RadioPlayerIndexException?)
}
