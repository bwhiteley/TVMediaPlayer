//
//  ViewController.swift
//  TVMediaPlayerTestApp
//
//  Created by J. B. Whiteley on 1/9/16.
//  Copyright © 2016 SwiftBit. All rights reserved.
//

import UIKit

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

}

