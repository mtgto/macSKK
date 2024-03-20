// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// skkservを辞書として使う辞書定義
struct SKKServDict {
    let destination: SKKServDestination
    let service: SKKServService

    init(destination: SKKServDestination) {
        self.destination = destination
        service = SKKServService()
    }

    func refer(_ yomi: String, option: DictReferringOption?) async throws -> [Word] {
        let result = try await service.refer(yomi: yomi, destination: destination)
        // 変換候補が見つかった場合は "1/変換/返還/" のように 1が先頭でスラッシュで区切られた文字列
        // 見つからなかった場合は "4へんかん" のように4が先頭の文字列
        print("result = \(result)")
        guard result.hasPrefix("1") else {
            return []
        }
        let line = yomi + " " + result.dropFirst()
        guard let candidates = Entry.parseWords(result.dropFirst(), dictId: "skkserv") else {
            logger.error("skkservの返した変換候補を正常にパースできませんでした")
            return []
        }
        return candidates
    }
}
