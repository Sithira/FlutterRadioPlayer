import Flutter
import Foundation
import AVFoundation
import MediaPlayer
import UIKit

class RadioPlayerService: NSObject {
    static let instance = RadioPlayerService()

    private var player: AVPlayer?
    private var sources: [RadioSourceMessage] = []
    private var currentIndex: Int = 0
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var metadataOutput: AVPlayerItemMetadataOutput?

    var playbackStateSink: PigeonEventSink<Bool>?
    var nowPlayingSink: PigeonEventSink<NowPlayingInfoMessage>?
    var volumeSink: PigeonEventSink<VolumeInfoMessage>?

    private var registrar: FlutterPluginRegistrar?

    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
        player = AVPlayer()
        player?.volume = 0.5
        observePlayerState()
        observeInterruptions()
        observeRouteChanges()
    }

    func setRegistrar(_ registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    func initialize(sources: [RadioSourceMessage], playWhenReady: Bool) {
        self.sources = sources
        self.currentIndex = 0

        guard !sources.isEmpty else { return }

        loadSource(at: 0)
        if playWhenReady {
            player?.play()
        }
    }

    func play() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func playOrPause() {
        if player?.timeControlStatus == .playing {
            pause()
        } else {
            play()
        }
    }

    func setVolume(volume: Float) {
        player?.volume = volume
        DispatchQueue.main.async {
            self.volumeSink?.success(VolumeInfoMessage(volume: Double(volume), isMuted: volume == 0))
        }
    }

    func getVolume() -> Float {
        return player?.volume ?? 0.5
    }

    func nextSource() {
        guard !sources.isEmpty else { return }
        let nextIndex = (currentIndex + 1) % sources.count
        loadSource(at: nextIndex)
        player?.play()
    }

    func previousSource() {
        guard !sources.isEmpty else { return }
        let prevIndex = (currentIndex - 1 + sources.count) % sources.count
        loadSource(at: prevIndex)
        player?.play()
    }

    func jumpToSourceAtIndex(index: Int) {
        guard index >= 0 && index < sources.count else { return }
        loadSource(at: index)
        player?.play()
    }

    func dispose() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        timeControlStatusObservation?.invalidate()
        statusObservation?.invalidate()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPRemoteCommandCenter.shared().playCommand.removeTarget(self)
        MPRemoteCommandCenter.shared().pauseCommand.removeTarget(self)
        MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(self)
        MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(self)
    }

    // MARK: - Private

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {}
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

    private func loadSource(at index: Int) {
        currentIndex = index
        let source = sources[index]

        guard let url = URL(string: source.url) else { return }

        statusObservation?.invalidate()

        let item = AVPlayerItem(url: url)
        setupMetadataOutput(for: item)
        player?.replaceCurrentItem(with: item)

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .readyToPlay {
                self?.updateNowPlayingInfo(title: source.title)
            }
        }

        updateNowPlayingInfo(title: source.title)
        loadArtwork(for: source)

        DispatchQueue.main.async {
            self.nowPlayingSink?.success(NowPlayingInfoMessage(title: nil))
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
                let isPlaying = player.timeControlStatus == .playing
                self?.playbackStateSink?.success(isPlaying)

                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
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

    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
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

        if let existing = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let artwork = existing[MPMediaItemPropertyArtwork] {
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
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.setNowPlayingArtwork(image)
            }
        }.resume()
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
        for group in groups {
            for item in group.items {
                if let title = item.stringValue, !title.isEmpty {
                    updateNowPlayingInfo(title: title)
                    DispatchQueue.main.async {
                        self.nowPlayingSink?.success(NowPlayingInfoMessage(title: title))
                    }
                    return
                }
            }
        }
    }
}
