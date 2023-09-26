
enum PlayerState {
    case standardPlay
    case pause
    case rewind(rate:Double)
    case fastforward(rate:Double)
    
    func nextFasterState() -> PlayerState? {
        switch self {
        case .standardPlay, .pause:
            guard let newRate = PlayerState.fastforwardRates.first else {
                return nil
            }
            return .fastforward(rate: newRate)
        case let .fastforward(rate):
            if let index = PlayerState.fastforwardRates.firstIndex(of: rate) , index + 1 < PlayerState.fastforwardRates.count {
                return .fastforward(rate: PlayerState.fastforwardRates[index + 1])
            }
            return nil
        case let .rewind(rate):
            if rate == PlayerState.rewindRates.first {
                return .standardPlay
            }
            if let index = PlayerState.rewindRates.firstIndex(of: rate) , index > 0 {
                return .rewind(rate: PlayerState.rewindRates[index - 1])
            }
            return nil
        }
    }
    
    func nextSlowerState() -> PlayerState? {
        switch self {
        case .standardPlay:
            guard let newRate = PlayerState.rewindRates.first else {
                return nil
            }
            return .rewind(rate: newRate)
        case let .rewind(rate):
            if let index = PlayerState.rewindRates.firstIndex(of: rate) , index + 1 < PlayerState.rewindRates.count {
                return .rewind(rate: PlayerState.rewindRates[index + 1])
            }
            return nil
        case let .fastforward(rate):
            if rate == PlayerState.fastforwardRates.first {
                return .standardPlay
            }
            if let index = PlayerState.fastforwardRates.firstIndex(of: rate) , index > 0 {
                return .fastforward(rate: PlayerState.fastforwardRates[index - 1])
            }
            return nil
        default:
            return nil
        }
    }
    
    fileprivate static let rewindRates:[Double] = [1, 2, 3, 4]
    fileprivate static let fastforwardRates:[Double] = [1, 2, 3, 4]
}

//
//  Created by Bart Whiteley on 10/25/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//
