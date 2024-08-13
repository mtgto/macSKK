// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Dictionary Serviceを使ってシステム辞書から検索する
@MainActor class SystemDict {
    enum Kind: String, CaseIterable, Identifiable {
        case daijirin = "com.apple.dictionary.ja.Daijirin"
        case wisdom = "com.apple.dictionary.ja-en.WISDOM"
        var id: Self { self }
    }
    private static let dictionaries: [Kind: DCSDictionary] = {
        return Dictionary(Kind.allCases.compactMap { kind in
            if let dictionary = findSystemDict(identifier: kind.rawValue) {
                return (kind, dictionary)
            } else {
                return nil
            }
        }, uniquingKeysWith: { (first, _) in first })
    }()

    class func lookup(_ word: String, for kind: Kind) -> String? {
        if let dictionary = dictionaries[kind], let result = DCSCopyTextDefinition(dictionary, word as NSString, CFRangeMake(0, word.count)) {
            return result.takeRetainedValue() as String
        }
        return nil
    }

    class func findSystemDict(identifier: String) -> DCSDictionary? {
        guard let dictionaries = DCSCopyAvailableDictionaries() as? Set<DCSDictionary> else {
            logger.error("システム辞書が見つかりません")
            return nil
        }
        let dictionary = dictionaries.first {
            DCSDictionaryGetIdentifier($0) == identifier
        }
        if let dictionary {
            return dictionary
        } else {
            logger.warning("システム辞書 \(identifier, privacy: .public) が利用可能な辞書にありませんでした")
            return nil
        }
    }
}

