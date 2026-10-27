// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

class MemoryDictTests: XCTestCase {
    func testParseSource() throws {
        let source = """
            ;; この行はコメント扱い
            ;; okuri-ari entries.
            おおk /大/多/[く/多/]/[き/大/]/
            いt /[った/行/言/]/
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
        let dict = MemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.entries["あg"]?.map { $0.word }, ["挙", "揚", "上"])
        XCTAssertEqual(dict.entries["あb"]?.map { $0.word }, ["浴"])
        XCTAssertEqual(dict.entries["あ"]?.map { $0.word }, ["阿", "唖", "亜", "娃"])
        XCTAssertEqual(dict.entries["けい"]?.map { $0.word }, ["京"])
        XCTAssertEqual(dict.entries["おおk"]?.map { $0.word }, ["大", "多", "多", "大"])
        XCTAssertEqual(dict.okuriNashiYomis, ["けい", "あ", "greek", "cyrillic", "Greek", "Cyrillic"], "辞書登場順の逆順に並ぶ")
    }

    func testParseSpecialSource() throws {
        // スラッシュの使用例はSKK-JISYO.Lから。
        let source = """
            わi /湧;(spring) 泉が湧く/沸;(boil) お湯が沸く/涌;≒湧く/
            ao /(concat "and\\057or")/
            GPL /GNU General Public License;(concat "http:\\057\\057www.gnu.org\\057licenses\\057gpl.ja.html")/
            しゅたいんずげーと /(concat "Steins\\073Gate")/

            """
        let dict = MemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.entries["わi"]?.map { $0.word }, ["湧", "沸", "涌"])
        XCTAssertEqual(dict.entries["ao"]?.map { $0.word }, ["and/or"])
        XCTAssertEqual(dict.entries["GPL"]?.map { $0.annotation?.text }, ["http://www.gnu.org/licenses/gpl.ja.html"])
        XCTAssertEqual(dict.entries["しゅたいんずげーと"]?.map { $0.word }, ["Steins;Gate"])
        XCTAssertEqual(dict.okuriNashiYomis, ["しゅたいんずげーと", "GPL", "ao"], "abbrev辞書の読みは末尾がアルファベットだが送り無し扱い")
    }

    func testParseOkurikanaBlockAndExcpetions() throws {
        let source = """
            あれきさんどろす /[Alexandros]/

            """
        let dict = MemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.entries["あれきさんどろす"]?.map { $0.word }, ["[Alexandros]"])
    }

    func testParseDuplicatedYomi() throws {
        let source = """
            あお /青/
            あお /蒼/
            あお /碧/

            """
        let dict = MemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.entries["あお"]?.map { $0.word }, ["青", "蒼", "碧"])
    }

    func testParseIncludingUserAnnotation() throws {
        // 注釈の先頭のアスタリスクはユーザー自身の注釈を表す
        let source = """
            いぬ /犬;*かわいい/

            """
        let dict = MemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.entries["いぬ"]?.first?.annotation, Annotation(dictId: "testDict", text: "かわいい"))
    }

    func testParseEmptyCandidate() throws {
        // TODO: いまは空の変換候補をスキップしているが扱えるようにしたい
        let source = """
            から //

            """
        let dict = MemoryDict(dictId: "testDict", source: source)
        XCTAssertNil(dict.entries["から"])
    }

    @MainActor func testAdd() throws {
        var dict = MemoryDict(entries: [:])
        XCTAssertEqual(dict.entryCount, 0)
        let word1 = Word("井")
        let word2 = Word("伊")
        dict.add(yomi: "い", word: word1)
        XCTAssertEqual(dict.refer("い", option: nil), [word1])
        XCTAssertEqual(dict.okuriNashiYomis, ["い"])
        dict.add(yomi: "う", word: Word("宇"))
        XCTAssertEqual(dict.okuriNashiYomis, ["い", "う"])
        dict.add(yomi: "い", word: word2)
        XCTAssertEqual(dict.refer("い", option: nil), [word2, word1])
        XCTAssertEqual(dict.okuriNashiYomis, ["う", "い"])
        dict.add(yomi: "い", word: word1)
        XCTAssertEqual(dict.refer("い", option: nil), [word1, word2])
        let annotation = Annotation(dictId: "test", text: "宇の注釈")
        dict.add(yomi: "う", word: Word("宇", annotation: annotation))
        XCTAssertEqual(dict.refer("う", option: nil), [Word("宇", annotation: annotation)])
        // 注釈なしで登録済みのエントリを上書きしても注釈が残る
        dict.add(yomi: "う", word: Word("宇", annotation: nil))
        XCTAssertEqual(dict.refer("う", option: nil), [Word("宇", annotation: annotation)])
        let annotation2 = Annotation(dictId: "test2", text: "宇の注釈の更新版")
        dict.add(yomi: "う", word: Word("宇", annotation: annotation2))
        XCTAssertEqual(dict.refer("う", option: nil), [Word("宇", annotation: annotation2)])
        // 送り仮名ブロックありとなしは共存する
        dict.add(yomi: "いt", word: Word("行"))
        XCTAssertEqual(dict.refer("いt", option: nil), [Word("行")])
        dict.add(yomi: "いt", word: Word("行", okuri: "った"))
        XCTAssertEqual(dict.refer("いt", option: nil), [Word("行", okuri: "った"), Word("行")])
    }

    @MainActor func testAddAsOldest() throws {
        var dict = MemoryDict(entries: [:])
        dict.add(yomi: "い", word: Word("井"))
        dict.add(yomi: "う", word: Word("宇"))
        dict.addAsOldest(yomi: "い", word: Word("伊"))
        XCTAssertEqual(dict.refer("い", option: nil), [Word("井"), Word("伊")], "同じ読みがあれば変換候補の末尾に足す")
        XCTAssertEqual(dict.okuriNashiYomis, ["い", "う"], "既にある読みは動かさない")
        dict.addAsOldest(yomi: "あ", word: Word("亜"))
        XCTAssertEqual(dict.okuriNashiYomis, ["あ", "い", "う"], "ない読みは最も古く変換したものとして足す")
        dict.addAsOldest(yomi: "あr", word: Word("有"))
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])
        // 既にある変換候補は動かさず、注釈も変えない
        let annotation = Annotation(dictId: "test", text: "宇の注釈")
        dict.add(yomi: "う", word: Word("宇", annotation: annotation))
        dict.add(yomi: "う", word: Word("卯"))
        dict.addAsOldest(yomi: "う", word: Word("宇"))
        XCTAssertEqual(dict.refer("う", option: nil), [Word("卯"), Word("宇", annotation: annotation)])
        // 送り仮名ブロックありとなしは別の変換候補として扱う
        dict.addAsOldest(yomi: "いt", word: Word("行"))
        dict.addAsOldest(yomi: "いt", word: Word("行", okuri: "った"))
        XCTAssertEqual(dict.refer("いt", option: nil), [Word("行"), Word("行", okuri: "った")])
        dict.addAsOldest(yomi: "", word: Word("＞"))
        XCTAssertEqual(dict.refer("", option: nil), [], "空の見出しは登録しない")
    }

    @MainActor func testAddEmptyYomiIsIgnored() throws {
        // 空の見出しはSKK辞書エントリとして不正なので登録しない (シリアライズすると
        // " /候補/" のような壊れた行になり次回読み込みで失敗するため)
        var dict = MemoryDict(entries: [:])
        dict.add(yomi: "", word: Word("＞"))
        XCTAssertEqual(dict.entryCount, 0)
        XCTAssertEqual(dict.refer("", option: nil), [])
        XCTAssertEqual(dict.okuriNashiYomis, [])
    }

    @MainActor func testDelete() throws {
        var dict = MemoryDict(entries: ["あr": [Word("有"), Word("在")], "え": [Word("絵"), Word("柄")]])
        XCTAssertFalse(dict.entries.isEmpty)
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])
        XCTAssertEqual(dict.okuriNashiYomis, ["え"])
        XCTAssertFalse(dict.delete(yomi: "あr", word: Word("或")))
        XCTAssertFalse(dict.delete(yomi: "いr", word: Word("居")), "存在しないエントリを削除しようとする")
        XCTAssertFalse(dict.delete(yomi: "お", word: Word("尾")), "存在しないエントリを削除しようとする")
        XCTAssertTrue(dict.delete(yomi: "あr", word: Word("在")))
        XCTAssertTrue(dict.delete(yomi: "え", word: Word("絵")))
        XCTAssertEqual(dict.okuriAriYomis, ["あr"], "「有」がまだ残っている")
        XCTAssertEqual(dict.okuriNashiYomis, ["え"], "「柄」がまだ残っている")
        XCTAssertEqual(dict.refer("あr", option: nil), [Word("有")])
        XCTAssertFalse(dict.delete(yomi: "いいい", word: Word("いいい")))
        XCTAssertFalse(dict.delete(yomi: "あr", word: Word("在")), "削除済")
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])
        XCTAssertTrue(dict.delete(yomi: "あr", word: Word("有")))
        XCTAssertEqual(dict.okuriAriYomis, [])
        XCTAssertFalse(dict.delete(yomi: "え", word: Word("絵")), "削除済")
        XCTAssertEqual(dict.okuriNashiYomis, ["え"])
        XCTAssertTrue(dict.delete(yomi: "え", word: Word("柄")))
        XCTAssertEqual(dict.okuriNashiYomis, [])
        XCTAssertTrue(dict.entries.isEmpty)
    }

    @MainActor func testDeleteOkuriBlock() throws {
        var dict = MemoryDict(entries: ["あr": [Word("有", okuri: "る"), Word("有", okuri: "り"), Word("有")]])
        XCTAssertTrue(dict.delete(yomi: "あr", word: Word("有")))
        XCTAssertEqual(dict.refer("あr", option: nil), [Word("有", okuri: "る"), Word("有", okuri: "り")], "送り仮名なしの「有」だけ削除され、送り仮名ありのエントリは残る")
    }

    @MainActor func testDeleteExactCandidate() throws {
        var dict = MemoryDict(entries: ["あr": [Word("有", okuri: "る"), Word("有", okuri: "り"), Word("有")]])
        XCTAssertTrue(dict.delete(yomi: "あr", word: Word("有", okuri: "る")))
        XCTAssertEqual(dict.refer("あr", option: nil), [Word("有", okuri: "り"), Word("有")])
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])
        XCTAssertFalse(dict.delete(yomi: "あr", word: Word("有", okuri: "る")), "削除済")

        XCTAssertTrue(dict.delete(yomi: "あr", word: Word("有")))
        XCTAssertEqual(dict.refer("あr", option: nil), [Word("有", okuri: "り")])
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])

        XCTAssertTrue(dict.delete(yomi: "あr", word: Word("有", okuri: "り")))
        XCTAssertEqual(dict.refer("あr", option: nil), [])
        XCTAssertEqual(dict.okuriAriYomis, [])
    }

    @MainActor func testFindCompletions() {
        var dict = MemoryDict(entries: [:])
        XCTAssertEqual(dict.findCompletions(prefix: ""), [], "辞書が空だと空")
        dict.add(yomi: "あいうえおか", word: Word("アイウエオカ"))
        XCTAssertEqual(dict.findCompletions(prefix: ""), [], "prefixが空だと空")
        XCTAssertEqual(dict.findCompletions(prefix: "あいうえ"), ["あいうえおか"])
        XCTAssertEqual(dict.findCompletions(prefix: "あいうえおか"), [], "完全一致する読みは補完候補とはしない")
        dict.add(yomi: "あいうえお", word: Word("アイウエオ"))
        XCTAssertEqual(dict.findCompletions(prefix: "あいうえ"), ["あいうえお", "あいうえおか"], "あとで追加したエントリの読みを優先する")
        dict.add(yomi: "だい#", word: Word("第1"))
        XCTAssertEqual(dict.findCompletions(prefix: "だい"), [], "数値変換の読みは補完候補とはしない")
    }

    @MainActor func testReverseRefer() {
        let dict = MemoryDict(entries: ["あr": [Word("有"), Word("在")], "え": [Word("絵"), Word("柄")]])
        XCTAssertEqual(dict.reverseRefer("絵"), "え")
        XCTAssertEqual(dict.reverseRefer("柄"), "え")
        XCTAssertNil(dict.reverseRefer("江"))
        XCTAssertEqual(dict.reverseRefer("有"), "あr")
    }

    @MainActor func testSerialize() throws {
        var dict = MemoryDict(entries: [:])
        XCTAssertEqual(dict.serialize(),
                       [FileDict.headers[0], FileDict.okuriAriHeader, FileDict.okuriNashiHeader, ""].joined(separator: "\n"))
        dict.add(yomi: "あ", word: Word("亜", annotation: Annotation(dictId: "testDict", text: "亜の注釈")))
        dict.add(yomi: "あ", word: Word("阿", annotation: Annotation(dictId: "testDict", text: "阿の注釈")))
        dict.add(yomi: "あr", word: Word("有", annotation: Annotation(dictId: "testDict", text: "有の注釈")))
        dict.add(yomi: "あr", word: Word("在", annotation: Annotation(dictId: "testDict", text: "在の注釈")))
        var expected = [
            FileDict.headers[0],
            FileDict.okuriAriHeader,
            "あr /在;在の注釈/有;有の注釈/",
            FileDict.okuriNashiHeader,
            "あ /阿;阿の注釈/亜;亜の注釈/",
            "",
        ].joined(separator: "\n")
        XCTAssertEqual(dict.serialize(), expected)
        // 追加したエントリはシリアライズ時は先頭に付く
        dict.add(yomi: "い", word: Word("伊"))
        dict.add(yomi: "いr", word: Word("射"))
        expected = [
            FileDict.headers[0],
            FileDict.okuriAriHeader,
            "いr /射/",
            "あr /在;在の注釈/有;有の注釈/",
            FileDict.okuriNashiHeader,
            "い /伊/",
            "あ /阿;阿の注釈/亜;亜の注釈/",
            "",
        ].joined(separator: "\n")
        XCTAssertEqual(dict.serialize(), expected)
        // 追加更新した場合は順序を変更する。削除更新した場合は順序を変更しない
        XCTAssertTrue(dict.delete(yomi: "あ", word: Word("亜")))
        dict.add(yomi: "あr", word: Word("或"))
        expected = [
            FileDict.headers[0],
            FileDict.okuriAriHeader,
            "あr /或/在;在の注釈/有;有の注釈/",
            "いr /射/",
            FileDict.okuriNashiHeader,
            "い /伊/",
            "あ /阿;阿の注釈/",
            "",
        ].joined(separator: "\n")
        XCTAssertEqual(dict.serialize(), expected)
    }
}
