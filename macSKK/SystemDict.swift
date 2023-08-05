// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Dictionary Serviceを使ってシステム辞書から検索する
class SystemDict {
    class func lookup(_ word: String) -> String? {
        var dictionary: DCSDictionary? = nil
        if let result = DCSCopyTextDefinition(dictionary, word as NSString, CFRangeMake(0, word.count)) {
            return result.takeRetainedValue() as String
        }
        return nil
    }
}
