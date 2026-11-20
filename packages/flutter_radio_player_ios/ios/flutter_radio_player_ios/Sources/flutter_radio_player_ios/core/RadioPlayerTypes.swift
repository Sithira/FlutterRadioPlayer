import Foundation

public enum RadioPlaybackStatus: String, Sendable {
    case idle, loading, playing, paused, error
}

public enum RadioPlayerErrorCode: String, Sendable {
    case invalidSource, network, httpStatus, unsupportedFormat, backgroundRestricted, timeout, unknown
}

public struct RadioPlayerError: Error, Sendable, Equatable {
    public let code: RadioPlayerErrorCode
    public let message: String

    public init(code: RadioPlayerErrorCode, message: String) {
        self.code = code
        self.message = message
    }
}

/// An index outside the source list the player holds.
public struct RadioPlayerIndexError: Error, Sendable, Equatable {
    public let message: String
}

public struct RadioSourceInfo: Sendable, Equatable, CustomStringConvertible {
    public let id: String
    public let url: String
    public let title: String?
    public let artwork: String?
    public let headers: [String: String]

    /// Local file the artwork is loaded from; set by the Flutter plugin for asset paths.
    var artworkFile: String?

    public init(
        url: String,
        id: String? = nil,
        title: String? = nil,
        artwork: String? = nil,
        headers: [String: String] = [:]
    ) {
        self.id = id ?? url
        self.url = url
        self.title = title
        self.artwork = artwork
        self.headers = headers
    }

    func sameStream(as other: RadioSourceInfo) -> Bool {
        id == other.id && url == other.url && headers == other.headers
    }

    public static func == (lhs: RadioSourceInfo, rhs: RadioSourceInfo) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url && lhs.title == rhs.title
            && lhs.artwork == rhs.artwork && lhs.headers == rhs.headers
    }

    public var description: String {
        "RadioSourceInfo(id: \(id), url: \(url), title: \(title ?? "nil"), "
            + "artwork: \(artwork ?? "nil"), headers: \(headers.keys.sorted()))"
    }
}

public struct RadioPlayerOptionsInfo: Sendable, Equatable {
    public var wrapAround: Bool
    /// Seconds.
    public var reconnectGiveUpAfter: TimeInterval

    public init(wrapAround: Bool = true, reconnectGiveUpAfter: TimeInterval = 300) {
        self.wrapAround = wrapAround
        self.reconnectGiveUpAfter = reconnectGiveUpAfter
    }
}

public struct RadioPlayerSnapshot: Sendable, Equatable {
    public let status: RadioPlaybackStatus
    public let sources: [RadioSourceInfo]
    public let currentIndex: Int?
    public let nowPlayingTitle: String?
    public let volume: Float
    public let error: RadioPlayerError?

    public var currentSource: RadioSourceInfo? {
        guard let currentIndex, sources.indices.contains(currentIndex) else { return nil }
        return sources[currentIndex]
    }

    /// No sources, volume 1.0: the state before any command and of a fresh player.
    public static let idle = RadioPlayerSnapshot(
        status: .idle, sources: [], currentIndex: nil, nowPlayingTitle: nil, volume: 1, error: nil
    )
}

/// Keeps an observation alive; cancelled by `invalidate()` or when released.
@MainActor
public final class RadioPlayerObservation {
    private var onInvalidate: (@MainActor () -> Void)?

    init(onInvalidate: @escaping @MainActor () -> Void) {
        self.onInvalidate = onInvalidate
    }

    public func invalidate() {
        onInvalidate?()
        onInvalidate = nil
    }

    deinit {
        guard let onInvalidate else { return }
        if Thread.isMainThread {
            MainActor.assumeIsolated { onInvalidate() }
        } else {
            DispatchQueue.main.async { MainActor.assumeIsolated { onInvalidate() } }
        }
    }
}
