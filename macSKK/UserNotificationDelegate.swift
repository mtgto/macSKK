// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import UserNotifications

class UserNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        logger.log("UserNotification didReceive \(response.notification.request.identifier, privacy: .public)")
        if response.notification.request.identifier == Release.userNotificationIdentifier {
            if let userInfo = response.notification.request.content.userInfo[Release.userNotificationUserInfoKey] as? [String: Any],
               let urlString = userInfo[Release.userNotificationUserInfoNameUrl] as? String,
               let url = URL(string: urlString) {
                // リリースページを開く
                _ = NSWorkspace.shared.open(url)
            }
        }
    }
}
