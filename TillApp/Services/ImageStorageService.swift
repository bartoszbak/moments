import UIKit
import Foundation

enum ImageStorageService {
    static let backgroundsDirectory: URL = makeDirectory(named: "backgrounds")
    static let thumbnailsDirectory: URL = makeDirectory(named: "thumbnails")

    private static func makeDirectory(named name: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Saves full-size image and 200px thumbnail for the given ID.
    /// Returns paths for both, or nil if encoding fails.
    static func save(image: UIImage, id: UUID) -> (backgroundPath: String, thumbnailPath: String)? {
        guard let fullData = compress(image, maxBytes: 1_500_000) else { return nil }

        let backgroundURL = backgroundsDirectory.appendingPathComponent("\(id.uuidString).jpg")
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")

        do {
            try fullData.write(to: backgroundURL)
            let thumbnail = image.resized(to: CGSize(width: 200, height: 200))
            guard let thumbData = thumbnail.jpegData(compressionQuality: 0.7) else { return nil }
            try thumbData.write(to: thumbnailURL)
        } catch {
            return nil
        }

        return (backgroundURL.path, thumbnailURL.path)
    }

    private static func compress(_ image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.9
        while quality > 0.1 {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }
        return image.jpegData(compressionQuality: 0.1)
    }
}

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
