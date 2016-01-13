//
//  PlayerState.swift
//  MythTV
//
//  Created by Bart Whiteley on 10/25/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//

import Foundation

enum PlayerState {
    case StandardPlay
    case Pause
    case Rewind(rate:Float)
    case Fastforward(rate:Float)
    
    func nextFasterState() -> PlayerState? {
        switch self {
        case .StandardPlay:
            guard let newRate = PlayerState.fastforwardRates.first else {
                return nil
            }
            return .Fastforward(rate: newRate)
        case let .Fastforward(rate):
            if let index = PlayerState.fastforwardRates.indexOf(rate) where index + 1 < PlayerState.fastforwardRates.count {
                return .Fastforward(rate: PlayerState.fastforwardRates[index + 1])
            }
            return nil
        case let .Rewind(rate):
            if rate == PlayerState.rewindRates.first {
                return .StandardPlay
            }
            if let index = PlayerState.rewindRates.indexOf(rate) where index > 0 {
                return .Rewind(rate: PlayerState.rewindRates[index - 1])
            }
            return nil
        default:
            return nil
        }
    }
    
    func nextSlowerState() -> PlayerState? {
        switch self {
        case .StandardPlay:
            guard let newRate = PlayerState.rewindRates.first else {
                return nil
            }
            return .Rewind(rate: newRate)
        case let .Rewind(rate):
            if let index = PlayerState.rewindRates.indexOf(rate) where index + 1 < PlayerState.rewindRates.count {
                return .Rewind(rate: PlayerState.rewindRates[index + 1])
            }
            return nil
        case let .Fastforward(rate):
            if rate == PlayerState.fastforwardRates.first {
                return .StandardPlay
            }
            if let index = PlayerState.fastforwardRates.indexOf(rate) where index > 0 {
                return .Fastforward(rate: PlayerState.fastforwardRates[index - 1])
            }
            return nil
        default:
            return nil
        }
    }
    
    private static let rewindRates:[Float] = [] // Doesn't seem to work in VLC. [2, 4, 8, 16]
    private static let fastforwardRates:[Float] = [1.3, 2, 4, 6]
}
