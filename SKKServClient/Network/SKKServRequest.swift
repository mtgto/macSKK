// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// end, request, version, hostは以下の資料を参考にしています
// https://github.com/jj1bdx/dbskkd-cdb/blob/master/skk-server-protocol.md
// midashiは以下の資料を参考にしています
// https://ja.osdn.net/projects/pysocialskkserv/wiki/SKKServ
enum SKKServRequest {
    case end
    case request(Data) // 見出し語をエンコードしたもの
    case version
    case host
    case completion(Data) // 読みをエンコードしたもの

    var data: Data {
        let lf: UInt8 = 0x0a
        let space: UInt8 = 0x20

        switch self {
        case .end:
            return Data([0x30, space, lf]) // '0' + space + LF
        case .request(let key):
            var data = Data([0x31]) // '1' + key + space + LF
            data.append(key)
            data.append(contentsOf: [space, lf])
            return data
        case .version:
            return Data([0x32, space, lf]) // '2' + space + LF
        case .host:
            return Data([0x33, space, lf]) // '3' + space + LF
        case .completion(let key):
            var data = Data([0x34]) // '4' + key + space + LF
            data.append(key)
            data.append(contentsOf: [space, lf])
            return data
        }
    }

    var terminateCharacter: UInt8 {
        switch self {
        case .request, .completion:
            return 0x0a
        case .version, .host:
            return 0x20
        default: // .end のときは応答がない
            return 0
        }
    }
}
