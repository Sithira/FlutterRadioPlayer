//
//  FRPCoreService.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2022-03-05.
//

import Foundation
import AVFoundation
import MediaPlayer

class FRPCoreServiceEX: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    
    private var player: AVQueuePlayer = AVQueuePlayer()
    private var currentAvPlayerItem: AVPlayerItem?
    private var mediaSource: [FRPMediaSource] = [FRPMediaSource]()
    private var audioSession: AVAudioSession =  AVAudioSession.sharedInstance()
    private var playbackStatus: FRPPlaybackStatus = FRPPlaybackStatus.STOPPED
    
    
    func initCore() {
        print(" ::::::: FRPCoreService INIT :::::::: ")
        do {
            try audioSession.setCategory(.playback, options: .mixWithOthers)
            try audioSession.setActive(true)
            self.initPlayerObservers()
        } catch {
            print("::::::: COULD NOT ACTIVATE AUDIO SESSION ::::::")
        }
    }
    
    func setMediaSources(sources: Array<FRPMediaSource>, playDefault: Bool = false) throws -> Void {
        
        mediaSource = sources
        
        if (mediaSource.isEmpty) {
            throw FRPException.runtimeError(errorMessage: "Empty media sources")
        }
        
        if (playbackStatus == FRPPlaybackStatus.STOPPED || playbackStatus == FRPPlaybackStatus.PAUSED) {
            let primarySource = mediaSource.first(where: {$0.isPrimary == true})
            
            if (primarySource == nil) {
                throw FRPException.runtimeError(errorMessage: "No primary source defined")
            }
            
            currentAvPlayerItem = AVPlayerItem.init(url: URL(string: primarySource!.url)!)
            player.replaceCurrentItem(with: currentAvPlayerItem)
            
            if (playDefault) {
                playbackStatus = FRPPlaybackStatus.PLAYING
                mediaSource = mediaSource.filter { frp in frp.url != primarySource?.url }
                player.play()
            } else {
                mediaSource.forEach({ frp in player.insert(AVPlayerItem.init(url: URL(string: frp.url)!), after: nil) })
            }
        }
    }
    
    func play() -> Void {
        player.play()
    }
    
    func pause() -> Void {
        player.pause()
    }
    
    func nextSource() -> Void {
        player.advanceToNextItem()
    }
    
    func isPlaying() -> Bool {
        if #available(iOS 10.0, *) {
            return player.timeControlStatus == AVQueuePlayer.TimeControlStatus.playing
        } else {
            return player.rate != 0 && player.error == nil
        }
    }
    
    func setVolume(volume: Float) -> Void {
        player.volume = volume
    }
    
    
    private func initPlayerObservers() {
        print("Initializing player observers...")
        player.addObserver(self, forKeyPath: #keyPath(AVQueuePlayer.status), options: [.new, .initial], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVQueuePlayer.currentItem.isPlaybackBufferEmpty), options:[.new, .initial], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVQueuePlayer.rate), options: [.new, .initial], context: nil)
        audioSession.addObserver(self, forKeyPath: #keyPath(AVAudioSession.outputVolume), options: [.initial, .new], context: nil)
    }


    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        print(object)
        if (object is AVQueuePlayer) {
            switch keyPath {
            case #keyPath(AVQueuePlayer.currentItem.isPlaybackBufferEmpty):
                if let newStatus = change?[NSKeyValueChangeKey.newKey] as? Bool {
                    if newStatus {
                        playbackStatus = FRPPlaybackStatus.LOADING
                        print("PLAYER LOADING...")
                    }
                }
            case #keyPath(AVPlayer.status):
                if let newStatus = change?[NSKeyValueChangeKey.newKey] as? Int {
                    let playerStatus = AVQueuePlayer.Status(rawValue: newStatus)?.rawValue
                    switch (playerStatus) {
                    case AVQueuePlayer.Status.readyToPlay.rawValue:
                        playbackStatus = FRPPlaybackStatus.PAUSED
                        print("Player ready to play \(newStatus)")
                        break
                    case AVQueuePlayer.Status.failed.rawValue:
                        playbackStatus = FRPPlaybackStatus.ERROR
                        print("Player ready to failed \(newStatus)")
                        break
                    case AVQueuePlayer.Status.unknown.rawValue:
                        print("Player ready to unknown \(newStatus)")
                        break
                    case .none:
                        print("none")
                    case .some(_):
                        print("some")
                    }
                }
            case #keyPath(AVQueuePlayer.rate):
                if let newStatus = change?[NSKeyValueChangeKey.newKey] as? Float {
                    if newStatus == 0.0 {
                        print("Player paused")
                    }
                    if newStatus == 1.0 {
                        print("Player playing")
                    }
                }
            case .none:
                print("none...")
            case .some(_):
                print("some...")
            default:
                print("Observer: unhandled change for keyPath " + keyPath!)
            }

        }
    
        if (object is AVAudioSession) {
            switch (keyPath) {
            case #keyPath(AVAudioSession.outputVolume):
                if let newStatus = change?[NSKeyValueChangeKey.newKey] as? Float {
                    print("Volume toggle: \(newStatus)")
                    if newStatus == 0 {
                        print("Volume muted...")
                    }
                }
         
                break
            case .none:
                print("ss")
                break
            case .some(_):
                print("sss")
                break
            }
        }
    }
}
