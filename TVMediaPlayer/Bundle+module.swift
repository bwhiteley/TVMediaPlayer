
import Foundation

#if !SWIFT_PACKAGE
extension Bundle {
    class BundleClass {}
    static let module = Bundle(for: BundleClass.self)
}
#endif
