//
//  PlayerObserver.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2022-03-05.
//

import Foundation
import AVFoundation

class PlayerObserver: NSObject {
    
    private var playbackStatus: FRPPlaybackStatus
    
    init(_ playbackStatus: inout FRPPlaybackStatus) {
        self.playbackStatus = playbackStatus
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
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
