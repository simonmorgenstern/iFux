//
//  Animation.swift
//  iFux
//
//  Created by Simon Morgenstern on 05.07.22.
//

import Foundation



struct Animation: Identifiable, Codable{
    var id = UUID().uuidString
    var fileName: String
    var duration: Int
}
