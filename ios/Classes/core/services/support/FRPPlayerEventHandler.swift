//
//  FRPPlayerEventHandler.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2022-03-06.
//

import Foundation
import AVFoundation
import SwiftAudioEx

class FRPPlayerEventHandler: NSObject {
    
    override init() {
        print("::::: EVENT HANDLER INIT ::::")
//        FRPCoreService.shared.player.eve
    }
    
    static func handleAudioLevelChange(volume: Float) {
        print("Changed :::::::::: ")
    }
    
    
    static func handleMetaDataChanges(metaDetails: Array<AVMetadataItem>) {
        if (FRPCoreService.shared.useIcyData) {
            metaDetails
                .compactMap({ $0 as AVMetadataItem })
                .forEach({ meta in
                    print("Meta details \(meta)")
                    FRPCoreService.shared.currentMetaData = meta
                    let nowPlayingTitle = meta.value as! String
                    FRPCoreService.shared.player.nowPlayingInfoController.set(keyValue: MediaItemProperty.albumTitle(nowPlayingTitle))
                    FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(icyMetaDetails: nowPlayingTitle))
            })
        }
    }
    
    static func handleAudioPlayerStateChange(state: AudioPlayerState) {
        switch state {
        case .playing:
            print("FRP playing...")
            FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(playbackStatus: FRPConsts.FRP_PLAYING))
            FRPCoreService.shared.playbackStatus = FRPPlaybackStatus.PLAYING
            break
        case .loading, .buffering:
            print("FRP loading...")
            FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(playbackStatus: FRPConsts.FRP_LOADING))
            FRPCoreService.shared.playbackStatus = FRPPlaybackStatus.LOADING
            break
        case .idle:
            FRPCoreService.shared.playbackStatus = FRPPlaybackStatus.STOPPED
            FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(playbackStatus: FRPConsts.FRP_STOPPED))
            print("FRP idle")
            break
        case .ready:
            print("FRP ready..")
            break
        case .paused:
            print("FRP paused")
            FRPCoreService.shared.playbackStatus = FRPPlaybackStatus.PAUSED
            FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(playbackStatus: FRPConsts.FRP_PAUSED))
            break
        }
    }
}
