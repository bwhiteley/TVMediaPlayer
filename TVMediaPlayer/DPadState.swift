
enum DPadState: CustomStringConvertible {
    case select
    case right
    case left
    case up
    case down
    
    var description:String {
        switch self {
        case .select: return "Select"
        case .right: return "Right"
        case .left: return "Left"
        case .down: return "Down"
        case .up: return "Up"
        }
    }
}

//
//  Created by Bart Whiteley on 11/10/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//
