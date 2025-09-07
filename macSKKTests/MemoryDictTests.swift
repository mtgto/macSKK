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
        let dict = MemoryDict(dictId: "testDict", source: source, readonly: false)
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
        let dict = MemoryDict(dictId: "testDict", source: source, readonly: false)
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
        let dict = MemoryDict(dictId: "testDict", source: source, readonly: false)
        XCTAssertEqual(dict.entries["あれきさんどろす"]?.map { $0.word }, ["[Alexandros]"])
    }

    func testParseDuplicatedYomi() throws {
        let source = """
            あお /青/
            あお /蒼/
            あお /碧/

            """
        let dict = MemoryDict(dictId: "testDict", source: source, readonly: false)
        XCTAssertEqual(dict.entries["あお"]?.map { $0.word }, ["青", "蒼", "碧"])
    }

    func testParseIncludingUserAnnotation() throws {
        // 注釈の先頭のアスタリスクはユーザー自身の注釈を表す
        let source = """
            いぬ /犬;*かわいい/

            """
        let dict = MemoryDict(dictId: "testDict", source: source, readonly: false)
        XCTAssertEqual(dict.entries["いぬ"]?.first?.annotation, Annotation(dictId: "testDict", text: "かわいい"))
    }

    func testParseEmptyCandidate() throws {
        // TODO: いまは空の変換候補をスキップしているが扱えるようにしたい
        let source = """
            から //

            """
        let dict = MemoryDict(dictId: "testDict", source: source, readonly: false)
        XCTAssertNil(dict.entries["から"])
    }

    func testParseReadonly() {
        // SKK-JISYOは送りありエントリは辞書の逆順、送りなしエントリは辞書順に並ぶ
        var source = """
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
        var dict = MemoryDict(dictId: "testDict", source: source, readonly: true)
        XCTAssertEqual(dict.okuriNashiYomis, ["Cyrillic", "Greek", "cyrillic", "greek", "あ", "けい"])
        XCTAssertEqual(dict.okuriAriYomis, ["あb", "あg", "いt", "おおk"])
        // okuri-nashi entriesが辞書順になってなければソートされる
        source = """
            Greek /Α/Β/Γ/Δ/Ε/Ζ/Η/Θ/Ι/Κ/Λ/Μ/Ν/Ξ/Ο/Π/Ρ/Σ/Τ/Υ/Φ/Χ/Ψ/Ω/
            おおk /大/多/[く/多/]/[き/大/]/
            greek /α/β/γ/δ/ε/ζ/η/θ/ι/κ/λ/μ/ν/ξ/ο/π/ρ/σ/τ/υ/φ/χ/ψ/ω/
            いt /[った/行/言/]/
            けい /京;10^16/
            あg /挙/揚/上/
            あ /阿/唖/亜/娃/
            あb /浴/
            cyrillic /а/б/в/г/д/е/ё/ж/з/и/й/к/л/м/н/о/п/р/с/т/у/ф/х/ц/ч/ш/щ/ъ/ы/ь/э/ю/я/
            Cyrillic /А/Б/В/Г/Д/Е/Ё/Ж/З/И/Й/К/Л/М/Н/О/П/Р/С/Т/У/Ф/Х/Ц/Ч/Ш/Щ/Ъ/Ы/Ь/Э/Ю/Я/
            """
        dict = MemoryDict(dictId: "testDict", source: source, readonly: true)
        XCTAssertEqual(dict.okuriNashiYomis, ["Cyrillic", "Greek", "cyrillic", "greek", "あ", "けい"])
        // okuriAriYomisはソートしてない。そのうちするかも
    }

    func testAdd() throws {
        var dict = MemoryDict(entries: [:], readonly: false)
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

    func testDelete() throws {
        var dict = MemoryDict(entries: ["あr": [Word("有"), Word("在")], "え": [Word("絵"), Word("柄")]], readonly: false)
        XCTAssertFalse(dict.entries.isEmpty)
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])
        XCTAssertEqual(dict.okuriNashiYomis, ["え"])
        XCTAssertFalse(dict.delete(yomi: "あr", word: "或"))
        XCTAssertFalse(dict.delete(yomi: "いr", word: "居"), "存在しないエントリを削除しようとする")
        XCTAssertFalse(dict.delete(yomi: "お", word: "尾"), "存在しないエントリを削除しようとする")
        XCTAssertTrue(dict.delete(yomi: "あr", word: "在"))
        XCTAssertTrue(dict.delete(yomi: "え", word: "絵"))
        XCTAssertEqual(dict.okuriAriYomis, ["あr"], "「有」がまだ残っている")
        XCTAssertEqual(dict.okuriNashiYomis, ["え"], "「柄」がまだ残っている")
        XCTAssertEqual(dict.refer("あr", option: nil), [Word("有")])
        XCTAssertFalse(dict.delete(yomi: "いいい", word: "いいい"))
        XCTAssertFalse(dict.delete(yomi: "あr", word: "在"), "削除済")
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])
        XCTAssertTrue(dict.delete(yomi: "あr", word: "有"))
        XCTAssertEqual(dict.okuriAriYomis, [])
        XCTAssertFalse(dict.delete(yomi: "え", word: "絵"), "削除済")
        XCTAssertEqual(dict.okuriNashiYomis, ["え"])
        XCTAssertTrue(dict.delete(yomi: "え", word: "柄"))
        XCTAssertEqual(dict.okuriNashiYomis, [])
        XCTAssertTrue(dict.entries.isEmpty)
    }

    func testDeleteOkuriBlock() throws {
        var dict = MemoryDict(entries: ["あr": [Word("有", okuri: "る"), Word("有", okuri: "り"), Word("有")]], readonly: false)
        XCTAssertTrue(dict.delete(yomi: "あr", word: "有"))
        XCTAssertEqual(dict.refer("あr", option: nil), [], "あr を読みとして持つ変換候補が全て削除された")
        XCTAssertEqual(dict.okuriAriYomis, [])
    }

    func testFindCompletions() {
        var dict = MemoryDict(entries: [:], readonly: false)
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

    func testFindCompletionsBinarySearch() {
        let source = """
            ;; okuri-ari entries.
            ;; okuri-nasi entries.
            あ /亜/
            いか /以下/
            いかめし /イカめし/
            いかめら /胃カメラ/
            いがい /以外/
            いきおい /勢い/
            いきなり /行き成り/
            いきば /行き場/
            いく /育/
            いこい /憩い/
            うえ /上/

            """
        let dict = MemoryDict(dictId: "testDict", source: source, readonly: true)
        XCTAssertEqual(dict.findCompletions(prefix: "い"), ["いか", "いかめし", "いかめら", "いがい", "いきおい", "いきなり", "いきば", "いく", "いこい"])
        XCTAssertEqual(dict.findCompletions(prefix: "いか"), ["いか", "いかめし", "いかめら"])
        XCTAssertEqual(dict.findCompletions(prefix: "いき"), ["いきおい", "いきなり", "いきば"])
        XCTAssertEqual(dict.findCompletions(prefix: "うえ"), ["うえ"])
        XCTAssertEqual(dict.findCompletions(prefix: "あ"), ["あ"])
        XCTAssertEqual(dict.findCompletions(prefix: "え"), [])
    }

    func testReferWithOption() {
        let dict = MemoryDict(entries: ["あき>": [Word("空き")],
                                        "あき": [Word("秋")],
                                        ">し": [Word("氏")],
                                        "し": [Word("詩")],
                                        "いt": [Word("言"), Word("行", okuri: "った")]],
                              readonly: true)
        XCTAssertEqual(dict.refer("あき", option: nil), [Word("秋")])
        XCTAssertEqual(dict.refer("あき", option: .prefix), [Word("空き")])
        XCTAssertEqual(dict.refer("あき", option: .suffix), [])
        XCTAssertEqual(dict.refer("し", option: nil), [Word("詩")])
        XCTAssertEqual(dict.refer("し", option: .suffix), [Word("氏")])
        XCTAssertEqual(dict.refer("し", option: .prefix), [])
        XCTAssertEqual(dict.refer("いt", option: nil), [Word("言"), Word("行", okuri: "った")])
        XCTAssertEqual(dict.refer("いt", option: .okuri("った")), [Word("行", okuri: "った"), Word("言")])
    }

    func testReverseRefer() {
        let dict = MemoryDict(entries: ["あr": [Word("有"), Word("在")], "え": [Word("絵"), Word("柄")]], readonly: false)
        XCTAssertEqual(dict.reverseRefer("絵"), "え")
        XCTAssertEqual(dict.reverseRefer("柄"), "え")
        XCTAssertNil(dict.reverseRefer("江"))
        XCTAssertEqual(dict.reverseRefer("有"), "あr")
    }
}
