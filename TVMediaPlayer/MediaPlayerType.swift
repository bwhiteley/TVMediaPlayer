
public protocol MediaPlayerType {
    
    func pause()
    func play()
    
    /// The current item being played.
    var item:MediaItemType { get }
    
    /// The rate of playback. 1.0 is the standard rate.
    var rate:Float { get set }
    
    /// The position between 0.0 and 1.0. Setting the position
    /// causes playback to move to the new position.
    var position:Float { get set }
    
    /// During playback, call this closure at intervals frequently 
    /// enough to allow the scrubber to update smoothly, if visible.
    var positionChanged:((_ position:Float) -> Void)? { get set }
}

//
//  Created by Bart Whiteley on 1/3/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//
