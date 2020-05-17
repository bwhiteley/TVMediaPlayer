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
    func snapshotImageAtPosition(_ position:Float, size:CGSize, handler:MediaPlayerThumbnailHandler)
}

open class MediaPlayerViewController: UIViewController {
    
    public init(mediaPlayer:MediaPlayerType) {
        self.mediaPlayer = mediaPlayer
        self.controls = ControlsOverlayViewController.viewControllerFromStoryboard(mediaItem: mediaPlayer.item)
        super.init(nibName: nil, bundle: nil)
        self.mediaPlayer.positionChanged = { [weak self] newPosition in
            self?.mediaPlayerPositionChanged(newPosition)
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    /**
     Provide your content in the `canvasView`. For example, 
     you might add your own subviews or sublayers. 
    */
    open var canvasView:UIView = UIView()
    
    fileprivate let controls:ControlsOverlayViewController

    fileprivate let panAdjustmentValue:Float = 0.3
    
    open var mediaPlayer:MediaPlayerType
    
    open var wideMargins:Bool = true
    
    open var thumbnailDelegate:MediaPlayerThumbnailSnapshotDelegate? {
        get {
            return controls.delegate
        }
        set {
            controls.delegate = newValue
        }
    }
    
    open var dismiss:((_ position:Float) -> Void)?
    
    fileprivate lazy var swipeLeftGestureRecognizer:UISwipeGestureRecognizer = {
        let gr = UISwipeGestureRecognizer(target: self, action: #selector(swipedLeft(_:)))
        gr.direction = .left
        return gr
    }()
    fileprivate lazy var swipeRightGestureRecognizer:UISwipeGestureRecognizer = {
        let gr = UISwipeGestureRecognizer(target: self, action: #selector(swipedRight(_:)))
        gr.direction = .right
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
        swipeRightGestureRecognizer.isEnabled = true
        swipeLeftGestureRecognizer.isEnabled = true
        mediaPlayer.play()
        mediaPlayer.rate = 1
    }
    
    open func pause() {
        panGestureRecognizer.isEnabled = true
        swipeRightGestureRecognizer.isEnabled = false
        swipeLeftGestureRecognizer.isEnabled = false
        controls.position = mediaPlayer.position
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
        
        guard let controller = GCController.controllers().first else { return }
        guard let micro = controller.microGamepad else { return }
        micro.reportsAbsoluteDpadValues = true
        micro.dpad.valueChangedHandler = { [weak self] (pad, x, y) in
            self?.dpadChanged(x:x, y: y)
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
        self.view.addGestureRecognizer(swipeRightGestureRecognizer)
        self.view.addGestureRecognizer(swipeLeftGestureRecognizer)
    
        panGestureRecognizer.require(toFail: swipeLeftGestureRecognizer)
        panGestureRecognizer.require(toFail: swipeRightGestureRecognizer)
        
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
    
    fileprivate var initialPanningPosition:Float = 0

    @objc func panning(_ gesture:UIPanGestureRecognizer) {
        
        let point = gesture.translation(in: gesture.view)
        
        if case .began = gesture.state {
            initialPanningPosition = controls.position
        }
        
        let delta:Float = panAdjustmentValue * Float(point.x) / Float(self.view.frame.width)
        let newProgress = initialPanningPosition + delta
        controls.position = newProgress
        
    }
    
    func swipedUp(_ gesture:UISwipeGestureRecognizer) {
        switch playerState {
        case .standardPlay, .fastforward, .rewind:
            shortJumpAhead()
        default:
            break
        }
    }

    func swipedDown(_ gesture:UISwipeGestureRecognizer) {
        switch playerState {
        case .standardPlay, .fastforward, .rewind:
            shortJumpBack()
        default:
            break
        }
    }
    
    @objc func swipedLeft(_ gesture:UISwipeGestureRecognizer) {
        guard let newState = playerState.nextSlowerState() else { return }
        playerState = newState
    }
    
    @objc func swipedRight(_ gesture:UISwipeGestureRecognizer) {
        guard let newState = playerState.nextFasterState() else { return }
        playerState = newState
    }
    
    func shortJumpAhead() {
        let position = MediaPlayerViewController.newPositionByAdjustingPosition(mediaPlayer.position, bySeconds: 30, length: mediaPlayer.item.length)
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
        guard !didTapEventComeFromDPad() else { return }
        guard case .standardPlay = playerState else { return }
        longJumpAhead()
    }
    
    fileprivate func downArrowPressed() {
        guard !didTapEventComeFromDPad() else { return }
        guard case .standardPlay = playerState else { return }
        longJumpBack()
    }

    fileprivate func leftArrowPressed() {
        guard !didTapEventComeFromDPad() else { return }
        guard case .standardPlay = playerState else { return }
        shortJumpBack()
    }
    
    fileprivate func rightArrowPressed() {
        guard !didTapEventComeFromDPad() else { return }
        guard case .standardPlay = playerState else { return }
        shortJumpAhead()
    }
    
    public static func newPositionByAdjustingPosition(_ position:Float, bySeconds seconds:Float, length:TimeInterval) -> Float {
        let delta = seconds / Float(length)
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
    
    fileprivate func mediaPlayerPositionChanged(_ position:Float) {
        controls.position = position
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
