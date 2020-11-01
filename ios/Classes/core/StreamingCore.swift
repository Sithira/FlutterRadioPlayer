//
//  StreamingCore.swift
//  flutter_radio_player
//
//  Created by Sithira on 3/26/20.
//

import Foundation
import AVFoundation
import MediaPlayer

class StreamingCore : NSObject, AVPlayerItemMetadataOutputPushDelegate {
    
    private var avPlayer: AVPlayer?
    private var avPlayerItem: AVPlayerItem?
    private var playerItemContext = 0
    private var commandCenter: MPRemoteCommandCenter?
    private var playWhenReady: Bool = false
    
    var playerStatus: String = Constants.FLUTTER_RADIO_STOPPED

    
    override init() {
        print("StreamingCore Initializing...")
    }
    
    func initService(streamURL: String, serviceName: String, secondTitle: String, playWhenReady: String) -> Void {
        
        print("Initialing Service...")
        
        print("Stream url: " + streamURL)
        
        let streamURLInstance = URL(string: streamURL)
        
        // Setting up AVPlayer
        avPlayerItem = AVPlayerItem(url: streamURLInstance!)
        avPlayer = AVPlayer(playerItem: avPlayerItem!)
        if #available(iOS 10.0, *) {
            avPlayerItem?.preferredForwardBufferDuration = 10
            
        }
        
        //Listener for metadata from streaming
        let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metadataOutput.setDelegate(self, queue: DispatchQueue.main)
        avPlayerItem?.add(metadataOutput)
        
        if playWhenReady == "true" {
            print("PlayWhenReady: true")
            self.playWhenReady = true
        }

        // initialize player observers
        initPlayerObservers()
        
        // init Remote protocols.
        initRemoteTransportControl(appName: serviceName, subTitle: secondTitle);
        setupNotifications()
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        

       
    }

    @objc
    func appMovedToForeground() {
        print("Reemmiting the current state!")
        pushEvent(eventName: playerStatus)
    }

    func setupNotifications() {
        // Get the default notification center instance.
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(handleInterruption),
                       name: AVAudioSession.interruptionNotification,
                       object: nil)
    }

    @objc func handleInterruption(notification: Notification) {
        // To be implemented.
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                  return
          }
          switch type {
          case .began:
            _ = pause()
            print("an intrruption has begun")
            break
          case .ended:
            _ = play()
            break
          default: ()
          }
    }
    
    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack?) {
      if let item = groups.first?.items.first // make this an AVMetadata item
      {
          item.value(forKeyPath: "value")
          let song = (item.value(forKeyPath: "value")!)
         pushEvent(typeEvent: "meta_data",eventName: song as! String)

            
        }}
    
    func play() -> PlayerStatus {
        print("invoking play method on service")
        playerStatus = Constants.FLUTTER_RADIO_PLAYING
        if(!isPlaying()) {
            avPlayer?.play()
            pushEvent(eventName: Constants.FLUTTER_RADIO_PLAYING)
        }
        
        return PlayerStatus.PLAYING
    }
    
    func pause() -> PlayerStatus {
        print("invoking pause method on service")
        playerStatus = Constants.FLUTTER_RADIO_PAUSED
        if (isPlaying()) {
            avPlayer?.pause()
            pushEvent(eventName: Constants.FLUTTER_RADIO_PAUSED)
        }
        
        return PlayerStatus.PAUSE
    }
    
    func stop() -> PlayerStatus {
        print("invoking stop method on service")
        playerStatus = Constants.FLUTTER_RADIO_STOPPED
        if (isPlaying()) {
            pushEvent(eventName: Constants.FLUTTER_RADIO_STOPPED)
            avPlayer = nil
            avPlayerItem = nil
            commandCenter = nil
            
        }
        
        return PlayerStatus.STOPPED
    }
    
    func isPlaying() -> Bool {
        let status = (avPlayer?.rate != 0 && avPlayer?.error == nil) ? true : false
        print("isPlaying status: \(status)")
        return status
    }
    
    func setVolume(volume: NSNumber) -> Void {
        let formattedVolume = volume.floatValue;
        print("Setting volume to: \(formattedVolume)")
        avPlayer?.volume = formattedVolume
    }

     func setTitle(title: String, subTitle:String) -> Void {
        print("Setting title to: \(title)")
        let nowPlayingInfo = [MPMediaItemPropertyTitle : title, MPMediaItemPropertyArtist: subTitle]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
     }
    
    func setUrl(streamURL: String, playWhenReady: String) -> Void {
        let streamURLInstance = URL(string: streamURL)
        avPlayer?.replaceCurrentItem(with: AVPlayerItem(url: streamURLInstance!))
        
        if playWhenReady == "true" {
            self.playWhenReady = true
            _ = play()
        } else {
            self.playWhenReady = false
            _ = pause()
        }
    }
    
    private func pushEvent(typeEvent : String = "status", eventName: String) {
        print("Pushing event: \(eventName)")
        NotificationCenter.default.post(name: Notifications.playbackNotification, object: nil, userInfo: [typeEvent: eventName])
    }
    
    private func initRemoteTransportControl(appName: String, subTitle: String) {
        
        do {
            commandCenter = MPRemoteCommandCenter.shared()
            
            // build now playing info
            let nowPlayingInfo = [MPMediaItemPropertyTitle : appName, MPMediaItemPropertyArtist: subTitle]
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
            // basic command center options
            commandCenter?.togglePlayPauseCommand.isEnabled = true
            commandCenter?.playCommand.isEnabled = true
            commandCenter?.pauseCommand.isEnabled = true
            commandCenter?.nextTrackCommand.isEnabled = false
            commandCenter?.previousTrackCommand.isEnabled = false
            commandCenter?.changePlaybackRateCommand.isEnabled = false
            commandCenter?.skipForwardCommand.isEnabled = false
            commandCenter?.skipBackwardCommand.isEnabled = false
            commandCenter?.ratingCommand.isEnabled = false
            commandCenter?.likeCommand.isEnabled = false
            commandCenter?.dislikeCommand.isEnabled = false
            commandCenter?.bookmarkCommand.isEnabled = false
            commandCenter?.changeRepeatModeCommand.isEnabled = false
            commandCenter?.changeShuffleModeCommand.isEnabled = false
            
            // only available in iOS 9
            if #available(iOS 9.0, *) {
                commandCenter?.enableLanguageOptionCommand.isEnabled = false
                commandCenter?.disableLanguageOptionCommand.isEnabled = false
            }
            
            // control center play button callback
            commandCenter?.playCommand.addTarget { (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus in
                print("command center play command...")
                _ = self.play()
                return .success
            }
            
            // control center pause button callback
            commandCenter?.pauseCommand.addTarget { (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus in
                print("command center pause command...")
                _ = self.pause()
                return .success
            }
            
            // control center stop button callback
            commandCenter?.stopCommand.addTarget { (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus in
                print("command center stop command...")
                _ = self.stop()
                return .success
            }
            
            // create audio session for background playback and control center callbacks.
            let audioSession = AVAudioSession.sharedInstance()
            
            if #available(iOS 10.0, *) {
                try audioSession.setCategory(.playback, mode: .default, options: .defaultToSpeaker)
                try audioSession.overrideOutputAudioPort(.speaker)
                try audioSession.setActive(true)
            }
            
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Something went wrong ! \(error)")
        }
    }
    
    private func initPlayerObservers() {
        print("Initializing player observers...")
        // Add observer for AVPlayer.Status and AVPlayerItem.currentItem
        NotificationCenter.default.addObserver(self, selector: #selector(itemNewErrorLogEntry(_:)), name: .AVPlayerItemNewErrorLogEntry, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(itemFailedToPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(itemPlaybackStalled(_:)), name: .AVPlayerItemPlaybackStalled, object: nil)
        
        self.avPlayer?.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.new, .initial], context: nil)

        self.avPlayer?.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.status), options:[.new, .initial], context: nil)
        self.avPlayer?.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.isPlaybackBufferEmpty), options:[.new, .initial], context: nil)
    }
    
    @objc func itemNewErrorLogEntry(_ notification:Notification){
        print(notification)
    }
    
    @objc func itemFailedToPlayToEndTime(_ notification:Notification){
        if let _ = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]{
            _ = stop()
            print("Observer: Failed...")
            playerStatus = Constants.FLUTTER_RADIO_ERROR

            pushEvent(eventName: Constants.FLUTTER_RADIO_ERROR)
        }
    }
    @objc func itemPlaybackStalled(_ notification:Notification){
        _ = stop()
        print("Observer: Stalled...")
        playerStatus = Constants.FLUTTER_RADIO_ERROR

        pushEvent(eventName: Constants.FLUTTER_RADIO_ERROR)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        
        if object is AVPlayer {

            switch keyPath {
            case #keyPath(AVPlayer.currentItem.isPlaybackBufferEmpty):
                let _: Bool
                if let newStatusNumber = change?[NSKeyValueChangeKey.newKey] as? Bool {
                    if newStatusNumber {
                        print("Observer: Stalling...")
                        playerStatus = Constants.FLUTTER_RADIO_LOADING

                        pushEvent(eventName: Constants.FLUTTER_RADIO_LOADING)
                    }
                }
            case #keyPath(AVPlayer.currentItem.status):
                let newStatus: AVPlayerItem.Status
                if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                    newStatus = AVPlayerItem.Status(rawValue: newStatusAsNumber.intValue)!
                } else {
                    newStatus = .unknown
                }
                if newStatus == .readyToPlay {
                    print("Observer: Ready to play...")
                    if (!isPlaying()) {
                        if (self.playWhenReady) {
                           _ = play()
                        }else{
                            playerStatus = Constants.FLUTTER_RADIO_PAUSED
                            pushEvent(eventName: Constants.FLUTTER_RADIO_PAUSED)}
                    } else {
                        playerStatus = Constants.FLUTTER_RADIO_PLAYING

                        pushEvent(eventName: Constants.FLUTTER_RADIO_PLAYING)
                    }
                }
                
                if newStatus == .failed {
                    print("Observer: Failed...")
                    playerStatus = Constants.FLUTTER_RADIO_ERROR

                    pushEvent(eventName: Constants.FLUTTER_RADIO_ERROR)
                }
            case #keyPath(AVPlayer.status):
                var newStatus: AVPlayerItem.Status
                if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                    newStatus = AVPlayerItem.Status(rawValue: newStatusAsNumber.intValue)!
                } else {
                    newStatus = .unknown
                }
    
                if newStatus == .failed {
                    print("Observer: Failed...")
                    
                    playerStatus = Constants.FLUTTER_RADIO_ERROR

                    pushEvent(eventName: Constants.FLUTTER_RADIO_ERROR)
                }
            case .none:
                print("none...")
            case .some(_):
                print("some...")
            }
        }
    }
    
}


