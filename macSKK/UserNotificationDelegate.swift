// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import UserNotifications

class UserNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == Release.userNotificationIdentifier {
            if let userInfo = response.notification.request.content.userInfo[Release.userNotificationUserInfoKey] as? [String: Any],
               let urlString = userInfo[Release.userNotificationUserInfoNameUrl] as? String,
               let url = URL(string: urlString) {
                // リリースページを開く
                if !NSWorkspace.shared.open(url) {
                    logger.warning("新しいバージョンの通知をタップしたがリリースページを開くことができませんでした。")
                }
            } else {
                logger.error("通知メッセージにリリースページの情報が含まれていません。バグの可能性が高いです")
            }
        } else if response.notification.request.identifier == UNNotifier.userNotificationSettingsSyncedIdentifier {
            // 取り込んだ設定を確認できるよう設定画面を開く
            if #available(macOS 14, *) {
                NotificationCenter.default.post(name: notificationNameOpenSettings, object: nil)
            } else {
                Task { @MainActor in
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        completionHandler()
    }
}
