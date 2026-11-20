import AVFoundation
import Foundation
import MediaPlayer
import UIKit

/// The shared radio player. One per process; every Flutter engine and any host
/// code (a CarPlay scene) use the same instance. Commands apply at once and return
/// the snapshot after the command; observers get that snapshot first.
@MainActor
public final class RadioPlayerCore: NSObject {
    private static var shared: RadioPlayerCore?

    /// Posted synchronously on the main thread when the shared player is created;
    /// `object` is the new `RadioPlayerCore`.
    public static let didCreateNotification = Notification.Name("RadioPlayerCoreDidCreate")

    /// The shared player, created on first use.
    public static func acquire() -> RadioPlayerCore {
        if let shared { return shared }
        let core = RadioPlayerCore()
        shared = core
        NotificationCenter.default.post(name: didCreateNotification, object: core)
        return core
    }

    /// The shared player if one exists; never creates it.
    public static var existing: RadioPlayerCore? { shared }

    private let player = AVPlayer()
    private var sources: [RadioSourceInfo] = []
    private var currentIndex: Int?
    private var playIntent = false
    private var interrupted = false
    private var nowPlayingTitle: String?
    private var error: RadioPlayerError?
    private var options = RadioPlayerOptionsInfo()

    private var item: AVPlayerItem?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var sessionActive = false
    private var remoteCommandsRegistered = false
    private var artwork: MPMediaItemArtwork?
    private var artworkToken = 0

    private var observers: [UUID: @MainActor (RadioPlayerSnapshot) -> Void] = [:]
    private var lastSnapshot = RadioPlayerSnapshot.idle

    private override init() {
        super.init()
        player.volume = 1
        timeControlObservation = player.observe(\.timeControlStatus) { [weak self] _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.timeControlChanged() } }
        }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(interruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(routeChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(failedToPlayToEnd(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
    }

    // MARK: Public API

    public var snapshot: RadioPlayerSnapshot { makeSnapshot() }

    /// Calls `handler` with every distinct snapshot until the observation is released.
    public func observe(_ handler: @escaping @MainActor (RadioPlayerSnapshot) -> Void) -> RadioPlayerObservation {
        let id = UUID()
        observers[id] = handler
        return RadioPlayerObservation { [weak self] in self?.observers[id] = nil }
    }

    @discardableResult
    public func setSources(_ newSources: [RadioSourceInfo], initialIndex: Int? = nil, autoPlay: Bool = false) throws -> RadioPlayerSnapshot {
        if let initialIndex, !newSources.indices.contains(initialIndex) {
            throw RadioPlayerIndexError(message: "initialIndex \(initialIndex) is out of range for \(newSources.count) sources")
        }
        let selection = selectSource(
            old: sources, oldIndex: currentIndex, new: newSources, initialIndex: initialIndex,
            id: { $0.id }, sameStream: { $0.sameStream(as: $1) }
        )
        let previous = currentSource
        sources = newSources
        currentIndex = selection.index
        if selection.index == nil {
            turnOff()
        } else if selection.keepStream {
            if previous?.title != currentSource?.title || previous?.artwork != currentSource?.artwork {
                if item != nil { publishNowPlaying(reloadArtwork: previous?.artwork != currentSource?.artwork) }
            }
        } else {
            closeStream()
            playIntent = false
        }
        if autoPlay && !sources.isEmpty { startPlayback() }
        return commit()
    }

    @discardableResult
    public func setOptions(_ options: RadioPlayerOptionsInfo) -> RadioPlayerSnapshot {
        self.options = options
        updateRemoteCommands()
        return commit()
    }

    @discardableResult
    public func play(at index: Int? = nil) throws -> RadioPlayerSnapshot {
        guard !sources.isEmpty else { return commit() }
        if let index {
            guard sources.indices.contains(index) else {
                throw RadioPlayerIndexError(message: "Index \(index) is out of range for \(sources.count) sources")
            }
            if index != currentIndex { switchSource(to: index) }
        }
        startPlayback()
        return commit()
    }

    @discardableResult
    public func pause() -> RadioPlayerSnapshot {
        guard !sources.isEmpty else { return commit() }
        playIntent = false
        error = nil
        player.pause()
        return commit()
    }

    @discardableResult
    public func playOrPause() -> RadioPlayerSnapshot {
        guard !sources.isEmpty else { return commit() }
        if makeSnapshot().status == .playing || makeSnapshot().status == .loading {
            return pause()
        }
        startPlayback()
        return commit()
    }

    @discardableResult
    public func stop() -> RadioPlayerSnapshot {
        guard !sources.isEmpty else { return commit() }
        turnOff()
        return commit()
    }

    @discardableResult
    public func next() -> RadioPlayerSnapshot { step(1) }

    @discardableResult
    public func previous() -> RadioPlayerSnapshot { step(-1) }

    @discardableResult
    public func setVolume(_ volume: Float) -> RadioPlayerSnapshot {
        player.volume = min(max(volume, 0), 1)
        return commit()
    }

    // MARK: Playback

    private var currentSource: RadioSourceInfo? {
        guard let currentIndex, sources.indices.contains(currentIndex) else { return nil }
        return sources[currentIndex]
    }

    private func step(_ delta: Int) -> RadioPlayerSnapshot {
        let count = sources.count
        guard count >= 2, let currentIndex else { return commit() }
        var target = currentIndex + delta
        if !(0..<count).contains(target) {
            guard options.wrapAround else { return commit() }
            target = (target + count) % count
        }
        let status = makeSnapshot().status
        let wasPlaying = status == .playing || status == .loading
        switchSource(to: target)
        if wasPlaying { startPlayback() } else { playIntent = false }
        return commit()
    }

    private func switchSource(to index: Int) {
        closeStream()
        currentIndex = index
    }

    private func startPlayback() {
        guard let source = currentSource else { return }
        playIntent = true
        interrupted = false
        error = nil
        activateSession()
        if item == nil || item?.status == .failed {
            closeStream()
            guard let url = playableURL(source.url) else {
                error = RadioPlayerError(code: .invalidSource, message: "Invalid source URL: \(source.url)")
                playIntent = false
                return
            }
            loadItem(url: url)
        }
        player.play()
    }

    private func loadItem(url: URL) {
        let item = AVPlayerItem(url: url)
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        output.setDelegate(self, queue: .main)
        item.add(output)
        metadataOutput = output
        itemStatusObservation = item.observe(\.status) { [weak self] item, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.itemStatusChanged(item) } }
        }
        self.item = item
        player.replaceCurrentItem(with: item)
        publishNowPlaying(reloadArtwork: true)
    }

    private func closeStream() {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        metadataOutput = nil
        item = nil
        nowPlayingTitle = nil
        error = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func turnOff() {
        playIntent = false
        closeStream()
        deactivateSession()
    }

    private func itemStatusChanged(_ item: AVPlayerItem) {
        guard item === self.item, item.status == .failed else { return }
        fail(with: item.error)
    }

    private func fail(with underlying: Error?) {
        error = mapError(underlying)
        commit()
    }

    private func timeControlChanged() {
        if player.timeControlStatus == .playing, error != nil { error = nil }
        updatePlaybackRate()
        commit()
    }

    @objc private nonisolated func failedToPlayToEnd(_ notification: Notification) {
        let item = notification.object as? AVPlayerItem
        let underlying = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let item, item === self.item else { return }
                self.fail(with: underlying ?? item.error)
            }
        }
    }

    @objc private nonisolated func interruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                switch type {
                case .began:
                    guard self.playIntent else { return }
                    self.interrupted = true
                    self.player.pause()
                case .ended:
                    let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
                    if self.interrupted && self.playIntent && shouldResume {
                        self.startPlayback()
                    }
                    self.interrupted = false
                @unknown default:
                    break
                }
                self.commit()
            }
        }
    }

    @objc private nonisolated func routeChange(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
              reason == .oldDeviceUnavailable else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated { _ = self.pause() }
        }
    }

    // MARK: Snapshot

    private func makeSnapshot() -> RadioPlayerSnapshot {
        let facts = PlayerFacts(
            hasSources: !sources.isEmpty,
            reconnectPending: false,
            failed: error != nil,
            playRequested: playIntent && !interrupted,
            rendering: item != nil && player.timeControlStatus == .playing
        )
        return RadioPlayerSnapshot(
            status: status(of: facts),
            sources: sources,
            currentIndex: currentIndex,
            nowPlayingTitle: nowPlayingTitle,
            volume: player.volume,
            error: error
        )
    }

    @discardableResult
    private func commit() -> RadioPlayerSnapshot {
        let snapshot = makeSnapshot()
        if snapshot != lastSnapshot {
            lastSnapshot = snapshot
            for observer in observers.values { observer(snapshot) }
        }
        return snapshot
    }

    // MARK: Session, remote commands, now playing

    private func activateSession() {
        if !sessionActive {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
            sessionActive = true
        }
        registerRemoteCommands()
    }

    private func deactivateSession() {
        guard sessionActive else { return }
        sessionActive = false
        unregisterRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        artwork = nil
        artworkToken += 1
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func registerRemoteCommands() {
        guard !remoteCommandsRegistered else { return updateRemoteCommands() }
        remoteCommandsRegistered = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget(self, action: #selector(remotePlay(_:)))
        center.pauseCommand.addTarget(self, action: #selector(remotePause(_:)))
        center.togglePlayPauseCommand.addTarget(self, action: #selector(remoteToggle(_:)))
        center.nextTrackCommand.addTarget(self, action: #selector(remoteNext(_:)))
        center.previousTrackCommand.addTarget(self, action: #selector(remotePrevious(_:)))
        updateRemoteCommands()
    }

    private func unregisterRemoteCommands() {
        guard remoteCommandsRegistered else { return }
        remoteCommandsRegistered = false
        let center = MPRemoteCommandCenter.shared()
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                        center.nextTrackCommand, center.previousTrackCommand] {
            command.removeTarget(self)
        }
    }

    private func updateRemoteCommands() {
        guard remoteCommandsRegistered else { return }
        let center = MPRemoteCommandCenter.shared()
        let canStep = sources.count >= 2
        let index = currentIndex ?? 0
        center.nextTrackCommand.isEnabled = canStep && (options.wrapAround || index < sources.count - 1)
        center.previousTrackCommand.isEnabled = canStep && (options.wrapAround || index > 0)
    }

    @objc private func remotePlay(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        _ = try? play()
        return .success
    }

    @objc private func remotePause(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        pause()
        return .success
    }

    @objc private func remoteToggle(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        playOrPause()
        return .success
    }

    @objc private func remoteNext(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        next()
        return .success
    }

    @objc private func remotePrevious(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        previous()
        return .success
    }

    private func publishNowPlaying(reloadArtwork: Bool) {
        guard let source = currentSource else { return }
        updateRemoteCommands()
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle ?? source.title ?? appName,
            MPMediaItemPropertyArtist: nowPlayingTitle == nil ? appName : (source.title ?? appName),
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: player.timeControlStatus == .playing ? 1.0 : 0.0,
        ]
        if reloadArtwork {
            artwork = nil
            loadArtwork(for: source)
        }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updatePlaybackRate() {
        guard item != nil, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.timeControlStatus == .playing ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(for source: RadioSourceInfo) {
        artworkToken += 1
        let token = artworkToken
        if let file = source.artworkFile {
            if let image = UIImage(contentsOfFile: file) { setArtwork(image) }
            return
        }
        guard let path = source.artwork, let url = playableURL(path) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.artworkToken == token else { return }
                    self.setArtwork(image)
                }
            }
        }.resume()
    }

    private func setArtwork(_ image: UIImage) {
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
        self.artwork = artwork
        guard item != nil, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension RadioPlayerCore: AVPlayerItemMetadataOutputPushDelegate {
    public nonisolated func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        let title = groups.lazy.flatMap(\.items).compactMap(\.stringValue).first { !$0.isEmpty }
        MainActor.assumeIsolated {
            guard let title, output === self.metadataOutput else { return }
            self.nowPlayingTitle = title
            self.publishNowPlaying(reloadArtwork: false)
            self.commit()
        }
    }
}

private let networkErrorCodes: Set<Int> = [
    NSURLErrorNotConnectedToInternet,
    NSURLErrorNetworkConnectionLost,
    NSURLErrorCannotConnectToHost,
    NSURLErrorCannotFindHost,
    NSURLErrorDNSLookupFailed,
]

func mapError(_ error: Error?) -> RadioPlayerError {
    var current = error as NSError?
    var code = RadioPlayerErrorCode.unknown
    while let candidate = current {
        if candidate.domain == NSURLErrorDomain {
            if candidate.code == NSURLErrorTimedOut {
                code = .timeout
                break
            }
            if networkErrorCodes.contains(candidate.code) {
                code = .network
                break
            }
        }
        current = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    let description = (error as NSError?)?.localizedDescription ?? ""
    return RadioPlayerError(code: code, message: description.isEmpty ? "Playback failed" : description)
}
