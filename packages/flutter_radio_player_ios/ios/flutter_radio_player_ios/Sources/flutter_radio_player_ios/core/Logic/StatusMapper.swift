struct PlayerFacts: Sendable {
    var hasSources: Bool
    var reconnectPending: Bool
    var failed: Bool
    var playRequested: Bool
    var rendering: Bool
}

func status(of facts: PlayerFacts) -> RadioPlaybackStatus {
    if !facts.hasSources { return .idle }
    if facts.reconnectPending { return .loading }
    if facts.failed { return .error }
    if facts.playRequested && !facts.rendering { return .loading }
    if facts.rendering { return .playing }
    return .paused
}
