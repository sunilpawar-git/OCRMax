//
//  CameraView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import SwiftUI
import VisionKit
import UIKit
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Check camera availability and permissions
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return createErrorViewController(message: "Camera not available on this device")
        }
        
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .denied, .restricted:
            return createErrorViewController(message: "Camera access denied. Please enable in Settings.")
        case .notDetermined:
            // Permission will be requested automatically by UIImagePickerController
            break
        case .authorized:
            break
        @unknown default:
            break
        }
        
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        return picker
    }
    
    private func createErrorViewController(message: String) -> UIViewController {
        let alertController = UIAlertController(title: "Camera Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            isPresented = false
        })
        
        let viewController = UIViewController()
        DispatchQueue.main.async {
            viewController.present(alertController, animated: true)
        }
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

