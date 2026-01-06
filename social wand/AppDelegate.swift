//
//  AppDelegate.swift
//  social wand
//

import CloudKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        CloudClipboardSyncService.shared.registerSubscription()
        CloudClipboardSyncService.shared.pushLocalChanges(requiresOpenAccess: false)
        CloudClipboardSyncService.shared.fetchRemoteChanges()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        CloudClipboardSyncService.shared.pushLocalChanges(requiresOpenAccess: false)
        CloudClipboardSyncService.shared.fetchRemoteChanges()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == CloudClipboardSyncService.subscriptionID else {
            completionHandler(.noData)
            return
        }

        CloudClipboardSyncService.shared.fetchRemoteChanges { success in
            completionHandler(success ? .newData : .failed)
        }
    }
}
