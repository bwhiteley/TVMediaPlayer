//
//  ScrubberButton.swift
//
//  Created by Bart Whiteley on 12/28/22.
//

import UIKit

class ScrubberButton: UIButton {
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if context.nextFocusedItem === self {
            backgroundColor = tintColor
            imageView?.isHidden = true
        } else {
            backgroundColor = .clear
            imageView?.isHidden = false
        }
    }
}
