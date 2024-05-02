// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Dictionary Serviceを使ってシステム辞書から検索する
@MainActor class SystemDict {
    private static let dictionary: DCSDictionary? = findSystemJapaneseDict()

    class func lookup(_ word: String) -> String? {
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
        let dictionary = dictionaries.first {
            // DCSDictionaryGetNameは "スーパー大辞林"
            DCSDictionaryGetIdentifier($0) == "com.apple.dictionary.ja.Daijirin"
        }
        if let dictionary {
            return dictionary
        } else {
            logger.warning("スーパー大辞林が利用可能な辞書にありませんでした")
            return nil
        }
    }
}
