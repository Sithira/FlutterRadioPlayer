//
//  FRPNotificationUtil.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2022-03-06.
//

import Foundation

class FRPNotificationUtil: NSObject {
    private let frpNotification = NSNotification.Name("frp_notifications")
    private let notificationCenter =  NotificationCenter.default
    
    static let shared = FRPNotificationUtil()
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(onRecieve(_:)), name: frpNotification, object: nil)
    }
    
    func publish(eventData: FRPPlayerEvent) {
        do {
            try notificationCenter.post(name: frpNotification, object: nil, userInfo: ["event_data": JSONEncoder().encode(eventData)])
        } catch let err {
            print("Notification center publishing error: \(err)")
        }
    }
    
    @objc private func onRecieve(_ notification: Notification) {
        if let playerEvent = notification.userInfo?["event_data"] {
            let payload = String(data: playerEvent as! Data, encoding: .utf8)
            // {} will be placeholder in case of an error
            print("Notification received data: \(payload ?? "{}")")
            SwiftFlutterRadioPlayerPlugin.eventSink?(payload)
        }
    }
}
