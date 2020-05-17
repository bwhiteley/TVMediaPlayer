import UIKit
import AVKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func playClicked(_ sender: AnyObject) {
        let vc = TestPlayerViewController()
        self.present(vc, animated: true, completion: nil)
    }

    @IBAction func controlClicked(_ sender: AnyObject) {
        let url = URL(string: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_30MB.mp4")!
        let vc = AVPlayerViewController()
        vc.player = AVPlayer(url: url)
        self.present(vc, animated: true, completion: nil)
        vc.player?.play()
    }
    
}

//
//  Created by Bart Whiteley on 1/9/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//
