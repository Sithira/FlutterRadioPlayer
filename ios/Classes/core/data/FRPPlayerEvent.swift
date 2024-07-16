//
//  FRPPlayerEvent.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2022-05-25.
//

import Foundation

struct FRPPlayerEvent: Codable {
    var currentSource: FRPCurrentSource? = nil
    var volumeChangeEvent: FRPVolumeChangeEvent? = nil
    var type: String? = nil
    var playbackStatus: String? = nil
    var icyMetaDetails: String? = nil
}
