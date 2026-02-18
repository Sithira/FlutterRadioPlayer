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

    func initialize(sources: [RadioSourceMessage], playWhenReady: Bool) throws {
        service.initialize(sources: sources, playWhenReady: playWhenReady)
    }

    func play() throws {
        service.play()
    }

    func pause() throws {
        service.pause()
    }

    func playOrPause() throws {
        service.playOrPause()
    }

    func setVolume(volume: Double) throws {
        service.setVolume(volume: Float(volume))
    }

    func getVolume() throws -> Double {
        return Double(service.getVolume())
    }

    func nextSource() throws {
        service.nextSource()
    }

    func previousSource() throws {
        service.previousSource()
    }

    func jumpToSourceAtIndex(index: Int64) throws {
        service.jumpToSourceAtIndex(index: Int(index))
    }

    func dispose() throws {
        service.dispose()
    }

    private func setupEventChannels(messenger: FlutterBinaryMessenger) {
        OnPlaybackStateChangedStreamHandler.register(
            with: messenger,
            streamHandler: PlaybackStateStreamWrapper(service: service)
        )
        OnNowPlayingChangedStreamHandler.register(
            with: messenger,
            streamHandler: NowPlayingStreamWrapper(service: service)
        )
        OnVolumeChangedStreamHandler.register(
            with: messenger,
            streamHandler: VolumeStreamWrapper(service: service)
        )
    }
}

private class PlaybackStateStreamWrapper: OnPlaybackStateChangedStreamHandler {
    let service: RadioPlayerService
    init(service: RadioPlayerService) { self.service = service }

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<Bool>) {
        service.playbackStateSink = sink
    }

    override func onCancel(withArguments arguments: Any?) {
        service.playbackStateSink = nil
    }
}

private class NowPlayingStreamWrapper: OnNowPlayingChangedStreamHandler {
    let service: RadioPlayerService
    init(service: RadioPlayerService) { self.service = service }

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<NowPlayingInfoMessage>) {
        service.nowPlayingSink = sink
    }

    override func onCancel(withArguments arguments: Any?) {
        service.nowPlayingSink = nil
    }
}

private class VolumeStreamWrapper: OnVolumeChangedStreamHandler {
    let service: RadioPlayerService
    init(service: RadioPlayerService) { self.service = service }

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<VolumeInfoMessage>) {
        service.volumeSink = sink
    }

    override func onCancel(withArguments arguments: Any?) {
        service.volumeSink = nil
    }
}
