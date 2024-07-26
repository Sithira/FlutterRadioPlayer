import Flutter
import UIKit

public class FlutterRadioPlayerPlugin: NSObject, FlutterPlugin {
    let player = PlaybackService.instance
    static var registrar: FlutterPluginRegistrar? = nil
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_radio_player", binaryMessenger: registrar.messenger())
        let instance = FlutterRadioPlayerPlugin()
        
        initalizeChannels(registrar: registrar)
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        FlutterRadioPlayerPlugin.registrar = registrar
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            if let args = call.arguments as? Dictionary<String, Any> {
                let sourcesAsString = args["sources"] as? String
                let isPlayWhenReady = args["playWhenReady"] as? Bool
                if let sources = sourcesAsString?.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    do {
                        let sources = try? decoder.decode([FlutterRadioPlayerSource].self, from: sources)
                        player.intialize(sources: sources!, playWhenReady: isPlayWhenReady!)
                    }
                }
            }
            break
        case "getVolume":
            result(player.getVolume())
            break
        case "play":
            player.play()
            break
        case "pause":
            player.pause()
            break
        case "nextSource":
            player.nextSource()
            break
        case "prevSource":
            player.prevSource()
            break
        case "changeVolume":
            if let args = call.arguments as? Dictionary<String, Any> {
                if let volume = args["volume"] as? Double {
                    player.setVolume(volume: Float(volume))
                    break
                }
            }
        case "sourceAtIndex":
            if let args = call.arguments as? Dictionary<String, Any> {
                if let sourceIndex = args["index"] as? Int {
                    player.jumpToItem(index: sourceIndex)
                    break
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    static private func initalizeChannels(registrar: FlutterPluginRegistrar) {
        let playbackStatusStream = FlutterEventChannel(name: "flutter_radio_player/playback_status", binaryMessenger: registrar.messenger())
        playbackStatusStream.setStreamHandler(PlaybackStatusEventStreamHandler())
        
        let nowPlayingInfoStream = FlutterEventChannel(name: "flutter_radio_player/now_playing_info", binaryMessenger: registrar.messenger())
        nowPlayingInfoStream.setStreamHandler(NowPlayingInfoStreamHandler())
        
        let deviceVolumeControlStream = FlutterEventChannel(name: "flutter_radio_player/volume_control", binaryMessenger: registrar.messenger())
        deviceVolumeControlStream.setStreamHandler(DeviceVolumeStreamHandler())
    }
}

class PlaybackStatusEventStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        PlaybackService.instance.playBackEventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        PlaybackService.instance.playBackEventSink = nil
        return nil
    }
}


class NowPlayingInfoStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        PlaybackService.instance.nowPlayingEventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        PlaybackService.instance.nowPlayingEventSink = nil
        return nil
    }
}

class DeviceVolumeStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        PlaybackService.instance.playbackVolumeControl = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        PlaybackService.instance.playbackVolumeControl = nil
        return nil
    }
}

