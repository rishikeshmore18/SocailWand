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
    @State private var photoUploadPicker: UploadSource? = nil
    @State private var uploadSessionID = UUID()  // NEW: Forces view recreation
    @State private var showSettings = false  // ✅ NEW: Track settings navigation
    @State private var showEmailCompose = false
    @State private var emailSessionID = UUID()
    
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
                checkPendingEmailCompose()
            }
            .onOpenURL { url in
                handleURL(url)
            }
            .fullScreenCover(isPresented: $showPhotoUpload) {
                PhotoUploadView(sourceApp: photoUploadSourceApp, initialPicker: photoUploadPicker)
                    .id(uploadSessionID)  // Forces new instance on each upload
            }
            .fullScreenCover(isPresented: $showEmailCompose) {
                EmailComposeView()
                    .id(emailSessionID)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
    
    private func checkPendingPhotoUpload() {
        guard let defaults = UserDefaults(suiteName: "group.com.rishimore.socialwand"),
              defaults.bool(forKey: "PendingPhotoUpload") else {
            return
        }
        
        // Check if request is recent (within last 5 minutes)
        if let requestTime = defaults.object(forKey: "PhotoUploadRequestTime") as? Date,
           Date().timeIntervalSince(requestTime) < 300 {
            
            // Get source app
            photoUploadSourceApp = defaults.string(forKey: "PhotoUploadSourceApp") ?? "instagram"
            if let picker = defaults.string(forKey: "PhotoUploadPicker") {
                photoUploadPicker = uploadSource(from: picker)
                print("✅ Read picker type: \(picker) → \(String(describing: photoUploadPicker))")
                // ✅ DON'T remove picker here - let it be cleared after modal shows
            } else {
                photoUploadPicker = nil
                print("⚠️ No picker type found, will use default")
            }
            
            // Clear the flags immediately (but picker cleanup happens after modal shows)
            defaults.set(false, forKey: "PendingPhotoUpload")
            defaults.removeObject(forKey: "PhotoUploadRequestTime")
            
            print("✅ Detected pending photo upload request")
            
            // CRITICAL: Generate new session ID to force view recreation
            uploadSessionID = UUID()
            print("🔄 Generated new upload session: \(uploadSessionID)")
            
            // Show photo upload
            showPhotoUpload = true
            
            // ✅ Clear picker flag after modal is shown (delayed to ensure view receives it)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                defaults.removeObject(forKey: "PhotoUploadPicker")
                print("✅ Cleared PhotoUploadPicker flag after modal presented")
            }
        } else {
            // Request too old, clear it
            defaults.set(false, forKey: "PendingPhotoUpload")
            defaults.removeObject(forKey: "PhotoUploadRequestTime")
            defaults.removeObject(forKey: "PhotoUploadPicker")
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
        
        if url.host == "email" {
            print("✅ Valid socialwand://email URL")
            emailSessionID = UUID()
            showEmailCompose = true
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
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let pickerItem = queryItems.first(where: { $0.name == "picker" }),
           let picker = pickerItem.value {
            photoUploadPicker = uploadSource(from: picker)
        } else {
            photoUploadPicker = nil
        }
        
        // CRITICAL: Generate new session ID to force view recreation
        uploadSessionID = UUID()
        print("🔄 Generated new upload session: \(uploadSessionID)")

        print("🚀 Showing PhotoUploadView")
        showPhotoUpload = true
    }

    private func uploadSource(from rawValue: String) -> UploadSource? {
        switch rawValue {
        case "photos":
            return .photoLibrary
        case "camera":
            return .camera
        case "files":
            return .files
        default:
            return nil
        }
    }

    private func checkPendingEmailCompose() {
        guard let defaults = UserDefaults(suiteName: "group.com.rishimore.socialwand"),
              defaults.bool(forKey: "PendingEmailCompose") else {
            return
        }

        if let requestTime = defaults.object(forKey: "EmailComposeRequestTime") as? Date,
           Date().timeIntervalSince(requestTime) < 300 {
            defaults.set(false, forKey: "PendingEmailCompose")
            defaults.removeObject(forKey: "EmailComposeRequestTime")

            emailSessionID = UUID()
            showEmailCompose = true
        } else {
            defaults.set(false, forKey: "PendingEmailCompose")
            defaults.removeObject(forKey: "EmailComposeRequestTime")
        }
    }
}
