// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import zlib

@testable import macSKK

final class DataGzipTests: XCTestCase {
    func testGunzippedWithoutMagicBytes() {
        let data = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertThrowsError(try data.gunzipped()) { error in
            XCTAssertEqual(error as? GzipError, .invalidData)
        }
    }

    func testGunzippedWithMagicBytesButInvalidData() {
        // 正当なgzipヘッダー (CM=0x08) + 不正なdeflateデータ (0xff) + フッター (ISIZE=4)
        // inflate が deflateストリームを解析するとZ_DATA_ERRORを返す
        let data = Data([
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,  // gzipヘッダー
            0xff, 0xff,                                                  // 不正なdeflateデータ
            0x00, 0x00, 0x00, 0x00,                                      // CRC32
            0x04, 0x00, 0x00, 0x00,                                      // ISIZE = 4
        ])

        XCTAssertThrowsError(try data.gunzipped()) { error in
            XCTAssertEqual(error as? GzipError, .decompressFailed(Z_DATA_ERROR))
        }
    }
}
