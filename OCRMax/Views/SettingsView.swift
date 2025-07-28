//
//  SettingsView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 28/07/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredOCREngine") private var preferredOCREngine = "Vision"
    @AppStorage("exportFormat") private var exportFormat = "RTF"
    @AppStorage("batchSize") private var batchSize = 25
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    
    var body: some View {
        NavigationStack {
            Form {
                // OCR Settings
                Section("OCR Settings") {
                    Picker("OCR Engine", selection: $preferredOCREngine) {
                        Text("Apple Vision").tag("Vision")
                        Text("Tesseract").tag("Tesseract")
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Export Format", selection: $exportFormat) {
                        Text("RTF").tag("RTF")
                        Text("DOCX").tag("DOCX")
                        Text("TXT").tag("TXT")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Batch Size")
                            Spacer()
                            Text("\(batchSize) pages")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(batchSize) },
                            set: { batchSize = Int($0) }
                        ), in: 10...50, step: 5)
                        
                        Text("Smaller batch sizes use less memory but take longer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // App Settings
                Section("App Settings") {
                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                    
                    NavigationLink("Storage & Cache") {
                        StorageView()
                    }
                    
                    NavigationLink("Help & Support") {
                        HelpView()
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                    
                    Button("Rate OCR Max") {
                        // TODO: Open App Store rating
                    }
                    .foregroundColor(.blue)
                }
                
                // Debug (Development only)
                #if DEBUG
                Section("Debug") {
                    Button(action: clearAllData) {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    
                    Button("Test OCR Performance") {
                        // TODO: Run performance test
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func clearAllData() {
        // TODO: Clear Core Data and UserDefaults
        print("Clearing all data...")
    }
}

struct StorageView: View {
    @State private var cacheSize = "0 MB"
    @State private var documentsCount = 0
    
    var body: some View {
        Form {
            Section("Storage Usage") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(cacheSize)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Processed Documents")
                    Spacer()
                    Text("\(documentsCount)")
                        .foregroundColor(.secondary)
                }
                
                Button(action: clearCache) {
                    Label("Clear Cache", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            
            Section("Data Management") {
                Toggle("Auto-delete after 30 days", isOn: .constant(false))
                
                Button("Export All Documents") {
                    // TODO: Export all documents
                }
                .foregroundColor(.blue)
            }
        }
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateStorageUsage()
        }
    }
    
    private func clearCache() {
        // TODO: Clear cache files
        cacheSize = "0 MB"
    }
    
    private func calculateStorageUsage() {
        // TODO: Calculate actual storage usage
        cacheSize = "2.5 MB"
        documentsCount = 0
    }
}

struct HelpView: View {
    var body: some View {
        Form {
            Section("Getting Started") {
                NavigationLink("How to Scan Documents") {
                    HelpDetailView(title: "How to Scan Documents", content: scanningHelpContent)
                }
                
                NavigationLink("Best Scanning Practices") {
                    HelpDetailView(title: "Best Scanning Practices", content: bestPracticesContent)
                }
                
                NavigationLink("Supported File Types") {
                    HelpDetailView(title: "Supported File Types", content: fileTypesContent)
                }
            }
            
            Section("Troubleshooting") {
                NavigationLink("OCR Not Working") {
                    HelpDetailView(title: "OCR Not Working", content: troubleshootingContent)
                }
                
                NavigationLink("Poor Text Recognition") {
                    HelpDetailView(title: "Poor Text Recognition", content: qualityTipsContent)
                }
            }
            
            Section("Contact") {
                Link("Email Support", destination: URL(string: "mailto:support@ocrmax.com")!)
                Link("Report a Bug", destination: URL(string: "https://github.com/ocrmax/issues")!)
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private let scanningHelpContent = """
    1. Position your document on a flat surface with good lighting
    2. Tap the camera button to take a photo
    3. Adjust the corners if needed
    4. Tap "Use Photo" to process
    5. Wait for OCR processing to complete
    6. Export to your preferred format
    """
    
    private let bestPracticesContent = """
    • Use good lighting - natural light works best
    • Keep the document flat and avoid shadows
    • Ensure text is clearly visible and not blurry
    • For best results, use high contrast documents
    • Clean the camera lens for sharp images
    """
    
    private let fileTypesContent = """
    Input Formats:
    • PDF files (up to 2000 pages, 200MB)
    • JPEG images
    • PNG images
    
    Export Formats:
    • RTF (Rich Text Format)
    • DOCX (Microsoft Word)
    • TXT (Plain Text)
    """
    
    private let troubleshootingContent = """
    If OCR is not working:
    1. Check your internet connection
    2. Ensure the document is clearly visible
    3. Try switching OCR engines in Settings
    4. Restart the app
    5. Contact support if issues persist
    """
    
    private let qualityTipsContent = """
    To improve text recognition:
    • Use documents with clear, dark text
    • Avoid handwritten text when possible
    • Ensure proper lighting without glare
    • Hold the device steady while scanning
    • Use the document scanner for best results
    """
}

struct HelpDetailView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(content)
                    .font(.body)
                    .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    SettingsView()
}