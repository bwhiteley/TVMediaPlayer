//
//  ControlsOverlayCustomization.swift
//

import UIKit

public struct ControlsOverlayCustomization {
    public init(textColor: UIColor, brandLogo: UIImage?, titleFont: UIFont, subtitleFont: UIFont, adSecondsRemainingString: @escaping (Int) -> NSAttributedString) {
        self.textColor = textColor
        self.brandLogo = brandLogo
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
        self.adSecondsRemainingString = adSecondsRemainingString
    }
    
    public var textColor: UIColor
    public var brandLogo: UIImage?
    public var titleFont: UIFont
    public var subtitleFont: UIFont
    public var adSecondsRemainingString: (Int) -> NSAttributedString
    
    public static let `default` = ControlsOverlayCustomization(
        textColor: .white,
        brandLogo: nil,
        titleFont: .systemFont(ofSize: 32),
        subtitleFont: .systemFont(ofSize: 24),
        adSecondsRemainingString: { seconds in
            let str = "Your program resumes in \(seconds) sec"
            return NSAttributedString(string: str, attributes: [
                NSAttributedString.Key.foregroundColor: UIColor.white,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 24),
            ])
        })
}
