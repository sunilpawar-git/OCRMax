//
//  ContentView.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScanView()
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan")
                }
                .tag(0)
            
            LibraryView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("Library")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
