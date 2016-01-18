import Foundation

public protocol MediaItemType {
    var title:String { get }
    var subtitle:String? { get }
    var length:NSTimeInterval { get }
}

extension MediaItemType {
    private func timeIntervalDisplayValue(seconds interval:Int) -> String {
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
    
    public func timeRemainingAtPosition(position:Float) -> NSTimeInterval {
        return length * (1.0 - NSTimeInterval(position))
    }
    
    func timeStringsAtPosition(var position:Float) -> (elapsed:String, remaining:String) {
        if isnan(position) || isinf(position) { position = 0 }
        var length:Float = Float(self.length)
        if isnan(length) || isinf(length) { length = 0 }
        let secondsElapsed = length * position
        let secondsRemaining = length * (1.0 - position)
        return (timeIntervalDisplayValue(seconds: Int(secondsElapsed)), timeIntervalDisplayValue(seconds: Int(secondsRemaining)))
    }

}

//
//  Created by Bart Whiteley on 1/8/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//
