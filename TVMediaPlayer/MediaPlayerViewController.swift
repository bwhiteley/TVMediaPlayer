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
    
    private let leftTapGestureRecognizer = UITapGestureRecognizer()
    private let leftLongPressGestureRecognizer = UILongPressGestureRecognizer()
    private let rightTapGestureRecognizer = UITapGestureRecognizer()
    private let rightLongPressGestureRecognizer = UILongPressGestureRecognizer()
    private var ffRewindTimer: Timer?
    
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
            switch playerState {
            case .standardPlay:
                switch oldValue {
                case .fastforward, .rewind:
                    self.mediaPlayer.position = self.controls.position
                default:
                    break
                }
                _play()
            case let .rewind(rate):
                _pause()
                panGestureRecognizer.isEnabled = false
                fastForward(rate: -rate)
                //mediaPlayer.rate = -rate
                break
            case let .fastforward(rate):
                _pause()
                panGestureRecognizer.isEnabled = false
                fastForward(rate: rate)
                //mediaPlayer.rate = rate
                break
            case .pause:
                _pause()
            }
            controls.playerState = playerState
        }
    }
    
    // A subclass or container can call this to indicate the user interacted with the
    // remote to reset the timer for hiding the controls.
    public func userInteractionOccurred() {
        controls.userInteractionOccurred()
    }
    
    fileprivate var touchesEndedTimestamp:Date? // used to distinguish universal remote arrow buttons from touchpad taps.
    fileprivate var touching:Bool = false {
        didSet {
            touchesEndedTimestamp = Date()
        }
    }
    
    public func resumePlaying() {
        playerState = .standardPlay
    }
    
    public func play() {
        playerState = .standardPlay
    }
    
    public func pause() {
        playerState = .pause
    }
    
    private func _play() {
        ffRewindTimer?.invalidate()
        panGestureRecognizer.isEnabled = false
        mediaPlayer.play()
        mediaPlayer.rate = 1
    }
    
    private func _pause() {
        if !mediaPlayer.isPlayingAd {
            switch playerState {
            case .fastforward, .rewind:
                break
            default:
                controls.position = mediaPlayer.position
            }
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

        controls.wideMargins = self.wideMargins
        controls.view.frame = self.view.bounds
        controls.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        controls.willMove(toParent: self)
        self.addChild(controls)
        view.addSubview(controls.view)
        controls.didMove(toParent: self)
        addTapRecognizers()
        
        // The first time the player is loaded, there are no game controllers.
        // So we register for a notification. For subsequent times, the
        // notification is not fired but the game controller is present here.
        NotificationCenter.default.addObserver(self, selector: #selector(discoveredGameController), name: NSNotification.Name.GCControllerDidConnect , object: nil)
        
        setupGameController()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func discoveredGameController() {
        setupGameController()
    }
    
    private func setupGameController() {
        if let controller = GCController.controllers().first {
            if let micro = controller.microGamepad {
                micro.reportsAbsoluteDpadValues = true
                micro.dpad.valueChangedHandler = { [weak self] (pad, x, y) in
                    self?.dpadChanged(x:x, y: y)
                }
            }
        }
    }
    
    private func addTapRecognizers() {
        self.view.addGestureRecognizer(panGestureRecognizer)

        leftTapGestureRecognizer.addTarget(self, action: #selector(self.leftButtonTapped))
        leftTapGestureRecognizer.allowedPressTypes = [
            NSNumber(value: UIPress.PressType.leftArrow.rawValue),
            NSNumber(value: UIPress.PressType.keyboardLeftArrow.rawValue),
        ]
        leftTapGestureRecognizer.isEnabled = true
        self.view.addGestureRecognizer(leftTapGestureRecognizer)
        
        rightTapGestureRecognizer.addTarget(self, action: #selector(self.rightButtonTapped))
        rightTapGestureRecognizer.allowedPressTypes = [
            NSNumber(value: UIPress.PressType.rightArrow.rawValue),
            NSNumber(value: UIPress.PressType.keyboardRightArrow.rawValue),
        ]
        rightTapGestureRecognizer.isEnabled = true
        self.view.addGestureRecognizer(rightTapGestureRecognizer)
        
        leftLongPressGestureRecognizer.addTarget(self, action: #selector(self.leftButtonLongPress))
        leftLongPressGestureRecognizer.allowedPressTypes = [
            NSNumber(value: UIPress.PressType.leftArrow.rawValue),
            NSNumber(value: UIPress.PressType.keyboardLeftArrow.rawValue),
        ]
        leftLongPressGestureRecognizer.isEnabled = true // disable until compatible with THEO
        self.view.addGestureRecognizer(leftLongPressGestureRecognizer)
        
        rightLongPressGestureRecognizer.addTarget(self, action: #selector(self.rightButtonLongPress))
        rightLongPressGestureRecognizer.allowedPressTypes = [
            NSNumber(value: UIPress.PressType.rightArrow.rawValue),
            NSNumber(value: UIPress.PressType.keyboardRightArrow.rawValue),
        ]
        rightLongPressGestureRecognizer.isEnabled = true // disable until compabitle with THEO
        self.view.addGestureRecognizer(rightLongPressGestureRecognizer)
        
        let menuTap = UITapGestureRecognizer(target: self, action: #selector(menuPressed))
        menuTap.allowedPressTypes = [
            NSNumber(value: UIPress.PressType.menu.rawValue as Int),
            NSNumber(value: UIPress.PressType.keyboardEsc.rawValue as Int),
        ]
        self.view.addGestureRecognizer(menuTap)
        
        let playTap = UITapGestureRecognizer(target: self, action: #selector(playPressed))
        playTap.allowedPressTypes = [
            NSNumber(value: UIPress.PressType.playPause.rawValue as Int),
            NSNumber(value: UIPress.PressType.keyboardSpace.rawValue as Int),
        ]
        self.view.addGestureRecognizer(playTap)
        
        let selectTap = UITapGestureRecognizer(target: self, action: #selector(selectPressed))
        selectTap.allowedPressTypes = [
            NSNumber(value: UIPress.PressType.select.rawValue as Int),
            NSNumber(value: UIPress.PressType.keyboardReturn.rawValue as Int),
        ]
        self.view.addGestureRecognizer(selectTap)
        
        let selectLongPress = UILongPressGestureRecognizer(target: self, action: #selector(selectLongPressed))
        selectLongPress.allowedPressTypes = [
            NSNumber(value: UIPress.PressType.select.rawValue as Int),
        ]
        self.view.addGestureRecognizer(selectLongPress)
    }
    
    @objc func selectLongPressed() {
        switch dpadState {
        case .right:
            rightButtonLongPress()
        case .left:
            leftButtonLongPress()
        default:
            break
        }
    }
    
    @objc private func rightButtonTapped() {
        if mediaPlayer.isPlayingAd { return }
        if !controls.lineView.isHidden && !controls.lineView.isFocused { return }
        switch playerState {
        case .standardPlay, .pause:
            shortJumpAhead()
        case .fastforward, .rewind:
            if let next = playerState.nextFasterState() {
                playerState = next
            }
        }
        //guard !didTapEventComeFromDPad() else { return }
    }

    @objc private func leftButtonTapped() {
        if mediaPlayer.isPlayingAd { return }
        if !controls.lineView.isHidden && !controls.lineView.isFocused { return }
        switch playerState {
        case .standardPlay, .pause:
            shortJumpBack()
        case .fastforward, .rewind:
            if let next = playerState.nextSlowerState() {
                playerState = next
            }
        }
        //guard !didTapEventComeFromDPad() else { return }
    }
    
    @objc private func rightButtonLongPress() {
        if mediaPlayer.isPlayingAd { return }
        switch playerState {
        case .standardPlay, .pause:
            if let next = playerState.nextFasterState() {
                playerState = next
            }
        default:
            break
        }
    }
    
    @objc private func leftButtonLongPress() {
        if mediaPlayer.isPlayingAd { return }
        switch playerState {
        case .standardPlay, .pause:
            if let next = playerState.nextSlowerState() {
                playerState = next
            }
        default:
            break
        }
    }
    
    private func fastForward(rate: Double) {
        /**
         Some expiriments with Apple's player, with a 1hr show and a 2hr movie.
         at 4x:
         1hr: 37s
         2h: 75s
         ==> ~ 100x realtime

         at 3x
         1hr: 75s
         ==> ~ 50x realtime

         at 2x
         10m: 25s
         ==> 25x
         
         at 1x
         10m: 75s
         30m: 230s
         ==> ~8x realtime
         */
        
        ffRewindTimer?.invalidate()
        
        var accel: Double
        switch abs(rate) {
        case 0.5..<1.5:
            accel = 8
        case 1.5..<2.5:
            accel = 25
        case 2.5..<3.5:
            accel = 50
        case 3.5..<4.5:
            accel = 100
        default:
            accel = 1
        }
        
        if rate < 0 {
            accel = -accel
        }
        
        let timeSlice: Double = 0.1
        let workLength = mediaPlayer.item.length
        let skip = timeSlice * accel
        ffRewindTimer = Timer.scheduledTimer(withTimeInterval: timeSlice, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let newPosition = MediaPlayerViewController.newPositionByAdjustingPosition(self.controls.position, bySeconds: skip, length: workLength)
            self.controls.position = newPosition
            if Int(Date().timeIntervalSinceReferenceDate * 10) % 10 == 0 {
                self.mediaPlayer.position = newPosition
            }
            if newPosition <= 0 || newPosition >= 1 {
                timer.invalidate()
                self.pause()
            }
        }
    }
    
    @objc private func menuPressed() {
        pause()
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
        if controls.lineView.isFocused {
            controls.position = newProgress
        } else {
            controls.position = initialPanningPosition
        }
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
    
    public static func newPositionByAdjustingPosition(_ position:Double, bySeconds seconds:Double, length:TimeInterval) -> Double {
        let delta = seconds / length
        var newPosition = position + delta
        newPosition = max(newPosition, 0.0)
        newPosition = min(newPosition, 1.0)
        return newPosition
    }

    @objc fileprivate func selectPressed() {
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
                rightButtonTapped()
            case .left:
                leftButtonTapped()
            case .up:
                longJumpAhead()
            case .down:
                longJumpBack()
            }
        case .pause:
            if !mediaPlayer.isPlayingAd {
                mediaPlayer.position = controls.position
            }
            playerState = .standardPlay
        }
    }

    @objc fileprivate func playPressed() {
        let state = playerState
        switch state {
        case .pause, .fastforward, .rewind:
            playerState = .standardPlay
        case .standardPlay:
            playerState = .pause
        }
    }
    
    fileprivate func flashTimeBar() {
        controls.position = mediaPlayer.position
        controls.flashTimeBar()
    }
    
    fileprivate func mediaPlayerPositionChanged(_ position:Double) {
        if mediaPlayer.isPlayingAd {
            controls.adTimeRemainingLabel.isHidden = false
            let length = mediaPlayer.item.length
            if !position.isNaN, !position.isInfinite, !length.isNaN, !length.isInfinite {
                let secondsRemaining = max(Int( length - position * length), 0)
                controls.adTimeRemainingLabel.attributedText = controls.controlsCustomization.adSecondsRemainingString(secondsRemaining)
            } else {
                controls.adTimeRemainingLabel.attributedText = nil
            }
        } else {
            controls.adTimeRemainingLabel.isHidden = true
            controls.adTimeRemainingLabel.attributedText = nil
            controls.position = position
        }
    }
    
}

extension MediaPlayerViewController: ControlsOverlayViewControllerDelegate {
    func scrubberButtonTapped() {
        //selectPressed()
    }
}

extension MediaPlayerViewController {
    override open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for item in presses {
            //NSLog("***** presses began for type: %d", item.type.rawValue)
            switch item.type {
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

extension MediaPlayerViewController {
    open override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.previouslyFocusedView === controls.lineView,
           context.nextFocusedView !== controls.lineView {
            panGestureRecognizer.isEnabled = false
        } else if context.nextFocusedView === controls.lineView {
            panGestureRecognizer.isEnabled = true
        }
    }
}

//
//  Created by Bart Whiteley on 10/4/15.
//  Copyright © 2015 SwiftBit. All rights reserved.
//
