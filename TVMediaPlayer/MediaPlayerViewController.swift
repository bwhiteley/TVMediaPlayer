//
//  MediaPlayerViewController.swift
//  MythTV
//
//  Created by J. B. Whiteley on 10/4/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//

import UIKit
import GameController


public class MediaPlayerViewController: UIViewController {
    
    
    public init(mediaPlayer:MediaPlayerType, mediaItem:MediaItemType) {
        self.mediaPlayer = mediaPlayer
        self.mediaItem = mediaItem
        self.controls = ControlsOverlayViewController.viewControllerFromStoryboard(mediaItem: mediaItem)
        super.init(nibName: nil, bundle: nil)
        self.mediaPlayer.positionChanged = { [weak self] newPosition in
            self?.mediaPlayerPositionChanged(newPosition)
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public let mediaItem: MediaItemType

    public var canvasView:UIView = UIView()
    
    private let controls:ControlsOverlayViewController

    private let panAdjustmentValue:Float = 0.3
    
    public var mediaPlayer:MediaPlayerType
    
    public var thumbnailDelegate:MediaPlayerThumbnailSnapshotDelegate? {
        get {
            return controls.delegate
        }
        set {
            controls.delegate = newValue
        }
    }
    
    public var dismiss:((position:Float) -> Void)?
    
//    lazy var swipeUpGestureRecognizer:UISwipeGestureRecognizer = {
//        let gr = UISwipeGestureRecognizer(target: self, action: "swipedUp:")
//        gr.direction = .Up
//        return gr
//    }()
//    lazy var swipeDownGestureRecognizer:UISwipeGestureRecognizer = {
//        let gr = UISwipeGestureRecognizer(target: self, action: "swipedDown:")
//        gr.direction = .Down
//        return gr
//    }()
    private lazy var swipeLeftGestureRecognizer:UISwipeGestureRecognizer = {
        let gr = UISwipeGestureRecognizer(target: self, action: "swipedLeft:")
        gr.direction = .Left
        return gr
    }()
    private lazy var swipeRightGestureRecognizer:UISwipeGestureRecognizer = {
        let gr = UISwipeGestureRecognizer(target: self, action: "swipedRight:")
        gr.direction = .Right
        return gr
    }()
    private lazy var panGestureRecognizer:UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: "panning:")
        pan.enabled = false
        return pan
    }()
    
    private var dpadState:DPadState = .Select {
        didSet {
            guard oldValue != dpadState else { return }
            //NSLog("New DPad state: \(dpadState)")
            controls.dpadState = dpadState
        }
    }
    
    private var playerState:PlayerState = .StandardPlay {
        didSet {
            controls.playerState = playerState
            // controls?.videoSize = mediaPlayer.videoSize TODO
            switch playerState {
            case .StandardPlay:
                play()
            case let .Rewind(rate):
                mediaPlayer.rate = -rate
            case let .Fastforward(rate):
                mediaPlayer.rate = rate
                controls.position = mediaPlayer.position
            case .Pause:
                pause()
            }
        }
    }
    
    private var touchesEndedTimestamp:NSDate?
    private var touching:Bool = false {
        didSet {
            touchesEndedTimestamp = NSDate()
        }
    }
    
    public func play() {
        panGestureRecognizer.enabled = false
        swipeRightGestureRecognizer.enabled = true
        swipeLeftGestureRecognizer.enabled = true
        //                swipeUpGestureRecognizer.enabled = true
        //                swipeDownGestureRecognizer.enabled = true
        mediaPlayer.play()
        mediaPlayer.rate = 1
    }
    
    public func pause() {
        panGestureRecognizer.enabled = true
        swipeRightGestureRecognizer.enabled = false
        swipeLeftGestureRecognizer.enabled = false
        //                swipeUpGestureRecognizer.enabled = false
        //                swipeDownGestureRecognizer.enabled = false
        controls.position = mediaPlayer.position
        mediaPlayer.pause()
    }
    
    private func dpadStateForAxis(x x:Float, y: Float) -> DPadState {
        let threshold:Float = 0.7
        if x > threshold { return .Right }
        if x < -threshold { return .Left }
//        if y > threshold { return .Up }
//        if y < -threshold { return .Down }
        return .Select
    }
    
    private func dpadChanged(x x:Float, y:Float) {
//        NSLog("dpad: x: \(x) y: \(y)")
        self.dpadState = dpadStateForAxis(x: x, y: y)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.canvasView.frame = view.bounds
        canvasView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.addSubview(canvasView)
        
        
//        controlsOverlayView.hidden = true
        //mediaPlayer.pause()
        mediaPlayer.play()
        setupButtons()
        
        guard let controller = GCController.controllers().first else { return }
        guard let micro = controller.microGamepad else { return }
        micro.reportsAbsoluteDpadValues = true
        micro.dpad.valueChangedHandler = { [weak self] (pad, x, y) in
            self?.dpadChanged(x:x, y: y)
        }
        
//        VLCLibrary.sharedLibrary().debugLogging = true
//        VLCLibrary.sharedLibrary().debugLoggingLevel = 0
        
        controls.view.frame = self.view.bounds
        controls.view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        controls.willMoveToParentViewController(self)
        self.addChildViewController(controls)
        view.addSubview(controls.view)
        controls.didMoveToParentViewController(self)
    }
    
    private func setupButtons() {
        
//        self.view.addGestureRecognizer(swipeUpGestureRecognizer)
//        self.view.addGestureRecognizer(swipeDownGestureRecognizer)
        self.view.addGestureRecognizer(swipeRightGestureRecognizer)
        self.view.addGestureRecognizer(swipeLeftGestureRecognizer)
        
        
    
//        panGestureRecognizer.requireGestureRecognizerToFail(swipeUpGestureRecognizer)
//        panGestureRecognizer.requireGestureRecognizerToFail(swipeDownGestureRecognizer)
        panGestureRecognizer.requireGestureRecognizerToFail(swipeLeftGestureRecognizer)
        panGestureRecognizer.requireGestureRecognizerToFail(swipeRightGestureRecognizer)
        
//        pan.requireGestureRecognizerToFail(upArrowGestureRecognizer)
//        pan.requireGestureRecognizerToFail(downArrowGestureRecognizer)
//        pan.requireGestureRecognizerToFail(leftArrowGestureRecognizer)
//        pan.requireGestureRecognizerToFail(rightArrowGestureRecognizer)
        self.view.addGestureRecognizer(panGestureRecognizer)

        let tap = UITapGestureRecognizer(target: self, action: "menuPressed:")
        tap.allowedPressTypes = [NSNumber(integer: UIPressType.Menu.rawValue)]
        self.view.addGestureRecognizer(tap)

    }
    
    internal func menuPressed(gr:UITapGestureRecognizer) {
        mediaPlayer.pause()
        if let dismiss = dismiss {
            dismiss(position: mediaPlayer.position)
        }
        else {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    private var initialPanningPosition:Float = 0

    func panning(gesture:UIPanGestureRecognizer) {
        
        let point = gesture.translationInView(gesture.view)
        
        if case .Began = gesture.state {
            initialPanningPosition = controls.position
        }
        
        let delta:Float = panAdjustmentValue * Float(point.x) / Float(self.view.frame.width)
        let newProgress = initialPanningPosition + delta
        controls.position = newProgress
        
    }
    
    func swipedUp(gesture:UISwipeGestureRecognizer) {
        switch playerState {
        case .StandardPlay, .Fastforward, .Rewind:
            shortJumpAhead()
        default:
            break
        }
    }

    func swipedDown(gesture:UISwipeGestureRecognizer) {
        switch playerState {
        case .StandardPlay, .Fastforward, .Rewind:
            shortJumpBack()
        default:
            break
        }
    }
    
    func swipedLeft(gesture:UISwipeGestureRecognizer) {
        guard let newState = playerState.nextSlowerState() else { return }
        playerState = newState
    }
    
    func swipedRight(gesture:UISwipeGestureRecognizer) {
        guard let newState = playerState.nextFasterState() else { return }
        playerState = newState
    }
    
    func shortJumpAhead() {
        let position = adjustPosition(mediaPlayer.position, bySeconds: 30)
        self.mediaPlayer.position = position
        flashTimeBar()
    }
    
    func shortJumpBack() {
        let position = adjustPosition(mediaPlayer.position, bySeconds: -10)
        self.mediaPlayer.position = position
        flashTimeBar()
    }
    
    func longJumpAhead() {
        let position = adjustPosition(mediaPlayer.position, bySeconds: 60*10)
        self.mediaPlayer.position = position
        flashTimeBar()
    }
    
    func longJumpBack() {
        let position = adjustPosition(mediaPlayer.position, bySeconds: -60*10)
        self.mediaPlayer.position = position
        flashTimeBar()
    }
    
    private func didTapEventComeFromDPad() -> Bool {
        if touching { return true }
        guard let touchesEndedTimestamp = self.touchesEndedTimestamp else {
            return false
        }
        let interval = NSDate().timeIntervalSinceDate(touchesEndedTimestamp)
        return interval < 0.1
    }
    
    private func upArrowPressed() {
        guard !didTapEventComeFromDPad() else { return }
        guard case .StandardPlay = playerState else { return }
        longJumpAhead()
    }
    
    private func downArrowPressed() {
        guard !didTapEventComeFromDPad() else { return }
        guard case .StandardPlay = playerState else { return }
        longJumpBack()
    }

    private func leftArrowPressed() {
        guard !didTapEventComeFromDPad() else { return }
        guard case .StandardPlay = playerState else { return }
        shortJumpBack()
    }
    
    private func rightArrowPressed() {
        guard !didTapEventComeFromDPad() else { return }
        guard case .StandardPlay = playerState else { return }
        shortJumpAhead()
    }

    public func adjustPosition(position:Float, bySeconds seconds:Float) -> Float {
        let delta = seconds / Float(mediaItem.length)
        var newPosition = position + delta
        newPosition = max(newPosition, 0.0)
        newPosition = min(newPosition, 1.0)
        return newPosition
    }

    private func selectPressed() {
        let state = playerState
        switch state {
        case .StandardPlay, .Rewind, .Fastforward:
            switch dpadState {
            case .Select:
                switch state {
                case .Rewind, .Fastforward:
                    playerState = .StandardPlay
                default:
                    playerState = .Pause
                }
            case .Right:
                shortJumpAhead()
            case .Left:
                shortJumpBack()
            case .Up:
                longJumpAhead()
            case .Down:
                longJumpBack()
            }
        case .Pause:
            mediaPlayer.position = controls.position
//            self.initialPosition = controls.position
            playerState = .StandardPlay
        }
    }

    
    private func playPressed() {
        let state = playerState
        switch state {
        case .Pause:
            playerState = .StandardPlay
        case .StandardPlay, .Fastforward, .Rewind:
            playerState = .Pause
        }
    }
    
    private func flashTimeBar() {
        controls.position = mediaPlayer.position
        controls.flashTimeBar()
    }
    
    private func mediaPlayerPositionChanged(position:Float) {
        controls.position = position
    }
    
}


extension MediaPlayerViewController {
    override public func pressesBegan(presses: Set<UIPress>, withEvent event: UIPressesEvent?) {
        for item in presses {
            //NSLog("presses began for type: %d", item.type.rawValue)
            switch item.type {
            case .PlayPause:
                self.playPressed()
            case .Select:
                self.selectPressed()
            case .UpArrow:
                self.upArrowPressed()
            case .DownArrow:
                self.downArrowPressed()
            case .LeftArrow:
                self.leftArrowPressed()
            case .RightArrow:
                self.rightArrowPressed()
            default:
                break
            }
        }
    }
    
    override public func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        touching = true
        //NSLog("media touches began")
        super.touchesBegan(touches, withEvent: event)
        controls.touchesBegan()
    }
    
    override public func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        touching = false
        //NSLog("media touches ended")
        super.touchesEnded(touches, withEvent: event)
        controls.touchesEnded()
    }
    
    override public func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        touching = false
        //NSLog("media touches cancelled")
        super.touchesCancelled(touches, withEvent: event)
        controls.touchesEnded()
    }

//    override func pressesEnded(presses: Set<UIPress>, withEvent event: UIPressesEvent?) {
//        for item in presses {
//            NSLog("presses ended for type: %d", item.type.rawValue)
//        }
//    }

}

