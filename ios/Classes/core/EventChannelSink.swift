//
//  EventChannelSink.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2024-07-23.
//

import Foundation
import Flutter

class EventChannelSink {
    static let instance = EventChannelSink()
    var playbackEventChannel: FlutterEventChannel?;
    var nowPlayingEventChannel: FlutterEventChannel?;
    var playbackVolumeChannel: FlutterEventChannel?;
    
    private init() {
        
    }
    
    
}
