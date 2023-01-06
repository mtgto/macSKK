// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

class DictTests: XCTestCase {
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

            """
        let dict = try Dict(source: source)
        XCTAssertEqual(dict.entries["あg"]?.map { $0.word }, ["挙", "揚", "上"])
        XCTAssertEqual(dict.entries["あb"]?.map { $0.word }, ["浴"])
        XCTAssertEqual(dict.entries["あ"]?.map { $0.word }, ["阿", "唖", "亜", "娃"])
    }

    func testParseSpecialSource() throws {
        // Sampling from SKK-JISYO.L
        let source = """
            わi /湧;(spring) 泉が湧く/沸;(boil) お湯が沸く/涌;≒湧く/
            ao /(concat "and\\057or")/
            GPL /GNU General Public License;(concat "http:\\057\\057www.gnu.org\\057licenses\\057gpl.ja.html")/

            """
        let dict = try Dict(source: source)
        XCTAssertEqual(dict.entries["わi"]?.map { $0.word }, ["湧", "沸", "涌"])
        XCTAssertEqual(dict.entries["ao"]?.map { $0.word }, ["and/or"])
        XCTAssertEqual(dict.entries["GPL"]?.map { $0.annotation }, ["http://www.gnu.org/licenses/gpl.ja.html"])
    }
}
