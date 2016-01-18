import Foundation

enum DPadState: CustomStringConvertible {
    case Select
    case Right
    case Left
    case Up
    case Down
    
    var description:String {
        switch self {
        case .Select: return "Select"
        case .Right: return "Right"
        case .Left: return "Left"
        case .Down: return "Down"
        case .Up: return "Up"
        }
    }
}

//
//  Created by Bart Whiteley on 11/10/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//
