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
        let cd = iconv_open("UTF-8".cString(using: .ascii), "EUC-JISX0213".cString(using: .ascii))
        if cd == iconv_t(bitPattern: -1) {
            throw EucJis2004Error.unsupported
        }
        var inLeft = data.count
        var buffer = Array<CChar>(repeating: 0, count: 4096)
        var outLeft = 4096
        var result = ""
        try data.withUnsafeMutableBytes {
            var inPtr = $0.baseAddress?.assumingMemoryBound(to: CChar.self)
            try buffer.withUnsafeMutableBufferPointer {
                var outPtr = $0.baseAddress
                let ret = iconv(cd, &inPtr, &inLeft, &outPtr, &outLeft)
                if ret == -1 {
                    throw EucJis2004Error.convert
                }
            }
            if let str = String(validatingUTF8: buffer) {
                result.append(str)
            }
            //let result = iconv(cd, &inPtr, &inLeft, &outPtr, &outLeft)
        }
        iconv(cd, nil, nil, nil, nil)
        iconv_close(cd)
        return result
    }
}
