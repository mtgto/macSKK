// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct Release: Sendable, Decodable {
    let version: ReleaseVersion
    let updated: Date
    let url: URL
    // HTML形式
    let content: String

    enum CodingKeys: String, CodingKey {
        case version = "name"
        case updated = "published_at"
        case url = "html_url"
        case content = "body"
    }
}
