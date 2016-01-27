# TVMediaPlayer
A media player view controller for tvOS similar to AVPlayerViewController, but not limited to AVPlayer.

## Usage
Instantiate a `MediaPlayerViewController` with an object conforming to the `MediaPlayerType` protocol.

Use the `canvasView` property of the `MediaPlayerViewController` to present content.

## Protocols
### MediaPlayerType
```
public protocol MediaPlayerType {
    func pause()
    func play()
    
    var item:MediaItemType { get }
    
    var rate:Float { get set }
    var position:Float { get set }
    
    var positionChanged:((position:Float) -> Void)? { get set }   
}
```
### MediaItemType
```
public protocol MediaItemType {
    var title:String { get }
    var subtitle:String? { get }
    var length:NSTimeInterval { get }
}
```

## Thumbnails
To provide thumbnails on the scrubber, set the `thumbnailDelegate` on the `MediaPlayerViewController`.

### Thumbnail Protocols
```
public protocol MediaPlayerThumbnailSnapshotDelegate: NSObjectProtocol {
    func snapshotImageAtPosition(position:Float, size:CGSize, handler:MediaPlayerThumbnailHandler)
}
```
The delegate should produce a thumbnail image at the requested position and pass it to the `MediaPlayerThumbnailHandler`.

```
public protocol MediaPlayerThumbnailHandler: NSObjectProtocol {
    func setSnapshotImage(image:UIImage, forPosition position:Float)
}
```