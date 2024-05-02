// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// リリースされたバージョン番号。PackageDescription.Versionと同じようにセマンティックバージョニングを採用しています。
struct ReleaseVersion: Comparable, CustomStringConvertible, Sendable {
    // 将来その下にベータとかアルファの情報を追加するかも
    let major: Int
    let minor: Int
    let patch: Int

    var description: String {
        return "\(major).\(minor).\(patch)"
    }

    static let pattern = /([0-9]+)\.([0-9]+)\.([0-9]+)/

    // Comparable
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        } else if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        } else {
            return lhs.patch < rhs.patch
        }
    }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(string: String) {
        if let match = string.wholeMatch(of: Self.pattern) {
            if let major = Int(match.1), let minor = Int(match.2), let patch = Int(match.3) {
                self.major = major
                self.minor = minor
                self.patch = patch
                return
            }
        }
        return nil
    }
}
