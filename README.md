# TVMediaPlayer
A media player view controller for tvOS similar to AVPlayerViewController, but not limited to AVPlayer.

This framework is used by the MythTV app for tvOS, which uses libVLC instead of AVPlayer.

## Usage
Instantiate a `MediaPlayerViewController` with an object conforming to the `MediaPlayerType` protocol.

Use the `canvasView` property of the `MediaPlayerViewController` to present content.

## Protocols
### MediaPlayerType
```swift
public protocol MediaPlayerType {
    
    func pause()
    func play()
    
    /// The current item being played.
    var item:MediaItemType { get }
    
    /// The rate of playback. 1.0 is the standard rate.
    var rate:Float { get set }
    
    /// The position between 0.0 and 1.0. Setting the position
    /// causes playback to move to the new position.
    var position:Float { get set }
    
    /// During playback, call this closure at intervals frequently 
    /// enough to allow the scrubber to update smoothly, if visible.
    var positionChanged:((position:Float) -> Void)? { get set }
}
```
### MediaItemType
```swift
public protocol MediaItemType {
    var title:String { get }
    var subtitle:String? { get }
    
    /// The length of the media item in seconds.
    var length:Double { get }
}
```

## Thumbnails
You can optionally provide thumbnails on the scrubber by setting the `thumbnailDelegate` on the `MediaPlayerViewController`.

### Thumbnail Protocols
```swift
public protocol MediaPlayerThumbnailSnapshotDelegate: NSObjectProtocol {
    /**
     A thumbnail image is requested at the given position and size.
     
     - param position: The position of the requested snapshot.
     
     - param size: The size of the requested thumbnail image.
     
     - param handler: A thumbnail handler to deliver the image to.
    */
    func snapshotImageAtPosition(position:Float, size:CGSize, handler:MediaPlayerThumbnailHandler)
}
```
The delegate should produce a thumbnail image at the requested position and pass it to the `MediaPlayerThumbnailHandler`.

```
public protocol MediaPlayerThumbnailHandler: NSObjectProtocol {
    /**
     Deliver a thumbnail image for the specified position.
     
     - param image: The thumbnail image.
     
     - param position: The position represented by the image.
     */
    func setSnapshotImage(image:UIImage, forPosition position:Float)
}
```
