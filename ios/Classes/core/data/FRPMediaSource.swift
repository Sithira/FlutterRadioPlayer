//
//  FRPMediaSource.swift
//  flutter_radio_player
//
//  Created by Sithira Munasinghe on 2022-05-25.
//

import Foundation

struct FRPMediaSource: Codable {
    let url: String
    let isPrimary: Bool?
    let title: String?
    let description: String?
    
    init(map: Dictionary<String, Any>) {
        self.url = (map["url"] as? String)!
        self.isPrimary = map["isPrimary"] as? Bool
        self.title = map["title"] as? String
        self.description = map["description"] as? String
    }
}
