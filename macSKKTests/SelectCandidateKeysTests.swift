// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class SelectCandidateKeysTests: XCTestCase {
    func testValidatePresets() throws {
        for preset in SelectCandidateKeys.presets {
            XCTAssertEqual(try SelectCandidateKeys.validate(preset), preset)
        }
    }

    func testValidateNormalizesToUppercase() throws {
        XCTAssertEqual(try SelectCandidateKeys.validate("qwertyuio"), "QWERTYUIO")
        XCTAssertEqual(try SelectCandidateKeys.validate(";,.pyfgcr"), ";,.PYFGCR")
    }

    func testValidateInvalidLength() {
        XCTAssertThrowsError(try SelectCandidateKeys.validate("")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .invalidLength(0))
        }
        XCTAssertThrowsError(try SelectCandidateKeys.validate("12345678")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .invalidLength(8))
        }
        XCTAssertThrowsError(try SelectCandidateKeys.validate("1234567890")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .invalidLength(10))
        }
    }

    func testValidateDuplicated() {
        XCTAssertThrowsError(try SelectCandidateKeys.validate("112345678")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .duplicated(["1"]))
        }
        // 大文字小文字は区別しない
        XCTAssertThrowsError(try SelectCandidateKeys.validate("aAbBcdefg")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .duplicated(["A", "B"]))
        }
        // 文字数が足りなくても重複を優先して報告する
        XCTAssertThrowsError(try SelectCandidateKeys.validate("11")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .duplicated(["1"]))
        }
    }

    func testValidateInvalidCharacters() {
        XCTAssertThrowsError(try SelectCandidateKeys.validate("1234 5678")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .invalidCharacters([" "]))
        }
        XCTAssertThrowsError(try SelectCandidateKeys.validate("あいうえおかきくけ")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .invalidCharacters(["あ", "い", "う", "え", "お", "か", "き", "く", "け"]))
        }
        XCTAssertThrowsError(try SelectCandidateKeys.validate("１23456789")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .invalidCharacters(["１"]))
        }
        XCTAssertThrowsError(try SelectCandidateKeys.validate("1234\t5678")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .invalidCharacters(["\t"]))
        }
        // 使えない文字は重複していても1回だけ報告する
        XCTAssertThrowsError(try SelectCandidateKeys.validate("12  ")) { error in
            XCTAssertEqual(error as? SelectCandidateKeys.ValidationError, .invalidCharacters([" "]))
        }
    }

    func testSanitize() {
        XCTAssertEqual(SelectCandidateKeys.sanitize("asdfghjkl"), "ASDFGHJKL")
        XCTAssertEqual(SelectCandidateKeys.sanitize("1234"), SelectCandidateKeys.default)
        XCTAssertEqual(SelectCandidateKeys.sanitize(nil), SelectCandidateKeys.default)
    }
}
