// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

class MemoryDictTests: XCTestCase {
    func testParseSource() throws {
        let source = """
            ;; この行はコメント扱い
            ;; okuri-ari entries.
            あg /挙/揚/上/
            あb /浴/
            ;; okuri-nasi entries.
            Cyrillic /А/Б/В/Г/Д/Е/Ё/Ж/З/И/Й/К/Л/М/Н/О/П/Р/С/Т/У/Ф/Х/Ц/Ч/Ш/Щ/Ъ/Ы/Ь/Э/Ю/Я/
            Greek /Α/Β/Γ/Δ/Ε/Ζ/Η/Θ/Ι/Κ/Λ/Μ/Ν/Ξ/Ο/Π/Ρ/Σ/Τ/Υ/Φ/Χ/Ψ/Ω/
            cyrillic /а/б/в/г/д/е/ё/ж/з/и/й/к/л/м/н/о/п/р/с/т/у/ф/х/ц/ч/ш/щ/ъ/ы/ь/э/ю/я/
            greek /α/β/γ/δ/ε/ζ/η/θ/ι/κ/λ/μ/ν/ξ/ο/π/ρ/σ/τ/υ/φ/χ/ψ/ω/
            あ /阿/唖/亜/娃/
            けい /京;10^16/

            """
        let dict = try MemoryDict(dictId: "testDict", source: source, readonly: false)
        XCTAssertEqual(dict.entries["あg"]?.map { $0.word }, ["挙", "揚", "上"])
        XCTAssertEqual(dict.entries["あb"]?.map { $0.word }, ["浴"])
        XCTAssertEqual(dict.entries["あ"]?.map { $0.word }, ["阿", "唖", "亜", "娃"])
        XCTAssertEqual(dict.entries["けい"]?.map { $0.word }, ["京"])
        XCTAssertEqual(dict.okuriNashiYomis, ["けい", "あ", "greek", "cyrillic", "Greek", "Cyrillic"], "辞書登場順の逆順に並ぶ")
    }

    func testParseSpecialSource() throws {
        // Sampling from SKK-JISYO.L
        let source = """
            わi /湧;(spring) 泉が湧く/沸;(boil) お湯が沸く/涌;≒湧く/
            ao /(concat "and\\057or")/
            GPL /GNU General Public License;(concat "http:\\057\\057www.gnu.org\\057licenses\\057gpl.ja.html")/

            """
        let dict = try MemoryDict(dictId: "testDict", source: source, readonly: false)
        XCTAssertEqual(dict.entries["わi"]?.map { $0.word }, ["湧", "沸", "涌"])
        XCTAssertEqual(dict.entries["ao"]?.map { $0.word }, ["and/or"])
        XCTAssertEqual(dict.entries["GPL"]?.map { $0.annotation?.text }, ["http://www.gnu.org/licenses/gpl.ja.html"])
        XCTAssertEqual(dict.okuriNashiYomis, ["GPL", "ao"], "abbrev辞書の読みは末尾がアルファベットだが送り無し扱い")
    }

    func testParseIncludingUserAnnotation() throws {
        // 注釈の先頭のアスタリスクはユーザー自身の注釈を表す
        let source = """
            いぬ /犬;*かわいい/

            """
        let dict = try MemoryDict(dictId: "testDict", source: source, readonly: false)
        XCTAssertEqual(dict.entries["いぬ"]?.first?.annotation, Annotation(dictId: "testDict", text: "かわいい"))
    }

    func testAdd() throws {
        var dict = MemoryDict(entries: [:], readonly: false)
        XCTAssertEqual(dict.entryCount, 0)
        let word1 = Word("井")
        let word2 = Word("伊")
        dict.add(yomi: "い", word: word1)
        XCTAssertEqual(dict.refer("い"), [word1])
        XCTAssertEqual(dict.okuriNashiYomis, ["い"])
        dict.add(yomi: "う", word: Word("宇"))
        XCTAssertEqual(dict.okuriNashiYomis, ["い", "う"])
        dict.add(yomi: "い", word: word2)
        XCTAssertEqual(dict.refer("い"), [word2, word1])
        XCTAssertEqual(dict.okuriNashiYomis, ["う", "い"])
        dict.add(yomi: "い", word: word1)
        XCTAssertEqual(dict.refer("い"), [word1, word2])
        let annotation = Annotation(dictId: "test", text: "宇の注釈")
        dict.add(yomi: "う", word: Word("宇", annotation: annotation))
        XCTAssertEqual(dict.refer("う"), [Word("宇", annotation: annotation)])
        // 注釈なしで登録済みのエントリを上書きしても注釈が残る
        dict.add(yomi: "う", word: Word("宇", annotation: nil))
        XCTAssertEqual(dict.refer("う"), [Word("宇", annotation: annotation)])
        let annotation2 = Annotation(dictId: "test2", text: "宇の注釈の更新版")
        dict.add(yomi: "う", word: Word("宇", annotation: annotation2))
        XCTAssertEqual(dict.refer("う"), [Word("宇", annotation: annotation2)])
    }

    func testDelete() throws {
        var dict = MemoryDict(entries: ["あr": [Word("有"), Word("在")]], readonly: false)
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])
        XCTAssertFalse(dict.delete(yomi: "あr", word: "或"))
        XCTAssertTrue(dict.delete(yomi: "あr", word: "在"))
        XCTAssertEqual(dict.refer("あr"), [Word("有")])
        XCTAssertFalse(dict.delete(yomi: "いいい", word: "いいい"))
        XCTAssertFalse(dict.delete(yomi: "あr", word: "在"))
        XCTAssertTrue(dict.delete(yomi: "あr", word: "有"))
        XCTAssertEqual(dict.okuriAriYomis, [])
    }
}
