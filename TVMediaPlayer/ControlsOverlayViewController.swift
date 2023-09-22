import UIKit

protocol ControlsOverlayViewControllerDelegate: AnyObject {
    func scrubberButtonTapped()
}

internal class ControlsOverlayViewController: UIViewController {
    
    class func viewControllerFromStoryboard(mediaItem:MediaItemType, controlsCustomization: ControlsOverlayCustomization) -> ControlsOverlayViewController {
        let vc = UIStoryboard(name: "ControlsOverlay", bundle: Bundle.module).instantiateViewController(withIdentifier: "controls") as! ControlsOverlayViewController
        vc.mediaItem = mediaItem
        vc.controlsCustomization = controlsCustomization
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
    
    internal weak var delegate: ControlsOverlayViewControllerDelegate?
    internal weak var thumbnailDelegate: MediaPlayerThumbnailSnapshotDelegate?
    
    internal var wideMargins = true
    
    fileprivate var mediaItem:MediaItemType!
    
    var controlsCustomization: ControlsOverlayCustomization!
    
    @IBOutlet var headerView: UIView!
    @IBOutlet var footerView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var adTimeRemainingLabel: UILabel!
    @IBOutlet var brandLogoImageView: UIImageView!
    
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
    @IBOutlet var lineView: ScrubberButton!
    @IBOutlet var thumbnailContainer: UIVisualEffectView!
    @IBOutlet var fastForwardAndRewindLabel: UILabel!
    @IBOutlet var skipForwardIcon: UIView!
    @IBOutlet var skipBackIcon: UIView!
    
    @IBOutlet var snapshotImageHeightConstraint: NSLayoutConstraint!
    @IBOutlet var progressLineHeightConstraint: NSLayoutConstraint!
    @IBOutlet var progressLineWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet var horizontalMarginConstraints: [NSLayoutConstraint]!
    @IBOutlet var verticalMarginConstraints: [NSLayoutConstraint]!
    
    private let adBreakContainer = UIView()
    
    fileprivate var temporaryDisplayToken:Date?
    
    internal let headerCustomContentView = UIView()
    
    private let progressViewFocusGuide = UIFocusGuide()
    private let topFocusGuide = UIFocusGuide()
    
    fileprivate var headerAndFooterElements:[UIView?] = []
    
    fileprivate var touching:Bool = false // This is used because `touchesEnded` is called before the last DPad state change.
    
    private func customizeUI() {
        brandLogoImageView.image = controlsCustomization.brandLogo
        titleLabel.font = controlsCustomization.titleFont
        titleLabel.textColor = controlsCustomization.textColor
        subtitleLabel.font = controlsCustomization.subtitleFont
        subtitleLabel.textColor = controlsCustomization.textColor
        lineView.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        lineView.layer.cornerRadius = 15
        lineView.layer.masksToBounds = true
        lineView.imageEdgeInsets = .init(top: 8, left: 8, bottom: 8, right: 8)
        lineView.tintColor = UIColor(red: 0, green: CGFloat(163) / CGFloat(255), blue: CGFloat(224) / CGFloat(255), alpha: 1)
    }
    
    
    func setSnapshotViewsHidden(_ hidden:Bool, animated:Bool = false, completion:(() -> Void)? = nil) {
        if animated && thumbnailContainer.isHidden != hidden && thumbnailDelegate != nil {
            let origHeightConstant = self.snapshotImageHeightConstraint.constant
            if hidden {
                self.controlsOverlayView?.layoutIfNeeded()
                UIView.animate(withDuration: 0.3, delay: 0, options: UIView.AnimationOptions(), animations: {
                    defer { self.controlsOverlayView?.layoutIfNeeded() }
                    self.snapshotImageHeightConstraint.constant = 1
                    self.progressLineHeightConstraint.constant = 30
                    self.progressLineWidthConstraint.constant = 30
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
                    self.progressLineHeightConstraint.constant = 30
                    self.progressLineWidthConstraint.constant = 30
                    }, completion: { success in
                        guard success else { return }
                        completion?()
                })
            }
        }
        else {
            let hideViews = hidden || thumbnailDelegate == nil
            self.thumbnailContainer.isHidden = hideViews
            self.progressLineHeightConstraint.constant = 30
            self.progressLineWidthConstraint.constant = 30
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
                self.headerCustomContentView.isHidden = true
                self.headerAndFooterElements.forEach {
                    $0?.alpha = 0.1
                    $0?.isHidden = false
                }
                self.setNeedsFocusUpdate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Delay appearance of custom header buttons, otherwise they
                    // tend to have focus instead of lineView. 
                    self.headerCustomContentView.isHidden = false
                }
                UIView.animate(withDuration: 0.3, animations: {
                    self.headerAndFooterElements.forEach { $0?.alpha = 1 }
                }, completion: { _ in
                    completion?()
                    self.setNeedsFocusUpdate()
                })
            }
        }
        else {
            self.headerAndFooterElements.forEach { $0?.isHidden = hidden }
            completion?()
            self.setNeedsFocusUpdate()
        }
    }
    
    var controlsState:ControlsState = .hidden {
        didSet {
            switch controlsState {
            case .hidden:
                setSnapshotViewsHidden(true, animated: true) {
                    self.setHeaderAndFooterElementsHidden(true, animated: true) {
                        self.controlsOverlayView.isHidden = true
                    }
                }
                fastForwardAndRewindLabel.isHidden = true
                skipBackIcon.isHidden = true
                skipForwardIcon.isHidden = true
            case .snapshot:
                self.controlsOverlayView.isHidden = false
                setHeaderAndFooterElementsHidden(false, animated: true)
                setSnapshotViewsHidden(false, animated: true)
                fastForwardAndRewindLabel.isHidden = true
                skipBackIcon.isHidden = true
                skipForwardIcon.isHidden = true
                controlsOverlayView.setNeedsFocusUpdate()
            case .fastForward, .rewind:
                controlsOverlayView.isHidden = false
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.isHidden = false
                skipBackIcon.isHidden = true
                skipForwardIcon.isHidden = true
            case .skipBack:
                controlsOverlayView.isHidden = false
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.isHidden = true
                skipBackIcon.isHidden = false
                skipForwardIcon.isHidden = true
            case .skipForward:
                controlsOverlayView.isHidden = false
                setSnapshotViewsHidden(true, animated: false)
                fastForwardAndRewindLabel.isHidden = true
                skipBackIcon.isHidden = true
                skipForwardIcon.isHidden = false
                timeRemainingLabel.isHidden = determineTimeRemainingLabelHidden()
            case .touches:
                controlsOverlayView.isHidden = false
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
            case let .rewind(rate):
                controlsState = .rewind
                //rewind(rate)
            default:
                break
            }
        }
    }
    
    func userInteractionOccurred() {
        touchTimer?.invalidate()
        touchTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: { [weak self] timer in
            self?.controlsState = .hidden
        })
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesBegan()
        super.touchesBegan(touches, with: event)
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded()
        super.touchesEnded(touches, with: event)
    }
    
    func touchesBegan() {
        touching = true
        touchTimer?.invalidate()
        if controlsState == .hidden {
            controlsState = .touches
        }
    }
    
    private var touchTimer: Timer?
    func touchesEnded() {
        touching = false
        switch controlsState {
        case .touches:
            touchTimer?.invalidate()
            touchTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: { [weak self] timer in
                self?.controlsState = .hidden
            })
        case .skipForward, .skipBack:
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
                thumbnailDelegate?.snapshotImageAtPosition(position, size:snapShotSize, handler: self)
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
    
    @IBOutlet private var controlsOverlayView: UIView!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        position = 0
        adTimeRemainingLabel.text = nil
        adTimeRemainingLabel.superview?.backgroundColor = .clear
        self.titleLabel.text = mediaItem?.title
        self.subtitleLabel.text = mediaItem?.subtitle
        
        //adTimeRemainingLabel.isHidden = true
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
        headerAndFooterElements = [lineView, footerView, progressView, titleLabel, subtitleLabel,
            timeRemainingLabel, timeElapsedLabel,
            headerView, adBreakContainer
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
        lineView.superview?.bringSubviewToFront(lineView)
        
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
        headerCustomContentView.backgroundColor = .clear
        headerCustomContentView.frame = headerView.bounds
        headerView.addSubview(headerCustomContentView)
        customizeUI()
        
        controlsOverlayView.addLayoutGuide(progressViewFocusGuide)
        NSLayoutConstraint.activate([
            progressViewFocusGuide.topAnchor.constraint(equalTo: progressView.topAnchor),
            progressViewFocusGuide.bottomAnchor.constraint(equalTo: progressView.bottomAnchor),
            progressViewFocusGuide.leadingAnchor.constraint(equalTo: progressView.leadingAnchor),
            progressViewFocusGuide.trailingAnchor.constraint(equalTo: progressView.trailingAnchor),
        ])
        progressViewFocusGuide.preferredFocusEnvironments = [lineView]
        
        controlsOverlayView.addLayoutGuide(topFocusGuide)
        NSLayoutConstraint.activate([
            topFocusGuide.topAnchor.constraint(equalTo: headerCustomContentView.topAnchor),
            topFocusGuide.bottomAnchor.constraint(equalTo: headerCustomContentView.bottomAnchor),
            topFocusGuide.leadingAnchor.constraint(equalTo: progressView.leadingAnchor),
            topFocusGuide.trailingAnchor.constraint(equalTo: progressView.trailingAnchor),
        ])
        topFocusGuide.preferredFocusEnvironments = [headerCustomContentView]
        
        lineView.addTarget(self, action: #selector(scrubberButtonTapped(_:)), for: .primaryActionTriggered)
        
    }
    
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [lineView]
    }
    
    @objc private func scrubberButtonTapped(_ sender: ScrubberButton) {
        delegate?.scrubberButtonTapped()
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
