import Foundation

public protocol MediaItemType {
    var title:String { get }
    var subtitle:String? { get }
    
    /// The length of the media item in seconds.
    var length:Double { get }
    
    func adBreaks() async throws -> [AdBreak]
}

extension MediaItemType {
    fileprivate func timeIntervalDisplayValue(seconds interval:Int) -> String {
        let secsInHour = 60 * 60
        let hours = interval / secsInHour
        let remainder = interval % secsInHour
        let minutes = remainder / 60
        let seconds = remainder % 60
        var s = ""
        if hours > 0 {
            s = "\(hours):"
        }
        if minutes < 10 {
            s += "0"
        }
        s += "\(minutes):"
        if seconds < 10 {
            s += "0"
        }
        s += "\(seconds)"
        return s
    }
    
    public func timeRemainingAtPosition(_ position:Double) -> TimeInterval {
        return length * (1.0 - TimeInterval(position))
    }
    
    func timeStringsAtPosition(_ position:Double) -> (elapsed:String, remaining:String) {
        var position = position
        if position.isNaN || position.isInfinite { position = 0 }
        var length = self.length
        if length.isNaN || length.isInfinite { length = 0 }
        let secondsElapsed = length * position
        let secondsRemaining = length * (1.0 - position)
        return (timeIntervalDisplayValue(seconds: Int(secondsElapsed)), timeIntervalDisplayValue(seconds: Int(secondsRemaining)))
    }

}

public struct AdBreak {
    public init(location: Double) {
        self.location = location
    }
    
    // value between 0 and 1 indicating the position of the ad break.
    var location: Double
}

//
//  Created by Bart Whiteley on 1/8/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//
