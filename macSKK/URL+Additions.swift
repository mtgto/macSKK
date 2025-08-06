// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension URL {
    /**
     * 読み込み可能なファイルかどうかを返す
     *
     * 隠しファイルでない、通常ファイルである(シンボリックリンクなどでない)、読み込み可能であるかどうかを調べる
     */
    func isReadable() throws -> Bool {
        let resourceValues = try resourceValues(forKeys: [.isReadableKey, .isRegularFileKey, .isHiddenKey])
        if let isHidden = resourceValues.isHidden, let isReadable = resourceValues.isReadable, let isRegularFile = resourceValues.isRegularFile {
            if isHidden {
                return false
            }
            if !isRegularFile {
                return false
            }
            if !isReadable {
                return false
            }
            return true
        } else {
            fatalError("isHidden, isReadable, isRegularFileの読み込みに失敗しました")
        }
    }
}
