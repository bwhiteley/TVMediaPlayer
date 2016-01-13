//
//  MediaPlayerType.swift
//  MythTV
//
//  Created by J. B. Whiteley on 1/3/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//

import Foundation

public protocol MediaPlayerType {
    
    func pause()
    func play()
    
    var rate:Float { get set }
    var position:Float { get set }
    
    var positionChanged:((position:Float) -> Void)? { get set }
    
}
