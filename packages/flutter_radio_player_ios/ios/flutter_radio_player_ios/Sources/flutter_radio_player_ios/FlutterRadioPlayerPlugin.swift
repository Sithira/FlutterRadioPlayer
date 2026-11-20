import Flutter
import UIKit

/// One instance per Flutter engine; all of them drive `RadioPlayerCore.acquire()`.
public final class FlutterRadioPlayerPlugin: NSObject, FlutterPlugin, RadioPlayerHostApi {
    private let registrar: FlutterPluginRegistrar
    private let stateHandler = StateStreamHandler()

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterRadioPlayerPlugin(registrar: registrar)
        RadioPlayerHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        OnStateChangedStreamHandler.register(with: registrar.messenger(), streamHandler: instance.stateHandler)
        registrar.publish(instance)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        RadioPlayerHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
        MainActor.assumeIsolated { stateHandler.cancel() }
    }

    typealias Completion = (Result<RadioPlayerStateMessage, Error>) -> Void

    func setSources(sources: [RadioSourceMessage], initialIndex: Int64?, autoPlay: Bool, completion: @escaping Completion) {
        run(completion) { core in
            try core.setSources(sources.map(self.sourceInfo), initialIndex: initialIndex.map(Int.init), autoPlay: autoPlay)
        }
    }

    func setOptions(options: RadioPlayerOptionsMessage, completion: @escaping Completion) {
        run(completion) { core in
            core.setOptions(RadioPlayerOptionsInfo(
                wrapAround: options.wrapAround,
                reconnectGiveUpAfter: TimeInterval(options.reconnectGiveUpAfterMillis) / 1000
            ))
        }
    }

    func play(index: Int64?, completion: @escaping Completion) {
        run(completion) { try $0.play(at: index.map(Int.init)) }
    }

    func pause(completion: @escaping Completion) { run(completion) { $0.pause() } }

    func playOrPause(completion: @escaping Completion) { run(completion) { $0.playOrPause() } }

    func stop(completion: @escaping Completion) { run(completion) { $0.stop() } }

    func next(completion: @escaping Completion) { run(completion) { $0.next() } }

    func previous(completion: @escaping Completion) { run(completion) { $0.previous() } }

    func setVolume(volume: Double, completion: @escaping Completion) {
        run(completion) { $0.setVolume(Float(volume)) }
    }

    private func run(_ completion: Completion, _ command: @MainActor (RadioPlayerCore) throws -> RadioPlayerSnapshot) {
        MainActor.assumeIsolated {
            do {
                let snapshot = try command(RadioPlayerCore.acquire())
                completion(.success(snapshot.message))
            } catch let error as RadioPlayerIndexError {
                completion(.failure(PigeonError(code: "invalid_index", message: error.message, details: nil)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func sourceInfo(_ message: RadioSourceMessage) -> RadioSourceInfo {
        var info = RadioSourceInfo(
            url: message.url, id: message.id, title: message.title,
            artwork: message.artwork, headers: message.headers
        )
        if let artwork = message.artwork, !artwork.hasPrefix("http://"), !artwork.hasPrefix("https://") {
            info.artworkFile = Bundle.main.path(forResource: registrar.lookupKey(forAsset: artwork), ofType: nil)
        }
        return info
    }
}

private final class StateStreamHandler: OnStateChangedStreamHandler {
    private var observation: RadioPlayerObservation?
    private var sink: PigeonEventSink<RadioPlayerStateMessage>?
    private var creationObserver: NSObjectProtocol?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<RadioPlayerStateMessage>) {
        MainActor.assumeIsolated {
            self.sink = sink
            if let core = RadioPlayerCore.existing {
                attach(to: core, sink: sink)
                return
            }
            sink.success(RadioPlayerSnapshot.idle.message)
            creationObserver = NotificationCenter.default.addObserver(
                forName: RadioPlayerCore.didCreateNotification, object: nil, queue: nil
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self, let sink = self.sink, let core = notification.object as? RadioPlayerCore else { return }
                    self.stopWaitingForCreation()
                    self.attach(to: core, sink: sink)
                }
            }
        }
    }

    @MainActor
    private func stopWaitingForCreation() {
        if let creationObserver { NotificationCenter.default.removeObserver(creationObserver) }
        creationObserver = nil
    }

    override func onCancel(withArguments arguments: Any?) {
        MainActor.assumeIsolated { cancel() }
    }

    @MainActor
    func cancel() {
        stopWaitingForCreation()
        observation?.invalidate()
        observation = nil
        sink = nil
    }

    @MainActor
    private func attach(to core: RadioPlayerCore, sink: PigeonEventSink<RadioPlayerStateMessage>) {
        observation = core.observe { [weak self] snapshot in self?.sink?.success(snapshot.message) }
        sink.success(core.snapshot.message)
    }
}

extension RadioPlayerSnapshot {
    var message: RadioPlayerStateMessage {
        RadioPlayerStateMessage(
            status: PlaybackStatusMessage.from(status),
            sources: sources.map {
                RadioSourceMessage(id: $0.id, url: $0.url, title: $0.title, artwork: $0.artwork, headers: $0.headers)
            },
            currentIndex: currentIndex.map(Int64.init),
            nowPlayingTitle: nowPlayingTitle,
            volume: Double(volume),
            error: error.map { RadioPlayerErrorMessage(code: RadioPlayerErrorCodeMessage.from($0.code), message: $0.message) }
        )
    }
}

extension PlaybackStatusMessage {
    static func from(_ status: RadioPlaybackStatus) -> PlaybackStatusMessage {
        switch status {
        case .idle: return .idle
        case .loading: return .loading
        case .playing: return .playing
        case .paused: return .paused
        case .error: return .error
        }
    }
}

extension RadioPlayerErrorCodeMessage {
    static func from(_ code: RadioPlayerErrorCode) -> RadioPlayerErrorCodeMessage {
        switch code {
        case .invalidSource: return .invalidSource
        case .network: return .network
        case .httpStatus: return .httpStatus
        case .unsupportedFormat: return .unsupportedFormat
        case .backgroundRestricted: return .backgroundRestricted
        case .timeout: return .timeout
        case .unknown: return .unknown
        }
    }
}
