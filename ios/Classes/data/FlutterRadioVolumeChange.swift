//
//  FlutterRadioVolumeChange.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2024-07-24.
//

import Foundation

struct FlutterRadioVolumeChanged: Codable {
    var volume: Float
    var isMuted: Bool = false
}
