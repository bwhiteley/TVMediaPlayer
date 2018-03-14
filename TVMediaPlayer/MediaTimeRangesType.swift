import Foundation
import CoreMedia

public protocol MediaTimeRangesType {

    func containsTime(_ time: CMTime) -> CMTimeRange?

    /// The list of ranges
    var ranges:[CMTimeRange] { get }
}

public extension MediaTimeRangesType {
    func containsTime(_ time: CMTime) -> CMTimeRange? {
        for range in ranges {
            if (range.containsTime(time)) {
                return range
            }
        }
        return nil
    }
}

//
//  Created by Martin Glass on 13-Mar-18.
//  Copyright © 2018 SwiftBit. All rights reserved.
//
