import UIKit
import TVMediaPlayer
import AVFoundation

class TestPlayerViewController:MediaPlayerViewController {
    let testMediaPlayer = TestMediaPlayer()
    
    init() {
        super.init(mediaPlayer: testMediaPlayer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let playerLayer = AVPlayerLayer(player: self.testMediaPlayer.player)
        playerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        playerLayer.frame = canvasView.bounds
        self.canvasView.layer.addSublayer(playerLayer)
    }
}

//
//  Created by Bart Whiteley on 1/9/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//
