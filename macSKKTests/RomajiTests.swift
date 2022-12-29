// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

class RomajiTests: XCTestCase {
    func testConvert() throws {
        XCTAssertEqual(Romaji.convert("o"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.table["o"]))
        XCTAssertEqual(Romaji.convert("ta"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.table["ta"]))
        XCTAssertEqual(Romaji.convert("n"), Romaji.ConvertedMoji(input: "n", kakutei: nil))
        XCTAssertEqual(Romaji.convert("-"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.symbolTable["-"]))
        XCTAssertEqual(Romaji.convert(","), Romaji.ConvertedMoji(input: "", kakutei: Romaji.symbolTable[","]))
        XCTAssertEqual(Romaji.convert("."), Romaji.ConvertedMoji(input: "", kakutei: Romaji.symbolTable["."]))
        XCTAssertEqual(Romaji.convert("zh"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.specialSymbolTable["zh"]))
        XCTAssertEqual(Romaji.convert("sy"), Romaji.ConvertedMoji(input: "sy", kakutei: nil))
        XCTAssertEqual(
            Romaji.convert("kk"), Romaji.ConvertedMoji(input: "k", kakutei: Romaji.sokuon("k")),
            "同じ子音が連続した場合は促音が確定して子音ひとつが残る")
        XCTAssertEqual(Romaji.convert("tr"), Romaji.ConvertedMoji(input: "r", kakutei: nil), "異なる子音が連続した場合は最後の子音ひとつが残る")
        XCTAssertEqual(
            Romaji.convert("tsh"), Romaji.ConvertedMoji(input: "h", kakutei: nil),
            "続けられない子音が連続した場合は最後の子音だけ残る (shじゃなくてhだけ残す)")
    }
}
