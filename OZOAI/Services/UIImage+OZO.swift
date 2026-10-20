import UIKit

extension UIImage {
    /// Downsizes the image so its longest edge is no larger than `maxDimension`.
    func ozoResized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }

        let ratio = maxDimension / longest
        let target = CGSize(width: max(1, size.width * ratio), height: max(1, size.height * ratio))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Produces a compact JPEG that is safe to store and send to a vision model.
    func ozoJPEGData(maxDimension: CGFloat = 1400, quality: CGFloat = 0.72) -> Data? {
        ozoResized(maxDimension: maxDimension).jpegData(compressionQuality: quality)
    }
}
