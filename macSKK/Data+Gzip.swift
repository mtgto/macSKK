// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import zlib

enum GzipError: Error, Equatable {
    case invalidData
    case decompressFailed(Int32)
}

extension Data {
    /// gzip圧縮されているかどうかを簡易的に検査する
    /// gzipマジックバイト (0x1f 0x8b) で始まるかどうか + 末尾の展開後のサイズ (4バイト)
    var isGzipped: Bool {
        count >= 6 && self[0] == 0x1f && self[1] == 0x8b
    }

    /// gzip形式のデータを展開して返す
    func gunzipped() throws -> Data {
        guard isGzipped else { throw GzipError.invalidData }

        // gzipフッター末尾4バイトから展開後サイズを取得 (little-endian uint32, mod 2^32)
        let expectedSize = Int(
            UInt32(self[count - 4]) |
            UInt32(self[count - 3]) << 8 |
            UInt32(self[count - 2]) << 16 |
            UInt32(self[count - 1]) << 24
        )

        var stream = z_stream()
        // MAX_WBITS + 16 = 31: gzipフォーマットを強制
        let initStatus = inflateInit2_(&stream, MAX_WBITS + 16, ZLIB_VERSION,
                                       Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else { throw GzipError.decompressFailed(initStatus) }
        defer { inflateEnd(&stream) }

        return try withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) throws -> Data in
            guard let baseAddress = srcPtr.baseAddress else { throw GzipError.invalidData }
            stream.next_in = UnsafeMutablePointer(mutating:
                baseAddress.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(count)

            var result = Data(count: expectedSize)
            let status: Int32 = result.withUnsafeMutableBytes { bufPtr in
                stream.next_out = bufPtr.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(expectedSize)
                return inflate(&stream, Z_FINISH)
            }
            guard status == Z_STREAM_END else { throw GzipError.decompressFailed(status) }
            result.count = Int(stream.total_out)
            return result
        }
    }
}
