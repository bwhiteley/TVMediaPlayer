import Foundation
import TVMediaPlayer
import AVFoundation

class TestMediaPlayer: MediaPlayerType, MediaItemType {
    
    lazy var playerItem:AVPlayerItem = {
        let url = URL(string: "https://cdn.theoplayer.com/video/big_buck_bunny/big_buck_bunny.m3u8")!
        return AVPlayerItem(url: url)
    }()
    
    lazy var player:AVPlayer = {
        let player = AVPlayer(playerItem: self.playerItem)
        player.addPeriodicTimeObserver(forInterval: CMTime(value: 10, timescale: 1000), queue: nil) { [weak self] time in
            guard let sself = self else { return }
            let position = time.seconds / sself.length
            sself.positionChanged?(position)
        }
        return player
    }()
    
    var item:MediaItemType { return self }
    
    var positionChanged:((_ position:Double) -> Void)?
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func stop() {
        player.pause()
    }
    
    var rate:Double {
        get {
            return Double(player.rate)
        }
        set {
            player.rate = Float(newValue)
        }
    }
        
    var position:Double {
        get {
            return player.currentTime().seconds / playerItem.duration.seconds
        }
        set {
            let scale:Int32 = 1000
            let micro = Int64(Double(newValue) * playerItem.duration.seconds * Double(scale))
            let time = CMTime(value: micro, timescale: scale)
            player.seek(to: time)
        }
    }
    
    var title:String { return "Title" }
    
    var subtitle:String? { return "Subtitle" }
    
    var length:Double { return playerItem.duration.seconds }
}

//
//  Created by Bart Whiteley on 1/9/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//
