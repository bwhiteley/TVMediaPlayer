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

    @IBAction func playClicked(sender: AnyObject) {
        let vc = TestPlayerViewController()
        self.presentViewController(vc, animated: true, completion: nil)
    }

    @IBAction func controlClicked(sender: AnyObject) {
        let url = NSURL(string: "https://bennugd-vlc.googlecode.com/files/sintel_trailer-480p.mp4")!
        let vc = AVPlayerViewController()
        vc.player = AVPlayer(URL: url)
        self.presentViewController(vc, animated: true, completion: nil)
        vc.player?.play()
    }
    
}

//
//  Created by Bart Whiteley on 1/9/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//
