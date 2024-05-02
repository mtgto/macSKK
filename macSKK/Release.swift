// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct Release: Sendable {
    let version: ReleaseVersion
    let updated: Date
    let url: URL
}
