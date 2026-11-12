import Flutter
import UIKit

public class FlutterRadioPlayerPlugin: NSObject, FlutterPlugin, RadioPlayerHostApi {
    private let service = RadioPlayerService.instance

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterRadioPlayerPlugin()
        RadioPlayerService.instance.setRegistrar(registrar)
        RadioPlayerHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        instance.setupEventChannels(messenger: registrar.messenger())
    }

    func initialize(
        sources: [RadioSourceMessage],
        playWhenReady: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        service.initialize(sources: sources, playWhenReady: playWhenReady)
        completion(.success(()))
    }

    func play(completion: @escaping (Result<Void, Error>) -> Void) {
        service.play()
        completion(.success(()))
    }

    func pause(completion: @escaping (Result<Void, Error>) -> Void) {
        service.pause()
        completion(.success(()))
    }

    func playOrPause(completion: @escaping (Result<Void, Error>) -> Void) {
        service.playOrPause()
        completion(.success(()))
    }

    func setVolume(volume: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        service.setVolume(volume: Float(volume))
        completion(.success(()))
    }

    func getVolume(completion: @escaping (Result<Double, Error>) -> Void) {
        completion(.success(Double(service.getVolume())))
    }

    func nextSource(completion: @escaping (Result<Void, Error>) -> Void) {
        service.nextSource()
        completion(.success(()))
    }

    func previousSource(completion: @escaping (Result<Void, Error>) -> Void) {
        service.previousSource()
        completion(.success(()))
    }

    func jumpToSourceAtIndex(index: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        service.jumpToSourceAtIndex(index: Int(index))
        completion(.success(()))
    }

    func dispose(completion: @escaping (Result<Void, Error>) -> Void) {
        service.dispose()
        completion(.success(()))
    }

    func getState(completion: @escaping (Result<RadioPlayerStateMessage, Error>) -> Void) {
        completion(.success(service.currentState()))
    }

    private func setupEventChannels(messenger: FlutterBinaryMessenger) {
        OnStateChangedStreamHandler.register(
            with: messenger,
            streamHandler: StateStreamWrapper(service: service)
        )
    }
}

private class StateStreamWrapper: OnStateChangedStreamHandler {
    let service: RadioPlayerService
    init(service: RadioPlayerService) { self.service = service }

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<RadioPlayerStateMessage>) {
        service.setStateSink(sink)
    }

    override func onCancel(withArguments arguments: Any?) {
        service.setStateSink(nil)
    }
}
