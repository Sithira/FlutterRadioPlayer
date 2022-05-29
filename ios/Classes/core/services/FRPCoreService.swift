//
//  FRPCoreService.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2022-03-05.
//

import Foundation
import SwiftAudioEx
import AVFAudio
import AVFoundation
import MediaPlayer

class FRPCoreService: NSObject {
    
    var player: QueuedAudioPlayer = QueuedAudioPlayer()
    var audioSession: AVAudioSession =  AVAudioSession.sharedInstance()
    var playbackStatus: FRPPlaybackStatus = FRPPlaybackStatus.STOPPED
    var currentPlayingItem: DefaultAudioItem? = nil
    var useIcyData: Bool = false
    var mediaSources: Array<FRPMediaSource> = []
    var currentMetaData: AVMetadataItem? = nil
    
    static let shared = FRPCoreService()
    
    private override init() {
        // singletone
    }
    
    func initCore() {
        
        try? audioSession.setCategory(.playback)
        try? audioSession.setActive(true)
        
        player.nowPlayingInfoController.set(keyValue: NowPlayingInfoProperty.isLiveStream(true))
        
        player.remoteCommands = [
            .play,
            .pause,
            .next,
            .previous
        ]
        
        // custom commands
        player.remoteCommandController.handleNextTrackCommand = { (event) in self.handleNextTrackCommandDefault(event: event) }
        player.remoteCommandController.handlePreviousTrackCommand = { (event) in self.handlePreviousTrackCommandDefault(event: event) }
        
        // add listeners
        player.event.stateChange.addListener(self, FRPPlayerEventHandler.handleAudioPlayerStateChange)
        player.event.receiveMetadata.addListener(self, FRPPlayerEventHandler.handleMetaDataChanges)
        
        audioSession.addObserver(self, forKeyPath: #keyPath(AVAudioSession.outputVolume), options: [.new, .initial], context: nil)
    }
    
    /**
            - parameter media sources to load to FRPCoreService
     */
    func setMediaSources(sources: Array<FRPMediaSource>, playDefault: Bool) throws {
        
        if (sources.isEmpty) {
            throw FRPException.runtimeError(errorMessage: "Empty media sources")
        }
        
        let defaultAudioItem = sources.first(where: { frp in frp.isPrimary! })
        
        if (defaultAudioItem == nil) {
            throw FRPException.runtimeError(errorMessage: "No default media source")
        }
        
        if (playDefault) {
            
            // set current playing item
            currentPlayingItem = DefaultAudioItem(
                audioUrl: defaultAudioItem!.url,
                title: defaultAudioItem?.title,
                albumTitle: defaultAudioItem?.description,
                sourceType: .stream)
            
            // filter current playing item with sources
            mediaSources = sources.filter({ frp in frp.url != currentPlayingItem?.audioUrl })
            
            try? player.add(item: currentPlayingItem!, playWhenReady: playDefault)
            mediaSources.forEach({frp in try? player.add(item: DefaultAudioItem(audioUrl: frp.url, title: frp.title, albumTitle: frp.description, sourceType: .stream))})
        } else {
            // adding all media sources with default play false
            mediaSources.forEach({ frp in
                try? player.add(item: DefaultAudioItem(audioUrl: frp.url, title: frp.title, albumTitle: frp.description, sourceType: .stream), playWhenReady: false)
            })
        }
        
    }
    
    func play() -> Void {
        player.play()
        FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(playbackStatus: FRPConsts.FRP_PLAYING))
    }
    
    func pause() -> Void {
        player.pause()
        FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(playbackStatus: FRPConsts.FRP_PAUSED))
    }
    
    func isPlaying() -> Bool {
        return playbackStatus == FRPPlaybackStatus.PLAYING
    }
    
    func playOrPause() ->  Void {
        isPlaying() ? pause() : play()
    }
    
    func stop() -> Void {
        player.stop()
    }
    
    func setVolume(volume: Float) -> Float {
        player.volume = volume
        FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(type: FRPConsts.FRP_VOLUME_CHANGED))
        return volume
    }
    
    func handleMetaDataChanges(metaDetails: Array<AVMetadataItem>) {
        if (self.useIcyData) {
            metaDetails
                .compactMap({ $0 as AVMetadataItem })
                .forEach({ meta in
                    currentMetaData = meta
                    let nowPlayingTitle = meta.value as! String
                    player.nowPlayingInfoController.set(keyValue: MediaItemProperty.albumTitle(nowPlayingTitle))
                    FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(icyMetaDetails: nowPlayingTitle))

            })
        }
    }
    
    func next() {
        do {
            try player.next()
            currentPlayingItem = updateCurrentPlayingItem(current: player.currentItem!)
            FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(currentSource: getCurrentSource()))
        } catch let err {
            print("Play next item failed: \(err)")
        }
    }
    
    func previous() {
        do {
            try player.previous()
            currentPlayingItem = updateCurrentPlayingItem(current: player.currentItem!)
            FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(currentSource: getCurrentSource()))
        } catch let err {
            print("Play previous item failed: \(err)")
        }
    }
    
    func useICYData(status: Bool = false) {
        useIcyData = status
    }
    
    private func getCurrentSource() -> FRPCurrentSource {
        return FRPCurrentSource(title: (currentPlayingItem?.title)! , description: (currentPlayingItem?.albumTitle)! )
    }
    
    private func updateCurrentPlayingItem(current: AudioItem) -> DefaultAudioItem {
        return DefaultAudioItem(audioUrl: current.getSourceUrl(), title: current.getTitle(), albumTitle: current.getAlbumTitle(), sourceType: current.getSourceType())
    }
    
    private func handleNextTrackCommandDefault(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        next()
        return MPRemoteCommandHandlerStatus.success
    }

    private func handlePreviousTrackCommandDefault(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        previous()
        return MPRemoteCommandHandlerStatus.success
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (object is AVAudioSession) {
            switch (keyPath) {
            case #keyPath(AVAudioSession.outputVolume):
                if let newStatus = change?[NSKeyValueChangeKey.newKey] as? Float {
                    if newStatus == 0 {
                        FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(type: FRPConsts.FRP_VOLUME_MUTE))
                        print("Volume muted...")
                    } else {
                        FRPNotificationUtil.shared.publish(eventData: FRPPlayerEvent(volumeChangeEvent: FRPVolumeChangeEvent(volume: newStatus), type: FRPConsts.FRP_VOLUME_CHANGED))
                        print("Volume toggle: \(newStatus)")
                    }
                }
                break
            case .none, .some(_):
                break
            }
        }
    }
}
