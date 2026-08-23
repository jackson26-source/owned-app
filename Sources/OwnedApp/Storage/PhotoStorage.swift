import UIKit

/// Saves receipt photos as plain JPEG files in the app's own Documents
/// directory — same local-only principle as ItemStore. Nothing here ever
/// touches the network.
enum PhotoStorage {
      static func save(_ image: UIImage) -> String? {
                guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
                let filename = "receipt-\(UUID().uuidString).jpg"
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url = documents.appendingPathComponent(filename)
                do {
                              try data.write(to: url, options: [.atomic])
                              return filename
                } catch {
                              print("PhotoStorage: failed to save photo — \(error)")
                              return nil
                }
      }

      static func load(filename: String) -> UIImage? {
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url = documents.appendingPathComponent(filename)
                return UIImage(contentsOfFile: url.path)
      }
}
