import UIKit

internal class ControlsOverlayViewController: UIViewController {
    
    class func viewControllerFromStoryboard(mediaItem:MediaItemType) -> ControlsOverlayViewController {
        let vc = UIStoryboard(name: "ControlsOverlay", bundle: Bundle.module).instantiateViewController(withIdentifier: "controls") as! ControlsOverlayViewController
        vc.mediaItem = mediaItem
        return vc
    }
    
    enum ControlsState {
        case hidden
        case snapshot
        case fastForward
        case rewind
        case skipForward
        case skipBack
        case touches
    }
    
    internal weak var delegate: MediaPlayerThumbnailSnapshotDelegate?
    
    internal var wideMargins = true
    
    fileprivate var mediaItem:MediaItemType!
    
    @IBOutlet var headerView: UIView!
    @IBOutlet var footerView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!

    @IBOutlet var progressView: UIVisualEffectView! {
        didSet {
            progressView.layer.masksToBounds = true
            progressView.layer.cornerRadius = progressView.frame.height / 2
        }
    }
    @IBOutlet var timeElapsedLabel: UILabel!
    @IBOutlet var timeRemainingLabel: UILabel!
    @IBOutlet var snapshotImageView: UIImageView?
    @IBOutlet var thumbnailStackXConstraint: NSLayoutConstraint!
    @IBOutlet var lineView: UIView!
    @IBOutlet var thumbnailContainer: UIVisualEffectView!
    @IBOutlet var fastForwardAndRewindLabel: UILabel!
    @IBOutlet var skipForwardIcon: UIView!
    @IBOutlet var skipBackIcon: UIView!
    
    @IBOutlet var snapshotImageHeightConstraint: NSLayoutConstraint!
    @IBOutlet var progressLineHeightConstraint: NSLayoutConstraint!
    @IBOutlet var progressLineBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet var horizontalMarginConstraints: [NSLayoutConstraint]!
    @IBOutlet var verticalMarginConstraints: [NSLayoutConstraint]!
    
    private let adBreakContainer = UIView()
    
    fileprivate var temporaryDisplayToken:Date?
    
    fileprivate var headerAndFooterElements:[UIView?] = []
    
    fileprivate var touching:Bool = false // This is used because `touchesEnded` is called before the last DPad state change.
    
    func setSnapshotViewsHidden(_ hidden:Bool, animated:Bool = false, completion:(() -> Void)? = nil) {
        if animated && thumbnailContainer.isHidden != hidden && delegate != nil {
            let origHeightConstant = self.snapshotImageHeightConstraint.constant
            if hidden {
                self.controlsOverlayView?.layoutIfNeeded()
                UIView.animate(withDuration: 0.3, delay: 0, options: UIView.AnimationOptions(), animations: {
                    defer { self.controlsOverlayView?.layoutIfNeeded() }
                    self.snapshotImageHeightConstraint.constant = 1
                    self.progressLineBottomConstraint.constant = -6
                    self.progressLineHeightConstraint.constant = 22
                    }, completion: { success in
                        guard success else { return }
                        self.thumbnailContainer.isHidden = true
                        self.snapshotImageHeightConstraint.constant = origHeightConstant
                        completion?()
                })
            }
            else {
                self.snapshotImageHeightConstraint.constant = 1
                self.controlsOverlayView?.layoutIfNeeded()
                self.thumbnailContainer.isHidden = false
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                    defer { self.controlsOverlayView?.layoutIfNeeded() }
                    self.snapshotImageHeightConstraint.constant = origHeightConstant
                    self.progressLineBottomConstraint.constant = 0
                    self.progressLineHeightConstraint.constant = 32
                    }, completion: { success in
                        guard success else { return }
                        completion?()
                })
            }
        }
        else {
            let hideViews = hidden || delegate == nil
            self.thumbnailContainer.isHidden = hideViews
            self.progressLineBottomConstraint.constant = hideViews ? -6 : 0
            self.progressLineHeightConstraint.constant = hideViews ? 22 : 32
            completion?()
        }
    }
    
    func setHeaderAndFooterElementsHidden(_ hidden:Bool, animated:Bool = false, completion:(() -> Void)? = nil) {
        if animated && progressView.isHidden != hidden {
            if hidden {
                UIView.animate(withDuration: 0.3, animations: {
                    self.headerAndFooterElements.forEach { $0?.alpha = 0 }
                }, completion: { _ in
                    self.headerAndFooterElements.forEach {
                        $0?.alpha = 0
                        $0?.isHidden = true
                        completion?()
                    }
                })
            }
            else {
                self.headerAndFooterElements.forEach {
                    $0?.alpha = 0
                    $0?.isHidden = false
                }
                UIView.animate(withDuration: 0.3, animations: {
                    self.headerAndFooterElements.forEach { $0?.alpha = 1 }
                }, completion: { _ in
                    completion?()
                })
            }
        }
        else {
            self.headerAndFooterElements.forEach { $0?.isHidden = hidden }
            completion?()
        }
    }
    
    var controlsState:ControlsState = .hidden {
        didSet {
            switch controlsState {
            case .hidden:
                setSnapshotViewsHidden(true, animated: true) {
                    self.setHeaderAndFooterElementsHidden(true, animated: true) {
                        self.view.isHidden = true
                    }
                }
                fastForwardAndRewindLabel.isHidden = true
                skipBackIcon.isHidden = true
                skipForwardIcon.isHidden = true
            case .snapshot:
                self.view.isHidden = false
                setHeaderAndFooterElementsHidden(false, animated: true)
                setSnapshotViewsHidden(false, animated: true)
                fastForwardAndRewindLabel.isHidden = true
                skipBackIcon.isHidden = true
                skipForwardIcon.isHidden = true
            case .fastForward, .rewind:
                view.isHidden = false
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.isHidden = false
                skipBackIcon.isHidden = true
                skipForwardIcon.isHidden = true
            case .skipBack:
                view.isHidden = false
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.isHidden = true
                skipBackIcon.isHidden = false
                skipForwardIcon.isHidden = true
            case .skipForward:
                view.isHidden = false
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.isHidden = true
                skipBackIcon.isHidden = true
                skipForwardIcon.isHidden = false
                timeRemainingLabel.isHidden = determineTimeRemainingLabelHidden()
            case .touches:
                view.isHidden = false
                setHeaderAndFooterElementsHidden(false, animated: true)
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.isHidden = true
                skipBackIcon.isHidden = true
                skipForwardIcon.isHidden = true
            }
        }
    }
    
    var playerState:PlayerState = .standardPlay {
        didSet {
            switch playerState {
            case .standardPlay:
                controlsState = .hidden
            case .pause:
                controlsState = .snapshot
            case let .fastforward(rate):
                controlsState = .fastForward
                fastForward(rate)
            default:
                break
            }
        }
    }
    
    func touchesBegan() {
        touching = true
        if controlsState == .hidden {
            controlsState = .touches
        }
    }
    
    func touchesEnded() {
        touching = false
        switch controlsState {
        case .touches, .skipForward, .skipBack:
            controlsState = .hidden
        default:
            break
        }
    }
    
    var dpadState:DPadState = .select {
        didSet {
            guard touching else { return } // this is called after `touchesEnded`
            switch playerState {
            case .standardPlay:
                break
            case .fastforward(let rate) where rate <= 2:
                break
            default:
                return
            }
            
            switch dpadState {
            case .right:
                controlsState = .skipForward
            case .left:
                controlsState = .skipBack
            default:
                controlsState = .touches
            }
        }
    }

    func fastForward(_ rate:Double) {
        let rateStr:String
        if rate == Double(Int(rate)) {
            rateStr = "\(Int(rate))"
        }
        else {
            rateStr = "\(rate)"
        }
        fastForwardAndRewindLabel.text = "»\(rateStr)x"
        fastForwardAndRewindLabel.isHidden = false
        thumbnailContainer?.isHidden = true
        
        if rate <= 2.0 {
            let token = Date()
            temporaryDisplayToken = token
            delay(4) { [weak self] in
                guard let sself = self else { return }
                guard case let .fastforward(newRate) = sself.playerState , newRate == rate else { return }
                guard sself.temporaryDisplayToken == token else { return }
                self?.controlsState = .hidden
            }
        }
    }
    
    internal var position:Double = 0 {
        didSet {
            var val = min(Double(1.0), position)
            val = max(Double(0), val)
            self.position = val
            guard let rvm = mediaItem else { return }
            guard progressView != nil else { return }
            let (elapsed, remaining) = rvm.timeStringsAtPosition(val)
            timeElapsedLabel?.text = elapsed
            timeRemainingLabel?.text = "-" + remaining
            
            let x = CGFloat(position) * progressView.frame.width
            self.thumbnailStackXConstraint.constant = x
            
            timeRemainingLabel?.isHidden = determineTimeRemainingLabelHidden()
            
            guard let snapShotSize = snapshotImageView?.frame.size else { return }
            
            if case .pause = playerState {
                delegate?.snapshotImageAtPosition(position, size:snapShotSize, handler: self)
            }
        }
    }
    
    func determineTimeRemainingLabelHidden() -> Bool {
        guard case .skipForward = controlsState else {
            return progressView?.isHidden ?? true
        }
        guard let timeRemainingLabel = timeRemainingLabel,
            let skipForwardIcon = skipForwardIcon,
            let progressView = self.progressView else { return true }
        
        guard let timeRemainingFrame = skipForwardIcon.superview?.convert(timeRemainingLabel.bounds, from: timeRemainingLabel) else {
            return true
        }
        
        let framesIntersect = timeRemainingFrame.intersects(skipForwardIcon.frame)
        return progressView.isHidden || (framesIntersect && !skipForwardIcon.isHidden)
    }
    
    @IBOutlet var controlsOverlayView: UIView!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        self.titleLabel.text = mediaItem?.title
        self.subtitleLabel.text = mediaItem?.subtitle
        
        controlsState = .hidden
        
        var gradient = CAGradientLayer()
        gradient.frame = headerView.bounds
        gradient.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
        headerView.layer.insertSublayer(gradient, at: 0)
        
        gradient = CAGradientLayer()
        gradient.frame = footerView.bounds
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        footerView.layer.insertSublayer(gradient, at: 0)
        
        // These aren't subviews of the footer, so we have to adjust them individually. 
        // We should probably fix that sometime.
        headerAndFooterElements = [titleLabel, subtitleLabel,
            progressView, timeRemainingLabel, timeElapsedLabel,
            headerView, footerView, lineView, adBreakContainer
        ]
        
        if !wideMargins {
            horizontalMarginConstraints.forEach {
                $0.constant = 45
            }
            verticalMarginConstraints.forEach {
                $0.constant = 30
            }
        }
        
        adBreakContainer.frame = progressView.frame
        adBreakContainer.backgroundColor = .clear
        progressView.superview?.addSubview(adBreakContainer)
        
        Task { @MainActor in
            do {
                for ad in try await mediaItem.adBreaks() {
                    let view = UIView()
                    let x: CGFloat = progressView.bounds.width * ad.location
                    view.frame = .init(x: x - 2, y: -5, width: 4, height: 20)
                    view.backgroundColor = UIColor(white: CGFloat(235) / CGFloat(255), alpha: 1)
                    adBreakContainer.addSubview(view)
                    view.layer.cornerRadius = 2
                    view.clipsToBounds = true
                }
            } catch {
                
            }
        }
    }
    
    func flashTimeBar() {
        guard controlsState == .hidden else { return }
        controlsState = .touches
        let token = Date()
        temporaryDisplayToken = token
        delay(4) { [weak self] in
            if self?.temporaryDisplayToken == token {
                self?.controlsState = .hidden
            }
        }
    }
}

extension ControlsOverlayViewController: MediaPlayerThumbnailHandler {
    internal func setSnapshotImage(_ image:UIImage, forPosition position:Float) {
        self.snapshotImageView?.image = image
    }
}

private func delay(_ delay:Double, closure:@escaping ()->()) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

//
//  Created by Bart Whiteley on 10/6/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//
