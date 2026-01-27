//
//  PhotoPicker.swift
//  social wand
//

import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedPhotos: [UIImage]
    let selectionLimit: Int
    let append: Bool
    let onStartLoading: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    
    init(
        selectedPhotos: Binding<[UIImage]>,
        selectionLimit: Int = 5,
        append: Bool = false,
        onStartLoading: (() -> Void)? = nil
    ) {
        self._selectedPhotos = selectedPhotos
        self.selectionLimit = selectionLimit
        self.append = append
        self.onStartLoading = onStartLoading
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = selectionLimit // Maximum photos per session
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // ✅ FIX: Don't dismiss immediately if user selected photos
            guard !results.isEmpty else {
                // User canceled - dismiss immediately
                parent.dismiss()
                return
            }
            
            print("📸 PhotoPicker: User selected \(results.count) photos - loading images...")
            DispatchQueue.main.async {
                self.parent.onStartLoading?()
            }
            
            // ✅ FIX: Wait for ALL images to load using DispatchGroup
            let group = DispatchGroup()
            var loadedImages: [UIImage] = []
            
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    defer { group.leave() }
                    
                    if let image = object as? UIImage {
                        // ✅ Compress immediately to reduce memory
                        let compressed = image.resized(toMaxDimension: 1024)
                        loadedImages.append(compressed)
                        print("📸 PhotoPicker: Loaded image \(loadedImages.count)/\(results.count)")
                    } else if let error = error {
                        print("❌ PhotoPicker: Failed to load image - \(error.localizedDescription)")
                    }
                }
            }
            
            // ✅ FIX: Wait for all images to load, THEN update binding and dismiss
            group.notify(queue: .main) {
                print("✅ PhotoPicker: All images loaded (\(loadedImages.count)), updating binding and dismissing")
                
                // Update binding with all images at once
                if self.parent.append {
                    self.parent.selectedPhotos.append(contentsOf: loadedImages)
                } else {
                    self.parent.selectedPhotos = loadedImages
                }
                
                // NOW dismiss after images are loaded
                self.parent.dismiss()
            }
        }
    }
}
