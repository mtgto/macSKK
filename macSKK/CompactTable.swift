// SPDX-FileCopyrightText: 2026 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 読みでソート済みのキー配列と、平坦化した変換候補の配列で辞書のエントリを持つ読み込み専用のテーブル。
///
/// `[String: [Word]]` に比べてハッシュテーブルと読みごとの配列のオーバーヘッドがないぶんメモリ効率がよい。
/// 読みの比較は `Dictionary` のキーの同一性と揃えるため `String` の `<` (正規等価) を使う。
struct CompactTable: Sendable {
    /// 読みの昇順。重複なし
    let keys: [String]
    /// `keys[i]` の候補は `words[starts[i]..<starts[i+1]]`。`starts.count == keys.count + 1`
    private let starts: [UInt32]
    private let words: [Word]

    /// - Parameters:
    ///   - entries: 登場順のエントリ。同じ読みが複数あれば候補を登場順に連結する。ソート済みでなければ読みでソートする。
    nonisolated init(entries: [(yomi: String, words: [Word])]) {
        var isSorted = true
        for i in entries.indices.dropFirst() where entries[i].yomi < entries[i - 1].yomi {
            isSorted = false
            break
        }
        let order: [Int]
        if isSorted {
            order = Array(entries.indices)
        } else {
            // 同じ読みの登場順を保つため元の添字をタイブレークにする
            order = entries.indices.sorted { lhs, rhs in
                let (l, r) = (entries[lhs].yomi, entries[rhs].yomi)
                return l < r || (!(r < l) && lhs < rhs)
            }
        }
        var keys: [String] = []
        var starts: [UInt32] = []
        var words: [Word] = []
        for index in order {
            let entry = entries[index]
            // 先頭のキーは必ず新規、以降は直前のキーと同じ(正規等価)なら連結する
            if keys.isEmpty || keys[keys.count - 1] < entry.yomi {
                keys.append(entry.yomi)
                starts.append(UInt32(words.count))
            }
            words.append(contentsOf: entry.words)
        }
        starts.append(UInt32(words.count))
        self.keys = keys
        self.starts = starts
        self.words = words
    }

    /// 読みの数
    nonisolated var count: Int { keys.count }

    /// 読みに対応する変換候補を二分探索で返す。見つからなければnilを返す。
    nonisolated func words(of yomi: String) -> [Word]? {
        var low = 0
        var high = keys.count
        while low < high {
            let mid = low + (high - low) / 2
            if keys[mid] < yomi {
                low = mid + 1
            } else {
                high = mid
            }
        }
        guard low < keys.count, !(yomi < keys[low]) else { return nil }
        return words(at: low)
    }

    /// 読みの昇順に全エントリを返す。
    nonisolated func allEntries() -> [(yomi: String, words: [Word])] {
        keys.indices.map { (yomi: keys[$0], words: words(at: $0)) }
    }

    private nonisolated func words(at index: Int) -> [Word] {
        Array(words[Int(starts[index])..<Int(starts[index + 1])])
    }
}
