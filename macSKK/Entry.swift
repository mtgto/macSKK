// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct Entry {
    let yomi: Substring
    let candidates: [Word]

    init?(line: String, dictId: FileDict.ID) {
        if line.first == ";" {
            // コメント行
            return nil
        }
        let words = line.split(separator: " /", maxSplits: 1)
        if words.count != 2 || words[0].last == " " {
            return nil
        }
        yomi = words[0]
        guard let candidates = Self.parseWords(words[1], dictId: dictId) else { return nil }
        self.candidates = candidates
    }

    /**
     * - Parameters:
     *   - wordsText "胃/異/" のように先頭のスラッシュを除いた変換候補部分の文字列
     */
    static func parseWords(_ wordsText: Substring, dictId: FileDict.ID) -> [Word]? {
        if wordsText.isEmpty {
            return []
        } else if wordsText.first == "/" || wordsText.last != "/" {
            return nil
        }
        if wordsText.first == "[" {
            // 送り仮名ブロックのパース ややこしいからリファクタしたい
            let array = wordsText.dropFirst().split(separator: "]", maxSplits: 1)
            if array.count != 2 || array[1].first != "/" {
                return nil
            }
            guard let index = array[0].firstIndex(of: "/") else { return nil }
            if index == array[0].startIndex || index == array[0].endIndex {
                return nil
            }
            let yomi = array[0].prefix(upTo: index)
            let words = parseWords(array[0].suffix(from: index).dropFirst(), dictId: dictId)?.map { word in
                Word(word.word, okuri: String(yomi), annotation: word.annotation)
            }
            guard let words else { return nil }
            guard let rest = parseWords(array[1].dropFirst(), dictId: dictId) else { return nil }
            return words + rest
        } else {
            let array = wordsText.split(separator: "/", maxSplits: 1)
            switch array.count {
            case 1:
                return [parseWord(array[0], dictId: dictId)]
            case 2:
                let word = parseWord(array[0], dictId: dictId)
                guard let words = parseWords(array[1], dictId: dictId) else { return nil }
                return [word] + words
            default:
                return nil
            }
        }
    }

    static func parseWord(_ wordText: Substring, dictId: FileDict.ID) -> Word {
        let words = wordText.split(separator: Character(";"), maxSplits: 1)
        let annotation: Annotation?
        if words.count == 2 {
            // 注釈の先頭に "*" がついていたらユーザー独自の注釈を表す
            let annotationText = words[1].first == "*" ? words[1].dropFirst() : words[1]
            annotation = Annotation(dictId: dictId, text: Self.decode(String(annotationText)))
        } else {
            annotation = nil
        }
        return Word(Self.decode(String(words[0])), annotation: annotation)
    }

    static func decode(_ word: String) -> String {
        if word.hasPrefix(#"(concat ""#) && word.hasSuffix(#"")"#) {
            return String(word.dropFirst(9).dropLast(2).replacingOccurrences(of: "\\057", with: "/"))
        } else {
            return word
        }
    }
}
