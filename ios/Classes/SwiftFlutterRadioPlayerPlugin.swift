import Flutter
import UIKit

public class SwiftFlutterRadioPlayerPlugin: NSObject, FlutterPlugin {
    
    private var streamingCore: StreamingCore = StreamingCore()
    
    public static var mEventSink: FlutterEventSink?
    public static var eventSinkMetadata: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_radio_player", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterRadioPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // register the event channel
        let eventChannel = FlutterEventChannel(name: "flutter_radio_player_stream", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(StatusStreamHandler())
        
        let eventChannelMetadata = FlutterEventChannel(name: "flutter_radio_player_meta_stream", binaryMessenger: registrar.messenger())
        eventChannelMetadata.setStreamHandler(MetaDataStreamHandler())
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch (call.method) {
        case "initService":
            print("method called to start the radio service")
            if let args = call.arguments as? Dictionary<String, Any>,
                let streamURL = args["streamURL"] as? String,
                let appName = args["appName"] as? String,
                let subTitle = args["subTitle"] as? String,
                let playWhenReady = args["playWhenReady"] as? String
            {
                if !streamingCore.isFirstTime{
                    NotificationCenter.default.removeObserver(self, name:  Notifications.playbackNotification, object: nil)
                }
                NotificationCenter.default.addObserver(self, selector: #selector(onRecieve(_:)), name: Notifications.playbackNotification, object: nil)

                streamingCore.initService(streamURL: streamURL, serviceName: appName, secondTitle: subTitle, playWhenReady: playWhenReady)
                
                result(false)
            }
            break
        case "playOrPause":
            print("method called to playOrPause from service")
            if (streamingCore.isPlaying()) {
                _ = streamingCore.pause()
            } else {
                _ = streamingCore.play()
            }
        case "play":
            print("method called to play from service")
            let status = streamingCore.play()
            if (status == PlayerStatus.PLAYING) {
                result(true)
            }
            result(false)
            break
            
        case "newPlay":
            print("method called to newPlay from service")
            let status = streamingCore.newPlay()
            if (status == PlayerStatus.PLAYING) {
                result(true)
            }
            result(false)
            break
       case "setTitle":
            print("method called to set title from service")
          if let args = call.arguments as? Dictionary<String, Any>,
                        let title = args["title"] as? String,
                        let subTitle = args["subtitle"] as? String
                    {
            streamingCore.setTitle(title:title,subTitle:subTitle)
           }
            result(false)
            break
        case "pause":
            print("method called to play from service")
            let status = streamingCore.pause()
            if (status == PlayerStatus.IDLE) {
                result(true)
            }
            result(false)
            break
        case "stop":
            print("method called to stopped from service")
            let status = streamingCore.stop()
            if (status == PlayerStatus.STOPPED) {
                result(true)
            }
            result(false)
            break
        case "isPlaying":
            print("method called to is_playing from service")
            result(streamingCore.isPlaying())
            break
        case "setVolume":
            print("method called to setVolume from service")
            if let args = call.arguments as? Dictionary<String, Any>,
                let volume = args["volume"] as? NSNumber {
                print("Received set to volume: \(volume)")
                streamingCore.setVolume(volume: volume)
            }
            result(nil)
        case "setUrl":
            if let args = call.arguments as? Dictionary<String, Any>,
                let streamURL = args["streamUrl"] as? String,
                let playWhenReady = args["playWhenReady"] as? String
            {
                print("method called to setUrl")
                streamingCore.setUrl(streamURL: streamURL, playWhenReady: playWhenReady)
            }
            result(nil)
        default:
            result(nil)
        }
    }
   
    
    @objc private func onRecieve(_ notification: Notification) {
        // unwrapping optional
        if let playerEvent = notification.userInfo!["status"] {
            print("Notification received with event name: \(playerEvent)")
            SwiftFlutterRadioPlayerPlugin.mEventSink?(playerEvent)
        }
        
        if let metaDataEvent = notification.userInfo!["meta_data"] {
            print("Notification received with metada: \(metaDataEvent)")
            SwiftFlutterRadioPlayerPlugin.eventSinkMetadata?(metaDataEvent as! String)
        }
    }
    
    deinit {
        print("DeinitPlugin")
    }
}



class StatusStreamHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.mEventSink = events
        return nil;
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.mEventSink = nil
        return nil;
    }
}

class MetaDataStreamHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.eventSinkMetadata = events
        return nil;
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.eventSinkMetadata = nil
        return nil;
    }
}
