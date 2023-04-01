import UIKit
import GameController

public protocol MediaPlayerThumbnailHandler: NSObjectProtocol {
    /**
     Deliver a thumbnail image for the specified position.
     
     - param image: The thumbnail image.
     
     - param position: The position represented by the image.
     */
    func setSnapshotImage(_ image:UIImage, forPosition position:Float)
}

public protocol MediaPlayerThumbnailSnapshotDelegate: NSObjectProtocol {
    /**
     A thumbnail image is requested at the given position and size.
     
     - param position: The position of the requested snapshot.
     
     - param size: The size of the requested thumbnail image.
     
     - param handler: A thumbnail handler to deliver the image to.
    */
    func snapshotImageAtPosition(_ position:Double, size:CGSize, handler:MediaPlayerThumbnailHandler)
}

open class MediaPlayerViewController: UIViewController {
    
    public init(mediaPlayer:MediaPlayerType, controlsCustomization: ControlsOverlayCustomization = .default) {
        self.mediaPlayer = mediaPlayer
        self.controls = ControlsOverlayViewController.viewControllerFromStoryboard(mediaItem: mediaPlayer.item, controlsCustomization: controlsCustomization)
        super.init(nibName: nil, bundle: nil)
        self.controls.delegate = self
        self.mediaPlayer.positionChanged = { [weak self] newPosition in
            self?.mediaPlayerPositionChanged(newPosition)
        }
    }

    @available (*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    /**
     Provide your content in the `canvasView`. For example, 
     you might add your own subviews or sublayers. 
    */
    open var canvasView:UIView = UIView()
    
    public var headerCustomContentView: UIView {
        get {
            return controls.headerCustomContentView
        }
    }
    
    fileprivate let controls:ControlsOverlayViewController

    fileprivate let panAdjustmentValue:Double = 0.3
    
    private weak var captionView: CaptionView?
    
    open var mediaPlayer:MediaPlayerType
    
    open var wideMargins:Bool = true
    
    open var thumbnailDelegate:MediaPlayerThumbnailSnapshotDelegate? {
        get {
            return controls.thumbnailDelegate
        }
        set {
            controls.thumbnailDelegate = newValue
        }
    }
    
    open var dismiss:((_ position:Double) -> Void)?
    
//    fileprivate lazy var swipeLeftGestureRecognizer:UISwipeGestureRecognizer = {
//        let gr = UISwipeGestureRecognizer(target: self, action: #selector(swipedLeft(_:)))
//        gr.direction = .left
//        return gr
//    }()
//    fileprivate lazy var swipeRightGestureRecognizer:UISwipeGestureRecognizer = {
//        let gr = UISwipeGestureRecognizer(target: self, action: #selector(swipedRight(_:)))
//        gr.direction = .right
//        return gr
//    }()
    fileprivate lazy var swipeUpGestureRecognizer:UISwipeGestureRecognizer = {
        let gr = UISwipeGestureRecognizer(target: self, action: #selector(swipedUp(_:)))
        gr.direction = .up
        return gr
    }()
    fileprivate lazy var swipeDownGestureRecognizer:UISwipeGestureRecognizer = {
        let gr = UISwipeGestureRecognizer(target: self, action: #selector(swipedDown(_:)))
        gr.direction = .down
        return gr
    }()
    fileprivate lazy var panGestureRecognizer:UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panning(_:)))
        pan.isEnabled = false
        return pan
    }()
    
    fileprivate var dpadState:DPadState = .select {
        didSet {
            guard oldValue != dpadState else { return }
            controls.dpadState = dpadState
        }
    }
    
    fileprivate var playerState:PlayerState = .standardPlay {
        didSet {
            controls.playerState = playerState
            switch playerState {
            case .standardPlay:
                play()
            case let .rewind(rate):
                mediaPlayer.rate = -rate
            case let .fastforward(rate):
                mediaPlayer.rate = rate
                controls.position = mediaPlayer.position
            case .pause:
                pause()
            }
        }
    }
    
    fileprivate var touchesEndedTimestamp:Date? // used to distinguish universal remote arrow buttons from touchpad taps.
    fileprivate var touching:Bool = false {
        didSet {
            touchesEndedTimestamp = Date()
        }
    }
    
    open func play() {
        panGestureRecognizer.isEnabled = false
//        swipeRightGestureRecognizer.isEnabled = true
//        swipeLeftGestureRecognizer.isEnabled = true
        mediaPlayer.play()
        mediaPlayer.rate = 1
    }
    
    open func pause() {
//        swipeRightGestureRecognizer.isEnabled = false
//        swipeLeftGestureRecognizer.isEnabled = false
        if !mediaPlayer.isPlayingAd {
            controls.position = mediaPlayer.position
            panGestureRecognizer.isEnabled = true
        }
        mediaPlayer.pause()
    }
    
    fileprivate func dpadStateForAxis(x:Float, y: Float) -> DPadState {
        let threshold:Float = 0.7
        if x > threshold { return .right }
        if x < -threshold { return .left }
        return .select
    }
    
    fileprivate func dpadChanged(x:Float, y:Float) {
        self.dpadState = dpadStateForAxis(x: x, y: y)
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        self.canvasView.frame = view.bounds
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(canvasView)
        
        mediaPlayer.play()
        setupButtons()
        
        if let controller = GCController.controllers().first,
           let micro = controller.microGamepad {
            micro.reportsAbsoluteDpadValues = true
            micro.dpad.valueChangedHandler = { [weak self] (pad, x, y) in
                self?.dpadChanged(x:x, y: y)
            }
        }
        
        controls.wideMargins = self.wideMargins
        controls.view.frame = self.view.bounds
        controls.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        controls.willMove(toParent: self)
        self.addChild(controls)
        view.addSubview(controls.view)
        controls.didMove(toParent: self)
    }
    
    fileprivate func setupButtons() {
//        self.view.addGestureRecognizer(swipeRightGestureRecognizer)
//        self.view.addGestureRecognizer(swipeLeftGestureRecognizer)
//        panGestureRecognizer.require(toFail: swipeLeftGestureRecognizer)
//        panGestureRecognizer.require(toFail: swipeRightGestureRecognizer)
        
        self.view.addGestureRecognizer(swipeDownGestureRecognizer)
        self.view.addGestureRecognizer(swipeUpGestureRecognizer)
   
        self.view.addGestureRecognizer(panGestureRecognizer)

        let tap = UITapGestureRecognizer(target: self, action: #selector(menuPressed(_:)))
        tap.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue as Int)]
        self.view.addGestureRecognizer(tap)
    }
    
    @objc internal func menuPressed(_ gr:UITapGestureRecognizer) {
        mediaPlayer.pause()
        if let dismiss = dismiss {
            dismiss(mediaPlayer.position)
        }
        else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    fileprivate var initialPanningPosition:Double = 0

    @objc func panning(_ gesture:UIPanGestureRecognizer) {
        
        let point = gesture.translation(in: gesture.view)
        
        if case .began = gesture.state {
            initialPanningPosition = controls.position
        }
        
        let delta = panAdjustmentValue * point.x / self.view.frame.width
        let newProgress = initialPanningPosition + delta
        controls.position = newProgress
        
    }
    
    @objc func swipedUp(_ gesture:UISwipeGestureRecognizer) {
        if captionView == nil { return }
        dismissCaptionView()
    }

    private let captionViewHeight:CGFloat = 245
    private func showCaptionView() {
        if self.captionView != nil { return }
        let captionView = CaptionView(frame: .init(x: 0, y: -captionViewHeight, width: view.frame.width, height: captionViewHeight))
        view.addSubview(captionView)
        captionView.configure(labels: mediaPlayer.textTracks, selected: mediaPlayer.activeTextTrack) { [weak self] newTrack in
            self?.mediaPlayer.activeTextTrack = newTrack
        }
        captionView.dismissHandler = { [weak self] in
            self?.dismissCaptionView()
        }
        self.captionView = captionView
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseOut]) { [weak self] in
            self?.view.setNeedsLayout()
            captionView.frame.origin.y = 0
            self?.view.setNeedsLayout()
            self?.setNeedsFocusUpdate()
            self?.updateFocusIfNeeded()
        }
    }
    
    open override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let captionView = self.captionView {
            return [captionView]
        }
        return super.preferredFocusEnvironments
    }
    
    private func dismissCaptionView() {
        guard let captionView = self.captionView else { return }
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseIn], animations: { [weak self] in
            guard let height = self?.captionViewHeight else { return }
            self?.view.setNeedsLayout()
            captionView.frame.origin.y = -height
            self?.view.setNeedsLayout()
        }, completion: { _ in
            captionView.removeFromSuperview()
        })
    }
    
    @objc func swipedDown(_ gesture:UISwipeGestureRecognizer) {
        showCaptionView()
    }
    
    @objc func swipedLeft(_ gesture:UISwipeGestureRecognizer) {
        guard let newState = playerState.nextSlowerState() else { return }
        guard captionView == nil else { return }
        playerState = newState
    }
    
    @objc func swipedRight(_ gesture:UISwipeGestureRecognizer) {
        guard let newState = playerState.nextFasterState() else { return }
        guard captionView == nil else { return }
        playerState = newState
    }
    
    func shortJumpAhead() {
        let position = MediaPlayerViewController.newPositionByAdjustingPosition(mediaPlayer.position, bySeconds: 10, length: mediaPlayer.item.length)
        self.mediaPlayer.position = position
        flashTimeBar()
    }
    
    func shortJumpBack() {
        let position = MediaPlayerViewController.newPositionByAdjustingPosition(mediaPlayer.position, bySeconds: -10, length: mediaPlayer.item.length)
        self.mediaPlayer.position = position
        flashTimeBar()
    }
    
    func longJumpAhead() {
        let position = MediaPlayerViewController.newPositionByAdjustingPosition(mediaPlayer.position, bySeconds: 60*10, length: mediaPlayer.item.length)
        self.mediaPlayer.position = position
        flashTimeBar()
    }
    
    func longJumpBack() {
        let position = MediaPlayerViewController.newPositionByAdjustingPosition(mediaPlayer.position, bySeconds: -60*10, length: mediaPlayer.item.length)
        self.mediaPlayer.position = position
        flashTimeBar()
    }
    
    fileprivate func didTapEventComeFromDPad() -> Bool {
        // We want to ignore tap events from the touchpad. We do this 
        // by checking to see if the tap event closely follows touch events.
        if touching { return true }
        guard let touchesEndedTimestamp = self.touchesEndedTimestamp else {
            return false
        }
        let interval = Date().timeIntervalSince(touchesEndedTimestamp)
        return interval < 0.1
    }
    
    fileprivate func upArrowPressed() {
        showCaptionView()
    }
    
    fileprivate func downArrowPressed() {
        if captionView == nil { return }
        dismissCaptionView()
    }

    fileprivate func leftArrowPressed() {
        if mediaPlayer.isPlayingAd { return }
        //guard !didTapEventComeFromDPad() else { return }
        guard case .standardPlay = playerState else { return }
        shortJumpBack()
    }
    
    fileprivate func rightArrowPressed() {
        if mediaPlayer.isPlayingAd { return }
        //guard !didTapEventComeFromDPad() else { return }
        guard case .standardPlay = playerState else { return }
        shortJumpAhead()
    }
    
    public static func newPositionByAdjustingPosition(_ position:Double, bySeconds seconds:Double, length:TimeInterval) -> Double {
        let delta = seconds / length
        var newPosition = position + delta
        newPosition = max(newPosition, 0.0)
        newPosition = min(newPosition, 1.0)
        return newPosition
    }

    fileprivate func selectPressed() {
        let state = playerState
        switch state {
        case .standardPlay, .rewind, .fastforward:
            switch dpadState {
            case .select:
                switch state {
                case .rewind, .fastforward:
                    playerState = .standardPlay
                default:
                    playerState = .pause
                }
            case .right:
                shortJumpAhead()
            case .left:
                shortJumpBack()
            case .up:
                longJumpAhead()
            case .down:
                longJumpBack()
            }
        case .pause:
            mediaPlayer.position = controls.position
            playerState = .standardPlay
        }
    }

    fileprivate func playPressed() {
        let state = playerState
        switch state {
        case .pause:
            playerState = .standardPlay
        case .standardPlay, .fastforward, .rewind:
            playerState = .pause
        }
    }
    
    fileprivate func flashTimeBar() {
        controls.position = mediaPlayer.position
        controls.flashTimeBar()
    }
    
    fileprivate func mediaPlayerPositionChanged(_ position:Double) {
        if mediaPlayer.isPlayingAd {
            let length = mediaPlayer.item.length
            if !position.isNaN, !position.isInfinite, !length.isNaN, !length.isInfinite {
                
            let secondsRemaining = max(Int( length - position * length), 0)
            controls.adTimeRemainingLabel.attributedText = controls.controlsCustomization.adSecondsRemainingString(secondsRemaining)
            } else {
                controls.adTimeRemainingLabel.attributedText = nil
            }
        } else {
            controls.adTimeRemainingLabel.attributedText = nil
            controls.position = position
        }
    }
    
}

extension MediaPlayerViewController: ControlsOverlayViewControllerDelegate {
    func scrubberButtonTapped() {
        selectPressed()
    }
}

extension MediaPlayerViewController {
    override open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for item in presses {
            //NSLog("presses began for type: %d", item.type.rawValue)
            switch item.type {
            case .playPause:
                self.playPressed()
            case .select:
                self.selectPressed()
            case .upArrow:
                self.upArrowPressed()
            case .downArrow:
                self.downArrowPressed()
            case .leftArrow:
                self.leftArrowPressed()
            case .rightArrow:
                self.rightArrowPressed()
            default:
                break
            }
        }
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touching = true
        //NSLog("media touches began")
        super.touchesBegan(touches, with: event)
        controls.touchesBegan()
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touching = false
        //NSLog("media touches ended")
        super.touchesEnded(touches, with: event)
        controls.touchesEnded()
    }
    
    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touching = false
        //NSLog("media touches cancelled")
        super.touchesCancelled(touches, with: event)
        controls.touchesEnded()
    }
}

//
//  Created by Bart Whiteley on 10/4/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//
