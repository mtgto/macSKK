// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class ReadonlyMemoryDictTests: XCTestCase {
    func testParseSource() {
        let source = """
            ;; この行はコメント扱い
            ;; okuri-ari entries.
            おおk /大/多/[く/多/]/[き/大/]/
            いt /[った/行/言/]/
            あg /挙/揚/上/
            あb /浴/
            ;; okuri-nasi entries.
            あ /阿/唖/亜/娃/
            けい /京;10^16/
            から //
            いぬ /犬;*かわいい/

            """
        let dict = ReadonlyMemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.refer("あg", option: nil).map { $0.word }, ["挙", "揚", "上"])
        XCTAssertEqual(dict.refer("あ", option: nil).map { $0.word }, ["阿", "唖", "亜", "娃"])
        XCTAssertEqual(dict.refer("けい", option: nil).map { $0.word }, ["京"])
        XCTAssertEqual(dict.refer("おおk", option: nil).map { $0.word }, ["大", "多", "多", "大"])
        XCTAssertEqual(dict.refer("いぬ", option: nil).first?.annotation, Annotation(dictId: "testDict", text: "かわいい"))
        XCTAssertEqual(dict.refer("から", option: nil), [], "空の変換候補しかもたない読みはスキップする")
        XCTAssertEqual(dict.entryCount, 7)
        XCTAssertEqual(dict.failedEntryCount, 0)
        XCTAssertTrue(dict.saveToUserDict)
    }

    func testParseFailedLines() {
        let source = """
            あ /阿/
            不正な行
            い い /胃/
            う /宇/

            """
        let dict = ReadonlyMemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.failedEntryCount, 2)
        XCTAssertEqual(dict.entryCount, 2)
        XCTAssertEqual(dict.okuriNashiYomis, ["あ", "う"])
    }

    func testParseSplitsOkuriAriNashiYomis() {
        // SKK-JISYOは送りありエントリは辞書の逆順、送りなしエントリは辞書順に並ぶ
        let source = """
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
        let dict = ReadonlyMemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.okuriNashiYomis, ["Cyrillic", "Greek", "cyrillic", "greek", "あ", "けい"])
        XCTAssertEqual(dict.okuriAriYomis, ["あb", "あg", "いt", "おおk"])
    }

    func testParseDuplicatedYomiInUnsortedInput() {
        let source = """
            あお /青/
            あか /赤/
            あお /蒼/
            あお /碧/

            """
        let dict = ReadonlyMemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.refer("あお", option: nil).map { $0.word }, ["青", "蒼", "碧"], "同じ読みは登場順に連結する")
        XCTAssertEqual(dict.okuriNashiYomis, ["あお", "あか"])
        XCTAssertEqual(dict.entryCount, 2)
    }

    func testEntries() {
        let source = """
            あb /浴/
            あお /青/
            あお /蒼/

            """
        let dict = ReadonlyMemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.entries, ["あb": [Word("浴")], "あお": [Word("青"), Word("蒼")]])
    }

    func testInitWithEntries() {
        let entries: [String: [Word]] = ["え": [Word("絵")], "あr": [Word("有")], "あ": [Word("亜")]]
        let dict = ReadonlyMemoryDict(entries: entries, saveToUserDict: false)
        XCTAssertEqual(dict.entries, entries)
        XCTAssertEqual(dict.okuriNashiYomis, ["あ", "え"])
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])
        XCTAssertEqual(dict.entryCount, 3)
        XCTAssertEqual(dict.failedEntryCount, 0)
        XCTAssertFalse(dict.saveToUserDict)
    }

    func testInitWithOkuriAriNashiEntries() {
        let dict = ReadonlyMemoryDict(okuriAriEntries: ["あr": [Word("有")]],
                                      okuriNashiEntries: ["え": [Word("絵")], "あ": [Word("亜")]])
        XCTAssertEqual(dict.okuriNashiYomis, ["あ", "え"])
        XCTAssertEqual(dict.okuriAriYomis, ["あr"])
        XCTAssertEqual(dict.refer("あr", option: nil), [Word("有")])
        XCTAssertEqual(dict.refer("え", option: nil), [Word("絵")])
        XCTAssertEqual(dict.findCompletions(prefix: "あ"), [], "送りありの読みは補完しない")
        XCTAssertTrue(dict.saveToUserDict)
    }

    func testWithSaveToUserDict() {
        let dict = ReadonlyMemoryDict(entries: ["あ": [Word("亜")]])
        XCTAssertTrue(dict.saveToUserDict)
        let changed = dict.with(saveToUserDict: false)
        XCTAssertFalse(changed.saveToUserDict)
        XCTAssertEqual(changed.entries, dict.entries)
        XCTAssertEqual(changed.with(saveToUserDict: true).saveToUserDict, true)
    }

    func testReferWithOption() {
        let dict = ReadonlyMemoryDict(entries: ["あき>": [Word("空き")],
                                                "あき": [Word("秋")],
                                                ">し": [Word("氏")],
                                                "し": [Word("詩")],
                                                "いt": [Word("言"), Word("行", okuri: "った")]])
        XCTAssertEqual(dict.refer("あき", option: nil), [Word("秋")])
        XCTAssertEqual(dict.refer("あき", option: .prefix), [Word("空き")])
        XCTAssertEqual(dict.refer("あき", option: .suffix), [])
        XCTAssertEqual(dict.refer("し", option: nil), [Word("詩")])
        XCTAssertEqual(dict.refer("し", option: .suffix), [Word("氏")])
        XCTAssertEqual(dict.refer("し", option: .prefix), [])
        XCTAssertEqual(dict.refer("いt", option: nil), [Word("言"), Word("行", okuri: "った")])
        XCTAssertEqual(dict.refer("いt", option: .okuri("った")), [Word("行", okuri: "った"), Word("言")])
        XCTAssertEqual(dict.refer("いk", option: .okuri("った")), [])
        XCTAssertEqual(dict.refer("なし", option: nil), [])
    }

    func testReverseRefer() {
        let dict = ReadonlyMemoryDict(entries: ["あr": [Word("有"), Word("在")], "え": [Word("絵"), Word("柄")]])
        XCTAssertEqual(dict.reverseRefer("絵"), "え")
        XCTAssertEqual(dict.reverseRefer("柄"), "え")
        XCTAssertNil(dict.reverseRefer("江"))
        XCTAssertEqual(dict.reverseRefer("有"), "あr")
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
        let dict = ReadonlyMemoryDict(dictId: "testDict", source: source)
        XCTAssertEqual(dict.findCompletions(prefix: "い"), ["いか", "いかめし", "いかめら", "いがい", "いきおい", "いきなり", "いきば", "いく", "いこい"])
        XCTAssertEqual(dict.findCompletions(prefix: "いか"), ["いかめし", "いかめら"])
        XCTAssertEqual(dict.findCompletions(prefix: "いき"), ["いきおい", "いきなり", "いきば"])
        XCTAssertEqual(dict.findCompletions(prefix: "う"), ["うえ"])
        XCTAssertEqual(dict.findCompletions(prefix: "あ"), [])
        XCTAssertEqual(dict.findCompletions(prefix: "え"), [])
    }

    func testFindCompletions() {
        let dict = ReadonlyMemoryDict(entries: ["あいうえお": [Word("アイウエオ")],
                                                "あいうえおか": [Word("アイウエオカ")],
                                                "あいうk": [Word("合う", okuri: "く")],
                                                "だい#": [Word("第1")],
                                                "だいがく": [Word("大学")]])
        XCTAssertEqual(dict.findCompletions(prefix: ""), [], "prefixが空だと空")
        XCTAssertEqual(dict.findCompletions(prefix: "あいう"), ["あいうえお", "あいうえおか"], "送りありの読みは補完候補としない")
        XCTAssertEqual(dict.findCompletions(prefix: "あいうえお"), ["あいうえおか"], "完全一致する読みは補完候補とはしない")
        XCTAssertEqual(dict.findCompletions(prefix: "あいうえおか"), [])
        XCTAssertEqual(dict.findCompletions(prefix: "だい"), ["だいがく"], "数値変換の読みは補完候補とはしない")
        XCTAssertEqual(ReadonlyMemoryDict(entries: [:]).findCompletions(prefix: "あ"), [], "辞書が空だと空")
    }
}
