//
//  social_wandApp.swift
//  social wand
//
//  Created by Trishali Rao on 11/6/25.
//

import SwiftUI

@main
struct social_wandApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showPhotoUpload = false
    @State private var photoUploadSourceApp = "instagram"
    @State private var uploadSessionID = UUID()  // NEW: Forces view recreation
    @State private var showSettings = false  // ✅ NEW: Track settings navigation
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    // Returning users: Show HomeView
                    HomeView()
                } else {
                    // First-time users: Show onboarding
                    ContentView()
                }
            }
            .onAppear {
                checkPendingPhotoUpload()
            }
            .onOpenURL { url in
                handleURL(url)
            }
            .fullScreenCover(isPresented: $showPhotoUpload) {
                PhotoUploadView(sourceApp: photoUploadSourceApp)
                    .id(uploadSessionID)  // Forces new instance on each upload
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
    
    private func checkPendingPhotoUpload() {
        guard let defaults = UserDefaults(suiteName: "group.rishi-more.social-wand"),
              defaults.bool(forKey: "PendingPhotoUpload") else {
            return
        }
        
        // Check if request is recent (within last 5 minutes)
        if let requestTime = defaults.object(forKey: "PhotoUploadRequestTime") as? Date,
           Date().timeIntervalSince(requestTime) < 300 {
            
            // Get source app
            photoUploadSourceApp = defaults.string(forKey: "PhotoUploadSourceApp") ?? "instagram"
            
            // Clear the flag
            defaults.set(false, forKey: "PendingPhotoUpload")
            defaults.removeObject(forKey: "PhotoUploadRequestTime")
            
            print("✅ Detected pending photo upload request")
            
            // CRITICAL: Generate new session ID to force view recreation
            uploadSessionID = UUID()
            print("🔄 Generated new upload session: \(uploadSessionID)")
            
            // Show photo upload
            showPhotoUpload = true
        } else {
            // Request too old, clear it
            defaults.set(false, forKey: "PendingPhotoUpload")
            defaults.removeObject(forKey: "PhotoUploadRequestTime")
        }
    }
    
    private func handleURL(_ url: URL) {
        print("🔗 URL received: \(url)")
        
        guard url.scheme == "socialwand" else {
            print("❌ Invalid URL scheme")
            return
        }
        
        // Handle settings URL
        if url.host == "settings" {
            print("✅ Valid socialwand://settings URL")
            print("🚀 Showing SettingsView")
            showSettings = true
            return
        }
        
        // Handle upload URL
        guard url.host == "upload" else {
            print("❌ Invalid URL host: \(url.host ?? "nil")")
            return
        }
        
        print("✅ Valid socialwand://upload URL")
        
        // Extract source app from query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let sourceItem = queryItems.first(where: { $0.name == "source" }),
           let source = sourceItem.value {
            photoUploadSourceApp = source
            print("✅ Source app from URL: \(source)")
        } else {
            photoUploadSourceApp = "instagram"
            print("⚠️ No source parameter, defaulting to instagram")
        }
        
        // CRITICAL: Generate new session ID to force view recreation
        uploadSessionID = UUID()
        print("🔄 Generated new upload session: \(uploadSessionID)")

        print("🚀 Showing PhotoUploadView")
        showPhotoUpload = true
    }
}
