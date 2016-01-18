import Foundation
import TVMediaPlayer
import AVFoundation

class TestMediaPlayer: MediaPlayerType, MediaItemType {
    
    lazy var playerItem:AVPlayerItem = {
        let url = NSURL(string: "https://bennugd-vlc.googlecode.com/files/sintel_trailer-480p.mp4")!
        return AVPlayerItem(URL: url)
    }()
    
    lazy var player:AVPlayer = {
        let player = AVPlayer(playerItem: self.playerItem)
        player.addPeriodicTimeObserverForInterval(CMTime(value: 100, timescale: 1000), queue: nil) { [weak self] time in
            guard let sself = self else { return }
            let position = time.seconds / sself.length
            sself.positionChanged?(position: Float(position))
        }
        return player
    }()
    
    var positionChanged:((position:Float) -> Void)?
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func stop() {
        player.pause()
    }
    
    var rate:Float {
        get {
            return player.rate
        }
        set {
            player.rate = newValue
        }
    }
        
    var position:Float {
        get {
            return Float(player.currentTime().seconds / playerItem.duration.seconds)
        }
        set {
            let scale:Int32 = 1000
            let micro = Int64(Double(newValue) * playerItem.duration.seconds * Double(scale))
            let time = CMTime(value: micro, timescale: scale)
            player.seekToTime(time)
        }
    }
    
    var title:String { return "Title" }
    
    var subtitle:String? { return "Subtitle" }
    
    var length:NSTimeInterval { return playerItem.duration.seconds }
}

//
//  Created by Bart Whiteley on 1/9/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//
