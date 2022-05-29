import Flutter
import UIKit

public class SwiftFlutterRadioPlayerPlugin: NSObject, FlutterPlugin {
    
let frpCoreService: FRPCoreService = FRPCoreService.shared
    static var eventSink: FlutterEventSink? = nil
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_radio_player/method_channel", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterRadioPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "flutter_radio_player/event_channel", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(FRPEventStreamHandler())
        instance.frpCoreService.initCore()
    
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        if call.method == "play" {
            self.frpCoreService.play()
            result("success")
            return
        }
        
        if call.method == "pause" {
            self.frpCoreService.pause()
            result("success")
        }
        
        if call.method == "stop" {
            self.frpCoreService.stop()
            result("success")
            return
        }
        
        if call.method == "next_source" {
            self.frpCoreService.next()
            result("success")
            return
        }
        
        if call.method == "previous_source" {
            self.frpCoreService.previous()
            result("success")
            return
        }
        
        if call.method == "seek_source_to_index" {
            if  let args = call.arguments as? Dictionary<String, Any> {
                let sourceIndex = args["source_index"] as? Int ?? 0
                let playIfReady = args["play_when_ready"] as? Bool ?? false
                do {
                    try self.frpCoreService.player.jumpToItem(atIndex: sourceIndex, playWhenReady: playIfReady)
                } catch let err {
                    print("JumpTo: \(err)")
                }
            }
        }
        
        if (call.method == "play_or_pause") {
            self.frpCoreService.playOrPause()
            result("success")
            return
        }
        
        if call.method == "init_services" {
            // for plugin stub!
            print("Calling \(call.method)")
            result("success")
            return
        }
        
        if call.method == "get_playback_state" {
            result(self.frpCoreService.playbackStatus.rawValue)
            return
        }
        
        if call.method == "use_icy_data" {
            self.frpCoreService.useICYData(status: true)
            result("success")
            return
        }
        
        if call.method == "get_current_metadata" {
            result(frpCoreService.currentMetaData?.value as? String ?? "N/A")
            return
        }
        
        if call.method == "set_volume" {
            if let args = call.arguments as? Dictionary<String, Any> {
                let volume = args["volume"] as? Float ?? 0.5
                let adjustedVolume = self.frpCoreService.setVolume(volume: volume)
                result(adjustedVolume)
            }
            result("success")
        }
        
        if call.method == "get_is_playing" {
            result(self.frpCoreService.isPlaying())
        }
 
        if call.method == "set_sources" {
            if let args = call.arguments as? Dictionary<String, Any> {
                let mediaSourceMap = args["media_sources"] as? Array<Dictionary<String, Any>>
                let sourceList = mediaSourceMap?.map({ x in
                    FRPMediaSource.init(map: x)
                })
                 do {
                    try self.frpCoreService.setMediaSources(sources: sourceList!, playDefault: true)
                 } catch let error {
                     print(error)
                 }
            }
            result("success")
            return
        }
    }
}
