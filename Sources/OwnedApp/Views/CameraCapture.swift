import SwiftUI
import UIKit

/// A thin SwiftUI wrapper around UIImagePickerController's camera source.
///
/// This is Phase 1's receipt-capture mechanism: no OCR yet, just "take a
/// photo of the receipt and attach it to the item." Extracting the date,
/// price, and retailer automatically from that photo (real OCR, via
/// VisionKit's text recognition) is a natural next step, but it wasn't
/// worth blocking the first working version on — a person can still type
/// those three fields in about ten seconds, and the photo is saved either
/// way as the source of truth if a claim is ever needed.
struct CameraCapture: UIViewControllerRepresentable {
      var onCapture: (UIImage) -> Void
      @Environment(\.dismiss) private var dismiss

      func makeUIViewController(context: Context) -> UIImagePickerController {
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.delegate = context.coordinator
                return picker
      }

      func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

      func makeCoordinator() -> Coordinator {
                Coordinator(onCapture: onCapture, dismiss: dismiss)
      }

      final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
                let onCapture: (UIImage) -> Void
                let dismiss: DismissAction

                init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
                              self.onCapture = onCapture
                              self.dismiss = dismiss
                }

                func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
                              if let image = info[.originalImage] as? UIImage {
                                                onCapture(image)
                              }
                              dismiss()
                }

                func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                              dismiss()
                }
      }
}
