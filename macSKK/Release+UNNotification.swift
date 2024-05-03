// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UserNotifications

extension Release {
    /// 新しいバージョンが出たときの通知のID。通知を識別するために使うので将来はバージョンごとに異なるようにするかも。
    static let userNotificationIdentifier = "net.mtgto.inputmethod.macSKK.userNotification.newVersion"
    static let userNotificationUserInfoKey = "ReleaseVersion"
    static let userNotificationUserInfoNameUrl = "url"

    /**
     * 新しいバージョンが出たことを通知するための通知リクエストを作成します。
     */
    func userNotificationRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "UNNewVersionTitle", comment: "新しいバージョンがあります")
        content.body = String(format: String(localized: "UNNewVersionBody", comment: ""), version.description)
        content.userInfo[Self.userNotificationUserInfoKey] = [Self.userNotificationUserInfoNameUrl: url.absoluteString]

        let request = UNNotificationRequest(identifier: Self.userNotificationIdentifier, content: content, trigger: nil)
        return request
    }
}
