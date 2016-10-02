
enum PlayerState {
    case standardPlay
    case pause
    case rewind(rate:Float)
    case fastforward(rate:Float)
    
    func nextFasterState() -> PlayerState? {
        switch self {
        case .standardPlay:
            guard let newRate = PlayerState.fastforwardRates.first else {
                return nil
            }
            return .fastforward(rate: newRate)
        case let .fastforward(rate):
            if let index = PlayerState.fastforwardRates.index(of: rate) , index + 1 < PlayerState.fastforwardRates.count {
                return .fastforward(rate: PlayerState.fastforwardRates[index + 1])
            }
            return nil
        case let .rewind(rate):
            if rate == PlayerState.rewindRates.first {
                return .standardPlay
            }
            if let index = PlayerState.rewindRates.index(of: rate) , index > 0 {
                return .rewind(rate: PlayerState.rewindRates[index - 1])
            }
            return nil
        default:
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
            if let index = PlayerState.rewindRates.index(of: rate) , index + 1 < PlayerState.rewindRates.count {
                return .rewind(rate: PlayerState.rewindRates[index + 1])
            }
            return nil
        case let .fastforward(rate):
            if rate == PlayerState.fastforwardRates.first {
                return .standardPlay
            }
            if let index = PlayerState.fastforwardRates.index(of: rate) , index > 0 {
                return .fastforward(rate: PlayerState.fastforwardRates[index - 1])
            }
            return nil
        default:
            return nil
        }
    }
    
    fileprivate static let rewindRates:[Float] = [] // Doesn't seem to work in VLC. [2, 4, 8, 16]
    fileprivate static let fastforwardRates:[Float] = [1.3, 2, 4, 6]
}

//
//  Created by Bart Whiteley on 10/25/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//
