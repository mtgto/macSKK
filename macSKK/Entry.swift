// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * SKK辞書の一行をパースする
 */
struct Entry: Sendable {
    let yomi: String
    let candidates: [Word]

    /**
     * SKK辞書の一行を受け取り、パースする
     *
     * 読みの「う゛」は「ゔ」に変換して返す。
     * スラッシュで終わらないなど、変換候補エントリとして壊れている場合はnilを返す。
     * 空文字列の変換候補を含む場合、現状の実装では除外して返す。
     * 空文字列の変換候補には今後対応する予定。
     *
     * 例
     * - "あ //": 空文字列の変換候補はフィルタされて candidates = [] となる
     * - "あ /亜": セミコロンで終わってないのでnilを返す
     */
    init?(line: String, dictId: FileDict.ID) {
        if line.first == ";" {
            // コメント行
            return nil
        }
        let words = line.split(separator: " /", maxSplits: 1)
        if words.count != 2 || words[0].last == " " {
            return nil
        }
        yomi = String(words[0]).replacing("う゛", with: "ゔ")
        guard let candidates = Self.parseWords(words[1], dictId: dictId) else { return nil }
        // TODO: いまは空の変換候補をスキップしているが扱えるようにしたい
        self.candidates = candidates.filter { !$0.word.isEmpty }
    }

    init(yomi: String, candidates: [Word]) {
        self.yomi = yomi
        self.candidates = candidates
    }

    /**
     * SKK辞書の一行にシリアライズする
     */
    func serialize() -> String {
        return yomi + " /" + serializeWords(candidates)
    }

    private func serializeWords(_ words: [Word]) -> String {
        var result = ""
        var remainingWords = ArraySlice(words)

        while !remainingWords.isEmpty {
            let head = remainingWords.first!
            let tail = remainingWords.dropFirst()
            if let okuri = head.okuri {
                // 送り仮名ブロックの読みが一致しているものは1つにまとめる
                let sameOkuriWords = tail.filter { $0.okuri == okuri }
                remainingWords = tail.filter { $0.okuri != okuri }

                let candidatesStr = ([head] + sameOkuriWords).map { serializeWord($0) }.joined(separator: "/")
                result += "[\(okuri)/\(candidatesStr)/]/"
            } else {
                result += serializeWord(head) + "/"
                remainingWords = tail
            }
        }
        return result
    }

    private func serializeWord(_ word: Word) -> String {
        if let annotation = word.annotation {
            return serializeSpecialCharacters(word.word) + ";" + serializeSpecialCharacters(annotation.text)
        } else {
            return serializeSpecialCharacters(word.word)
        }
    }

    /// "/" と ";" は辞書の変換候補内では使用できないので `(concat "...\057...")` `(concat "...\073...")` のように変換する
    private func serializeSpecialCharacters(_ string: String) -> String {
        if string.contains("/") || string.contains(";") {
            return "(concat \"" + string.replacingOccurrences(of: "/", with: "\\057").replacingOccurrences(of: ";", with: "\\073") + "\")"
        }
        return string
    }

    /**
     * エントリの変換候補部分の先頭のスラッシュを取り除いた文字列をパースする。
     * 重複変換候補は最初に現れたものだけを残してあとは無視する。
     *
     * - Parameters:
     *   - wordsText "胃/異/" のように先頭のスラッシュを除いた変換候補部分の文字列
     */
    static func parseWords(_ wordsText: Substring, dictId: FileDict.ID) -> [Word]? {
        // 長すぎるとスタックオーバーフローで死ぬので送り仮名ブロック以外はループで処理
        var wordsText = wordsText
        var result: [Word] = []
        var added = Set<Word>()
        while true {
            if wordsText.isEmpty {
                return result
            } else if wordsText.last != "/" {
                return nil
            }
            if wordsText.first == "[" {
                // 送り仮名ブロックのパース ややこしいからリファクタしたい
                // 閉じカッコがない場合は送り仮名ブロックではなくただの開きカッコとして扱う
                let array = wordsText.dropFirst().split(separator: "]", maxSplits: 1)
                if array.count == 2 && array[1].first == "/" {
                    if let index = array[0].firstIndex(of: "/") {
                        if index == array[0].startIndex || index == array[0].endIndex {
                            return nil
                        }
                        let yomi = array[0].prefix(upTo: index)
                        let words = parseWords(array[0].suffix(from: index).dropFirst(), dictId: dictId)?.compactMap { word in
                            let wordWithOkuri = Word(word.word, okuri: String(yomi), annotation: word.annotation)
                            let (inserted, _) = added.insert(wordWithOkuri)
                            if inserted {
                                return wordWithOkuri
                            } else {
                                return nil
                            }
                        }
                        guard let words else { return nil }
                        result.append(contentsOf: words)
                        wordsText = array[1].dropFirst()
                    } else {
                        // スラッシュが含まれないときは送り仮名ブロックではない
                        result.append(parseWord(wordsText.dropLast(), dictId: dictId))
                        wordsText = array[1].dropFirst()
                    }
                    continue
                }
            }
            let array = wordsText.split(separator: "/", maxSplits: 1)
            switch array.count {
            case 1:
                let word = parseWord(array[0], dictId: dictId)
                let (inserted, _) = added.insert(word)
                if inserted {
                    result.append(word)
                }
                return result
            case 2:
                let word = parseWord(array[0], dictId: dictId)
                let (inserted, _) = added.insert(word)
                if inserted {
                    result.append(word)
                }
                wordsText = array[1]
            default:
                result.append(Word(""))
                return result
            }
        }
    }

    static func parseWord(_ wordText: Substring, dictId: FileDict.ID) -> Word {
        let words = wordText.split(separator: Character(";"), maxSplits: 1)
        let annotation: Annotation?
        if words.isEmpty {
            return Word("", annotation: nil)
        } else if words.count == 2 {
            annotation = parseAnnotation(words[1], dictId: dictId)
        } else if words.count == 1 && wordText.first == ";" {
            // 変換候補が空文字列で注釈だけある場合
            annotation = parseAnnotation(words[0], dictId: dictId)
            return Word("", annotation: annotation)
        } else {
            annotation = nil
        }
        return Word(Self.decode(String(words[0])), annotation: annotation)
    }

    static func parseAnnotation(_ text: Substring, dictId: FileDict.ID) -> Annotation {
        // 注釈の先頭に "*" がついていたらユーザー独自の注釈を表す
        let annotationText = text.first == "*" ? text.dropFirst() : text
        return Annotation(dictId: dictId, text: Self.decode(String(annotationText)))
    }

    static func decode(_ word: String) -> String {
        if word.hasPrefix(#"(concat ""#) && word.hasSuffix(#"")"#) {
            return String(word.dropFirst(9).dropLast(2).replacingOccurrences(of: "\\057", with: "/").replacingOccurrences(of: "\\073", with: ";"))
        } else {
            return word
        }
    }
}
