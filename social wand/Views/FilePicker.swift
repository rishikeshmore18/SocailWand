//
//  FilePicker.swift
//  social wand
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FilePicker: UIViewControllerRepresentable {
    @Binding var selectedPhotos: [UIImage]
    let selectionLimit: Int
    let onStartLoading: (() -> Void)?
    let onCancel: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
        picker.allowsMultipleSelection = selectionLimit > 1
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePicker
        
        init(_ parent: FilePicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !urls.isEmpty else {
                parent.dismiss()
                return
            }
            
            parent.onStartLoading?()
            
            var images: [UIImage] = []
            let remaining = max(0, self.parent.selectionLimit)
            let limited = urls.prefix(remaining)
            
            for url in limited {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let image = UIImage(contentsOfFile: url.path) {
                        images.append(image.resized(toMaxDimension: 1024))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.parent.selectedPhotos.append(contentsOf: images)
                self.parent.dismiss()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
            parent.onCancel?()
        }
    }
}
