//
//  ControlsOverlayViewController.swift
//  MythTV
//
//  Created by J. B. Whiteley on 10/6/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//

import UIKit

public protocol MediaPlayerThumbnailHandler: NSObjectProtocol {
    func snapshotImage(image:UIImage, forPosition position:Float)
}

public protocol MediaPlayerThumbnailSnapshotDelegate: NSObjectProtocol {
    func snapshotImageAtPosition(position:Float, size:CGSize, handler:MediaPlayerThumbnailHandler)
}

public class ControlsOverlayViewController: UIViewController {
    
    class func viewControllerFromStoryboard(mediaItem mediaItem:MediaItemType) -> ControlsOverlayViewController {
        let vc = UIStoryboard(name: "ControlsOverlay", bundle: NSBundle(forClass: self)).instantiateViewControllerWithIdentifier("controls") as! ControlsOverlayViewController
        vc.mediaItem = mediaItem
        return vc
    }
    
    enum ControlsState {
        case Hidden
        case Snapshot
        case FastForward
        case Rewind
        case SkipForward
        case SkipBack
        case Touches
    }
    
    public weak var delegate: MediaPlayerThumbnailSnapshotDelegate?
    
    private var mediaItem:MediaItemType?
    
    @IBOutlet var headerView: UIView!
    @IBOutlet var footerView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var sizeLabel: UILabel?

    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var timeElapsedLabel: UILabel!
    @IBOutlet var timeRemainingLabel: UILabel!
    @IBOutlet var snapshotImageView: UIImageView?
    @IBOutlet var thumbnailStackXConstraint: NSLayoutConstraint!
    @IBOutlet var lineView: UIVisualEffectView!
    @IBOutlet var thumbnailContainer: UIVisualEffectView!
    @IBOutlet var fastForwardAndRewindLabel: UILabel!
    @IBOutlet var skipForwardIcon: UIView!
    @IBOutlet var skipBackIcon: UIView!
    
    @IBOutlet var snapshotImageHeightConstraint: NSLayoutConstraint!
    
    private var temporaryDisplayToken:NSDate?
    
    private var headerAndFooterElements:[UIView?] = []
    
    private var touching:Bool = false // This is used because `touchesEnded` is called before the last DPad state change.
    
    func setSnapshotViewsHidden(hidden:Bool, animated:Bool = false, completion:(() -> Void)? = nil) {
        if animated && thumbnailContainer.hidden != hidden {
            let origHeightConstant = self.snapshotImageHeightConstraint.constant
            if hidden {
                self.controlsOverlayView?.layoutIfNeeded()
                UIView.animateWithDuration(0.3, delay: 0, options: .CurveEaseInOut, animations: {
                    self.snapshotImageHeightConstraint.constant = 1
                    self.controlsOverlayView?.layoutIfNeeded()
                    }, completion: { success in
                        guard success else { return }
                        self.thumbnailContainer.hidden = true
                        self.lineView.hidden = true
                        self.snapshotImageHeightConstraint.constant = origHeightConstant
                        completion?()
                })
            }
            else {
                self.snapshotImageHeightConstraint.constant = 1
                self.controlsOverlayView?.layoutIfNeeded()
                self.thumbnailContainer.hidden = false
                self.lineView.hidden = false
                UIView.animateWithDuration(0.3, delay: 0, options: .CurveEaseInOut, animations: {
                    self.snapshotImageHeightConstraint.constant = origHeightConstant
                    self.controlsOverlayView?.layoutIfNeeded()
                    }, completion: { success in
                        guard success else { return }
                        completion?()
                })
            }
        }
        else {
            self.thumbnailContainer.hidden = hidden
            self.lineView.hidden = hidden
            completion?()
        }
    }
    
    func setHeaderAndFooterElementsHidden(hidden:Bool, animated:Bool = false, completion:(() -> Void)? = nil) {
        if animated && progressView.hidden != hidden {
            if hidden {
                UIView.animateWithDuration(0.3, animations: {
                    self.headerAndFooterElements.forEach { $0?.alpha = 0 }
                }, completion: { success in
                    //guard success else { return }
                    self.headerAndFooterElements.forEach {
                        $0?.alpha = 0
                        $0?.hidden = true
                        //guard success else { return }
                        completion?()
                    }
                })
            }
            else {
                self.headerAndFooterElements.forEach {
                    $0?.alpha = 0
                    $0?.hidden = false
                }
                UIView.animateWithDuration(0.3, animations: {
                    self.headerAndFooterElements.forEach { $0?.alpha = 1 }
                }, completion: { success in
                    //guard success else { return }
                    completion?()
                })
            }
        }
        else {
            self.headerAndFooterElements.forEach { $0?.hidden = hidden }
            completion?()
        }
    }
    
    var controlsState:ControlsState = .Hidden {
        didSet {
            switch controlsState {
            case .Hidden:
                setSnapshotViewsHidden(true, animated: true) {
                    self.setHeaderAndFooterElementsHidden(true, animated: true) {
                        self.view.hidden = true
                    }
                }
                fastForwardAndRewindLabel.hidden = true
                skipBackIcon.hidden = true
                skipForwardIcon.hidden = true
            case .Snapshot:
                self.view.hidden = false
                setHeaderAndFooterElementsHidden(false, animated: true)
                setSnapshotViewsHidden(false, animated: true)
                fastForwardAndRewindLabel.hidden = true
                skipBackIcon.hidden = true
                skipForwardIcon.hidden = true
            case .FastForward, .Rewind:
                view.hidden = false
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.hidden = false
                skipBackIcon.hidden = true
                skipForwardIcon.hidden = true
            case .SkipBack:
                view.hidden = false
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.hidden = true
                skipBackIcon.hidden = false
                skipForwardIcon.hidden = true
            case .SkipForward:
                view.hidden = false
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.hidden = true
                skipBackIcon.hidden = true
                skipForwardIcon.hidden = false
                timeRemainingLabel.hidden = determineTimeRemainingLabelHidden()
            case .Touches:
                view.hidden = false
                setHeaderAndFooterElementsHidden(false, animated: true)
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.hidden = true
                skipBackIcon.hidden = true
                skipForwardIcon.hidden = true
            }
        }
    }
    
    public var videoSize:CGSize? = nil {
        didSet {
            guard let size = videoSize where size.height > 0 else {
                sizeLabel?.text = nil
                return
            }
            self.sizeLabel?.text = "\(Int(size.width))x\(Int(size.height))"
        }
    }
    
    var playerState:PlayerState = .StandardPlay {
        didSet {
            switch playerState {
            case .StandardPlay:
                controlsState = .Hidden
            case .Pause:
                controlsState = .Snapshot
            case let .Fastforward(rate):
                controlsState = .FastForward
                fastForward(rate)
            default:
                break
            }
        }
    }
    
    func touchesBegan() {
        touching = true
        if controlsState == .Hidden {
            controlsState = .Touches
        }
    }
    
    func touchesEnded() {
        touching = false
        switch controlsState {
        case .Touches, .SkipForward, .SkipBack:
            controlsState = .Hidden
        default:
            break
        }
    }
    
    var dpadState:DPadState = .Select {
        didSet {
            guard touching else { return } // this is called after `touchesEnded`
            switch playerState {
            case .StandardPlay:
                break
            case .Fastforward(let rate) where rate < 2:
                break
            default:
                return
            }
            
            switch dpadState {
            case .Right:
                controlsState = .SkipForward
            case .Left:
                controlsState = .SkipBack
            default:
                controlsState = .Touches
            }
        }
    }

    func fastForward(rate:Float) {
        let rateStr:String
        if rate == Float(Int(rate)) {
            rateStr = "\(Int(rate))"
        }
        else {
            rateStr = "\(rate)"
        }
        fastForwardAndRewindLabel.text = "»\(rateStr)x"
        fastForwardAndRewindLabel.hidden = false
        thumbnailContainer?.hidden = true
        
        if rate < 2.0 {
            let token = NSDate()
            temporaryDisplayToken = token
            delay(4) { [weak self] in
                guard let sself = self else { return }
                guard case let .Fastforward(newRate) = sself.playerState where newRate == rate else { return }
                guard sself.temporaryDisplayToken === token else { return }
                self?.controlsState = .Hidden
            }
        }
    }
    
    public var position:Float {
        get {
            return self.progressView.progress
        }
        set {
            var val = min(Float(1.0), newValue)
            val = max(Float(0), val)
            self.progressView.progress = val
            guard let rvm = mediaItem else { return }
            let (elapsed, remaining) = rvm.timeStringsAtPosition(val)
            timeElapsedLabel.text = elapsed
            timeRemainingLabel.text = "-" + remaining
            
            let x = CGFloat(position) * progressView.frame.width
            self.thumbnailStackXConstraint.constant = x
            
            timeRemainingLabel?.hidden = determineTimeRemainingLabelHidden()
            
            guard let snapShotSize = snapshotImageView?.frame.size else { return }
            
            if case .Pause = playerState {
                delegate?.snapshotImageAtPosition(newValue, size:snapShotSize, handler: self)
            }
        }
    }
    
    func determineTimeRemainingLabelHidden() -> Bool {
        guard case .SkipForward = controlsState else {
            return progressView?.hidden ?? true
        }
        guard let timeRemainingLabel = timeRemainingLabel,
            let skipForwardIcon = skipForwardIcon,
            let progressView = self.progressView else { return true }
        
        guard let timeRemainingFrame = skipForwardIcon.superview?.convertRect(timeRemainingLabel.bounds, fromView: timeRemainingLabel) else {
            return true
        }
        
        let framesIntersect = CGRectIntersectsRect(timeRemainingFrame, skipForwardIcon.frame)
        return progressView.hidden || (framesIntersect && !skipForwardIcon.hidden)
    }
    
    @IBOutlet var controlsOverlayView: UIView!
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.videoSize = nil
        
        self.titleLabel.text = mediaItem?.title
        self.subtitleLabel.text = mediaItem?.subtitle
        
        controlsState = .Hidden
        
        var gradient = CAGradientLayer()
        gradient.frame = headerView.bounds
        gradient.colors = [UIColor.blackColor().CGColor, UIColor.clearColor().CGColor]
        headerView.layer.insertSublayer(gradient, atIndex: 0)
        
        gradient = CAGradientLayer()
        gradient.frame = footerView.bounds
        gradient.colors = [UIColor.clearColor().CGColor, UIColor.blackColor().CGColor]
        footerView.layer.insertSublayer(gradient, atIndex: 0)
        
        headerAndFooterElements = [titleLabel, subtitleLabel, sizeLabel,
            progressView, timeRemainingLabel, timeElapsedLabel,
            headerView, footerView
        ]
    }
    
    func flashTimeBar() {
        guard controlsState == .Hidden else { return }
        controlsState = .Touches
        let token = NSDate()
        temporaryDisplayToken = token
        delay(4) { [weak self] in
            if self?.temporaryDisplayToken === token {
                self?.controlsState = .Hidden
            }
        }
    }
}

extension ControlsOverlayViewController: MediaPlayerThumbnailHandler {
    public func snapshotImage(image:UIImage, forPosition position:Float) {
        self.snapshotImageView?.image = image
    }
}

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}


