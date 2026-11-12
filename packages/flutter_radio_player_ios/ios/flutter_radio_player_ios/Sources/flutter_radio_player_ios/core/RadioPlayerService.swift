import Flutter
import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import os

func mapPlaybackStatus(
    hasError: Bool,
    hasSources: Bool,
    hasCurrentItem: Bool,
    timeControlStatus: AVPlayer.TimeControlStatus
) -> PlaybackStatusMessage {
    if hasError { return .error }
    if !hasSources || !hasCurrentItem { return .idle }
    switch timeControlStatus {
    case .waitingToPlayAtSpecifiedRate: return .loading
    case .playing: return .playing
    case .paused: return .paused
    @unknown default: return .paused
    }
}

private let networkErrorCodes: Set<Int> = [
    NSURLErrorNotConnectedToInternet,
    NSURLErrorNetworkConnectionLost,
    NSURLErrorCannotConnectToHost,
    NSURLErrorCannotFindHost,
    NSURLErrorDNSLookupFailed,
    NSURLErrorTimedOut,
]

func mapPlaybackError(_ error: Error?) -> RadioPlayerErrorMessage {
    var current = error as NSError?
    var isNetworkError = false
    while let candidate = current {
        if candidate.domain == NSURLErrorDomain && networkErrorCodes.contains(candidate.code) {
            isNetworkError = true
            break
        }
        current = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    let description = (error as NSError?)?.localizedDescription ?? ""
    return RadioPlayerErrorMessage(
        code: isNetworkError ? .network : .unknown,
        message: description.isEmpty ? "Playback failed" : description
    )
}

class RadioPlayerService: NSObject {
    static let instance = RadioPlayerService()

    private static let log = Logger(subsystem: "flutter_radio_player_ios", category: "FlutterRadioPlayer")

    private var player: AVPlayer?
    private var isSetUp = false
    private var volume: Float = 0.5
    private var userIntendsToPlay = false
    private var currentArtwork: MPMediaItemArtwork?
    private var artworkLoadToken = 0
    private var artworkTask: URLSessionDataTask?
    private var sources: [RadioSourceMessage] = []
    private var currentIndex: Int = 0
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var metadataOutput: AVPlayerItemMetadataOutput?

    private var stateSink: PigeonEventSink<RadioPlayerStateMessage>?
    private var lastEmittedState: RadioPlayerStateMessage?
    private var nowPlayingTitle: String?
    private var lastError: RadioPlayerErrorMessage?

    private var registrar: FlutterPluginRegistrar?

    private override init() {
        super.init()
    }

    func setRegistrar(_ registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    func initialize(sources: [RadioSourceMessage], playWhenReady: Bool) {
        setUp()
        self.sources = sources
        self.currentIndex = 0
        userIntendsToPlay = false
        lastError = nil

        guard !sources.isEmpty else {
            player?.pause()
            clearCurrentItem()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            emitState()
            return
        }

        if loadSource(at: 0) && playWhenReady {
            startPlayback()
        }
    }

    func play() {
        guard requireSetUp("play") else { return }
        startPlayback()
    }

    func pause() {
        guard requireSetUp("pause") else { return }
        userIntendsToPlay = false
        player?.pause()
    }

    func playOrPause() {
        guard requireSetUp("playOrPause") else { return }
        if player?.timeControlStatus == .playing {
            pause()
        } else {
            play()
        }
    }

    func setVolume(volume: Float) {
        self.volume = volume
        player?.volume = volume
        emitState()
    }

    func getVolume() -> Float {
        return volume
    }

    func nextSource() {
        guard requireSetUp("nextSource") else { return }
        guard !sources.isEmpty else { return }
        let nextIndex = (currentIndex + 1) % sources.count
        if loadSource(at: nextIndex) {
            startPlayback()
        }
    }

    func previousSource() {
        guard requireSetUp("previousSource") else { return }
        guard !sources.isEmpty else { return }
        let prevIndex = (currentIndex - 1 + sources.count) % sources.count
        if loadSource(at: prevIndex) {
            startPlayback()
        }
    }

    func jumpToSourceAtIndex(index: Int) {
        guard requireSetUp("jumpToSourceAtIndex") else { return }
        guard index >= 0 && index < sources.count else { return }
        if loadSource(at: index) {
            startPlayback()
        }
    }

    func dispose() {
        guard isSetUp else {
            emitState()
            return
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        nowPlayingTitle = nil
        lastError = nil
        userIntendsToPlay = false
        tearDown()

        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
        emitState()
    }

    func setStateSink(_ sink: PigeonEventSink<RadioPlayerStateMessage>?) {
        stateSink = sink
        guard let sink = sink else { return }
        let state = makeState()
        lastEmittedState = state
        sink.success(state)
    }

    func currentState() -> RadioPlayerStateMessage {
        return makeState()
    }

    // MARK: - Private

    private func makeState() -> RadioPlayerStateMessage {
        let hasCurrentItem = player?.currentItem != nil
        let failedItem = player?.currentItem?.status == .failed ? player?.currentItem : nil
        let error = lastError ?? failedItem.map { mapPlaybackError($0.error) }
        let status = mapPlaybackStatus(
            hasError: error != nil,
            hasSources: !sources.isEmpty,
            hasCurrentItem: hasCurrentItem,
            timeControlStatus: player?.timeControlStatus ?? .paused
        )
        return RadioPlayerStateMessage(
            status: status,
            currentIndex: !sources.isEmpty && (hasCurrentItem || error != nil) ? Int64(currentIndex) : nil,
            nowPlayingTitle: hasCurrentItem ? nowPlayingTitle : nil,
            volume: Double(volume),
            error: error
        )
    }

    private func emitState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let state = self.makeState()
            guard state != self.lastEmittedState else { return }
            self.lastEmittedState = state
            self.stateSink?.success(state)
        }
    }

    private func setUp() {
        guard !isSetUp else { return }
        isSetUp = true
        configureAudioSession()
        if player == nil {
            let newPlayer = AVPlayer()
            newPlayer.volume = volume
            player = newPlayer
        }
        setupRemoteCommands()
        observePlayerState()
        observeInterruptions()
        observeRouteChanges()
        observeItemFailures()
    }

    private func tearDown() {
        isSetUp = false
        timeControlStatusObservation?.invalidate()
        timeControlStatusObservation = nil
        statusObservation?.invalidate()
        statusObservation = nil
        metadataOutput = nil
        NotificationCenter.default.removeObserver(self)

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(self)
        commandCenter.pauseCommand.removeTarget(self)
        commandCenter.nextTrackCommand.removeTarget(self)
        commandCenter.previousTrackCommand.removeTarget(self)
        UIApplication.shared.endReceivingRemoteControlEvents()

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        cancelArtworkLoad()
        currentArtwork = nil
        sources = []
        currentIndex = 0
    }

    private func requireSetUp(_ method: String) -> Bool {
        guard isSetUp else {
            Self.log.warning("\(method, privacy: .public)() called before initialize(); ignored")
            return false
        }
        return true
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    private func startPlayback() {
        userIntendsToPlay = true
        if shouldReloadCurrentSource() {
            guard loadSource(at: currentIndex) else { return }
        } else if lastError != nil {
            lastError = nil
            emitState()
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
    }

    private func shouldReloadCurrentSource() -> Bool {
        guard currentIndex >= 0, currentIndex < sources.count else { return false }
        if player?.currentItem?.status == .failed { return true }
        return lastError != nil
    }

    private func clearCurrentItem() {
        statusObservation?.invalidate()
        statusObservation = nil
        metadataOutput = nil
        cancelArtworkLoad()
        currentArtwork = nil
        nowPlayingTitle = nil
        player?.replaceCurrentItem(with: nil)
    }

    private func cancelArtworkLoad() {
        artworkLoadToken += 1
        artworkTask?.cancel()
        artworkTask = nil
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true

        commandCenter.playCommand.addTarget(self, action: #selector(handlePlayCommand))
        commandCenter.pauseCommand.addTarget(self, action: #selector(handlePauseCommand))
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(handleNextCommand))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(handlePreviousCommand))

        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    @objc private func handlePlayCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        play()
        return .success
    }

    @objc private func handlePauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        pause()
        return .success
    }

    @objc private func handleNextCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        nextSource()
        return .success
    }

    @objc private func handlePreviousCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        previousSource()
        return .success
    }

    @discardableResult
    private func loadSource(at index: Int) -> Bool {
        let source = sources[index]

        currentIndex = index
        clearCurrentItem()

        guard let url = URL(string: source.url), let scheme = url.scheme, !scheme.isEmpty else {
            lastError = RadioPlayerErrorMessage(
                code: .invalidSource,
                message: "Invalid source URL: \(source.url)"
            )
            updateNowPlayingInfo(title: source.title)
            loadArtwork(for: source)
            emitState()
            return false
        }

        lastError = nil

        let item = AVPlayerItem(url: url)
        setupMetadataOutput(for: item)
        player?.replaceCurrentItem(with: item)

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                self?.updateNowPlayingInfo(title: source.title)
            case .failed:
                self?.handleItemFailure(item, error: item.error)
            default:
                break
            }
        }

        updateNowPlayingInfo(title: source.title)
        loadArtwork(for: source)

        emitState()
        return true
    }

    private func handleItemFailure(_ item: AVPlayerItem, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isSetUp, item === self.player?.currentItem else { return }
            self.lastError = mapPlaybackError(error)
            self.emitState()
        }
    }

    private func setupMetadataOutput(for item: AVPlayerItem) {
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        output.setDelegate(self, queue: .main)
        item.add(output)
        metadataOutput = output
    }

    private func observePlayerState() {
        timeControlStatusObservation = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self = self, self.isSetUp else { return }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPNowPlayingInfoPropertyPlaybackRate] =
                    player.timeControlStatus == .playing ? 1.0 : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                self.emitState()
            }
        }
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    private func observeItemFailures() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFailedToPlayToEnd),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: nil
        )
    }

    @objc private func handleFailedToPlayToEnd(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem else { return }
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        handleItemFailure(item, error: error ?? item.error)
    }

    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.handleInterruption(notification) }
            return
        }
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            player?.pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && userIntendsToPlay {
                    startPlayback()
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.handleRouteChange(notification) }
            return
        }
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    private func updateNowPlayingInfo(title: String?) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title ?? getAppName() ?? "Radio",
            MPMediaItemPropertyArtist: getAppName() ?? "",
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]

        if let artwork = currentArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(for source: RadioSourceMessage) {
        guard let artworkPath = source.artwork, !artworkPath.isEmpty else { return }

        if artworkPath.hasPrefix("http://") || artworkPath.hasPrefix("https://") {
            loadArtworkFromURL(artworkPath)
        } else {
            loadArtworkFromAsset(artworkPath)
        }
    }

    private func loadArtworkFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let token = artworkLoadToken
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard let self = self, self.artworkLoadToken == token else { return }
                self.setNowPlayingArtwork(image)
            }
        }
        artworkTask = task
        task.resume()
    }

    private func loadArtworkFromAsset(_ assetName: String) {
        guard let registrar = self.registrar else { return }
        let assetKey = registrar.lookupKey(forAsset: assetName)
        guard let assetPath = Bundle.main.path(forResource: assetKey, ofType: nil),
              let image = UIImage(contentsOfFile: assetPath) else { return }
        setNowPlayingArtwork(image)
    }

    private func setNowPlayingArtwork(_ image: UIImage) {
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        currentArtwork = artwork
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func getAppName() -> String? {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
    }
}

// MARK: - AVPlayerItemMetadataOutputPushDelegate

extension RadioPlayerService: AVPlayerItemMetadataOutputPushDelegate {
    func metadataOutput(_ output: AVPlayerItemMetadataOutput,
                        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
                        from track: AVPlayerItemTrack?) {
        guard isSetUp, output === metadataOutput, player?.currentItem != nil else { return }
        for group in groups {
            for item in group.items {
                if let title = item.stringValue, !title.isEmpty {
                    updateNowPlayingInfo(title: title)
                    nowPlayingTitle = title
                    emitState()
                    return
                }
            }
        }
    }
}
