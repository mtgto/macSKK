// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UserDictTests: XCTestCase {
    func testSerialize() throws {
        var userDict = UserDict(dicts: [])
        XCTAssertEqual(userDict.serialize(), ";; okuri-ari entries.\n;; okuri-nasi entries.\n")
        userDict.okurinashi = ["あ": [Word(word: "亜", annotation: "亜の注釈")]]
        XCTAssertEqual(userDict.serialize(), ";; okuri-ari entries.\n;; okuri-nasi entries.\nあ /亜;亜の注釈/\n")
    }
}
