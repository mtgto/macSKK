// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum EucJis2004Error: Error {
    case unsupported
    case convert
}

extension URL {
    // EUC-JIS-2004でエンコードされているファイルからStringに読み込む
    func eucJis2004String() throws -> String {
        var data = try Data(contentsOf: self)
        if data.isEmpty {
            return ""
        }
        let cd = iconv_open("UTF-8".cString(using: .ascii), "EUC-JISX0213".cString(using: .ascii))
        if cd == iconv_t(bitPattern: -1) {
            throw EucJis2004Error.unsupported
        }
        defer {
            iconv_close(cd)
        }
        var inLeft = data.count
        // EUC-JIS-2004は1文字で1..2バイト (ASCIIは1バイト)、UTF-8は1..4バイト (ASCIIは1バイト) なのでバッファサイズは2倍用意する
        var outLeft = data.count * 2
        var buffer = Array<CChar>(repeating: 0, count: outLeft)
        return try data.withUnsafeMutableBytes {
            var inPtr = $0.baseAddress?.assumingMemoryBound(to: CChar.self)
            try buffer.withUnsafeMutableBufferPointer {
                var outPtr = $0.baseAddress
                let ret = iconv(cd, &inPtr, &inLeft, &outPtr, &outLeft)
                if ret == -1 {
                    if errno == EBADF {
                        logger.error("iconv変換デスクリプタの状態が異常です")
                    } else if errno == EILSEQ {
                        logger.error("入力に不正なバイト列が存在します")
                    } else if errno == E2BIG {
                        logger.error("EUC-JIS-2004からの変換先のバッファが足りません")
                    } else if errno == EINVAL {
                        logger.error("入力文字列が終端していません")
                    }
                    throw EucJis2004Error.convert
                } else if ret > 0 {
                    logger.warning("EUC-JIS-2004から処理できない文字が \(ret) 文字ありました")
                }
            }
            guard let str = String(validatingUTF8: buffer) else {
                throw EucJis2004Error.convert
            }
            return str
        }
    }
}