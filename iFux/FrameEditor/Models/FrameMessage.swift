//
//  FrameMessage.swift
//  iFux
//
//  Created by Simon Morgenstern on 19.06.22.
//

import Foundation

struct FrameMessage: Encodable{
    var index: Int
    var duration: Int
    var changes: Array<Array<String>>
    var changesFux: Array<Array<String>>
}
