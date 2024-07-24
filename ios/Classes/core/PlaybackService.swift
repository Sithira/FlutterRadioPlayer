//
//  PlaybackService.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2024-07-23.
//

import Foundation
import SwiftAudioEx
import AVFoundation
import MediaPlayer
import Flutter

class PlaybackService: NSObject {
    static let instance =  PlaybackService()
    private var player: QueuedAudioPlayer?
    var playBackEventSink: FlutterEventSink? = nil
    var nowPlayingEventSink: FlutterEventSink? = nil
    var playbackVolumeControl: FlutterEventSink? = nil
    let audioSession =  AVAudioSession.sharedInstance()
    
    private override init() {
        super.init()
        player = QueuedAudioPlayer()
        player?.automaticallyUpdateNowPlayingInfo = true
        player?.remoteCommands = [
            .play,
            .pause,
            .next,
            .previous
        ]
        
        player?.nowPlayingInfoController.set(keyValue: NowPlayingInfoProperty.isLiveStream(true))
        player?.volume = 0.5
        
        do {
            try AudioSessionController.shared.set(category: .playback)
            try AudioSessionController.shared.activateSession()
        } catch {
            
        }
        
        player?.event.stateChange.addListener(self, handlePlayerStateChange)
        player?.event.receiveTimedMetadata.addListener(self, handleNowPlayingChanges)
        player?.event.receiveCommonMetadata.addListener(self, handleCommonChanges)
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    
    private func handleCommonChanges(data: Any) {
        print(data)
    }
    
    func intialize(sources: Array<FlutterRadioPlayerSource>, playWhenReady: Bool) {
        for source in sources {
            let mediaSource = DefaultAudioItem(audioUrl: source.url, sourceType: .stream)
            if source.title == nil {
                mediaSource.artist = getAppName()
            } else {
                mediaSource.title = source.title
                mediaSource.artist = getAppName()
            }
            if source.artwork != nil {
                mediaSource.artwork = loadImageFromFlutterAssets(assetName: source.artwork!, registrar: FlutterRadioPlayerPlugin.registrar!)
            }
            player?.add(item: mediaSource, playWhenReady: playWhenReady)
        }
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        if player?.playerState.rawValue == "playing" {
            player?.pause()
        }
    }
    
    func nextSource() {
        if player?.items != nil {
            player?.next()
            player?.nowPlayingInfoController.set(keyValue: MediaItemProperty.artist(player?.currentItem?.getArtist()))
            self.nowPlayingEventSink?(nil)
        }
    }
    
    func prevSource() {
        if player?.items != nil {
            player?.previous()
            self.nowPlayingEventSink?(nil)
        }
    }
    
    func getVolume() -> Float {
        return (player?.volume)!
    }
    
    func setVolume(volume: Float) {
        player?.volume = volume
        DispatchQueue.main.async {
            let preparedEvent = FlutterRadioVolumeChanged(volume: volume)
            if let data = try? JSONEncoder().encode(preparedEvent) {
                self.playbackVolumeControl?(String(data: data, encoding: .utf8))
            }
        }
        self.playbackVolumeControl?(volume)
    }
    
    private func handleNowPlayingChanges(data: Array<AVTimedMetadataGroup>) {
        let nowPlayingData = data.first?.items.first
        if let nowPlayingAVMetaTitle = nowPlayingData?.value {
            player?.nowPlayingInfoController.set(keyValue: MediaItemProperty.title(nowPlayingAVMetaTitle as? String))
            let nowPlaying = NowPlayingInfo(title: nowPlayingAVMetaTitle as? String)
            if let encodedData = try? JSONEncoder().encode(nowPlaying) {
                DispatchQueue.main.async {
                    self.nowPlayingEventSink?(String(data: encodedData, encoding: .utf8)!)
                }
            }
        }
    }
    
    private func handlePlayerStateChange(state: AVPlayerWrapperState) {
        if state.rawValue == "playing" {
            DispatchQueue.main.async {
                self.playBackEventSink?(true)
            }
        }
        if state.rawValue == "paused" {
            DispatchQueue.main.async {
                self.playBackEventSink?(false)
            }
        }
    }
    
    private func getAppName() -> String? {
        if let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? Bundle.main.infoDictionary?["CFBundleName"] as? String {
            return appName
        } else {
            return nil
        }
    }
    
    private func loadImageFromFlutterAssets(assetName: String, registrar: FlutterPluginRegistrar) -> UIImage? {
        let assetKey = registrar.lookupKey(forAsset: assetName)
        guard let assetPath = Bundle.main.path(forResource: assetKey, ofType: nil),
              let image = UIImage(contentsOfFile: assetPath) else {
            return nil
        }
        return image
    }
    
}
