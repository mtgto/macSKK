// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Dictionary Serviceを使ってシステム辞書から検索する
class SystemDict {
    class func lookup(_ word: String) -> String? {
        let dictionary: DCSDictionary? = findSystemJapaneseDict()
        if let result = DCSCopyTextDefinition(dictionary, word as NSString, CFRangeMake(0, word.count)) {
            return result.takeRetainedValue() as String
        }
        return nil
    }

    class func findSystemJapaneseDict() -> DCSDictionary? {
        guard let dictionaries = DCSCopyAvailableDictionaries() as? Set<DCSDictionary> else {
            logger.error("システム辞書が見つかりません")
            return nil
        }
        return dictionaries.first { dict in
            // DCSDictionaryGetNameだと"スーパー大辞林"
            return DCSDictionaryGetIdentifier(dict) == "com.apple.dictionary.ja.Daijirin"
        }
    }
}
