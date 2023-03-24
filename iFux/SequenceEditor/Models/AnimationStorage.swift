//
//  AnimationStorage.swift
//  iFux
//
//  Created by Simon Morgenstern on 18.07.22.
//
import Foundation

struct AnimationStorage: Codable {
    var animations: [Animation]
    var beatGrid: [Beat]
}
