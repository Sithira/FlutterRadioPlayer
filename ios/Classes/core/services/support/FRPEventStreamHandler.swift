//
//  FRPEventStreamHandler.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2022-03-06.
//

import Foundation

class FRPEventStreamHandler: NSObject, FlutterStreamHandler {
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.eventSink = events
        print("onListen \(String(describing: events))")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.eventSink = nil
        print("onCancel")
        return nil
    }
    
}


