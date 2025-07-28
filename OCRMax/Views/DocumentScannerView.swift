//
//  DocumentScannerView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import SwiftUI
import VisionKit
import UIKit

@available(iOS 13.0, *)
struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onDocumentsScanned: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        
        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var scannedImages: [UIImage] = []
            
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                scannedImages.append(image)
            }
            
            parent.onDocumentsScanned(scannedImages)
            parent.isPresented = false
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.isPresented = false
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.isPresented = false
        }
    }
}