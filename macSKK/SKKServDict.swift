// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// skkservを辞書として使う辞書定義
// 複数のskkservを想定してSKKServDict(サーバー数)とSKKServService(1つ)と分けているけど、
// 当面はサーバー数を1に固定してSKKServDictにXPCとの通信処理をもってきたほうがシンプルかも?
// actorとして定義できそう?
struct SKKServDict {
    let destination: SKKServDestination
    let service: SKKServService

    init(destination: SKKServDestination) {
        self.destination = destination
        service = SKKServService()
    }

    func refer(_ yomi: String, option: DictReferringOption?) async -> [Word] {
        logger.log("skkservに変換候補の検索を行います")
        do {
            let result = try await service.refer(yomi: yomi, destination: destination)
            // 変換候補が見つかった場合は "1/変換/返還/" のように 1が先頭でスラッシュで区切られた文字列
            // 見つからなかった場合は "4へんかん" のように4が先頭の文字列
            guard result.hasPrefix("1/") else {
                logger.error("skkservから変換候補が見つからなかったレスポンスが返りました")
                return []
            }
            // Entry.parseWordsは先頭のスラッシュがない形を受け取る
            guard let candidates = Entry.parseWords(result.dropFirst(2), dictId: "skkserv") else {
                logger.error("skkservの返した変換候補を正常にパースできませんでした")
                return []
            }
            logger.log("skkservから変換候補が返りました")
            return candidates
        } catch {
            if let error = error as? SKKServClientError {
                switch error {
                case .connectionRefused:
                    logger.log("skkservが応答しません")
                case .connectionTimeout:
                    logger.log("skkservとの接続がタイムアウトしました")
                case .invalidResponse:
                    logger.warning("skkservから想定しない応答が返りました")
                case .timeout:
                    logger.log("skkservから応答が一定時間返りませんでした")
                default:
                    logger.error("skkservから不明なエラーが返りました")
                }
            } else {
                logger.error("skkserv辞書の検索でエラーが発生しました: \(error, privacy: .public)")
            }
            return []
        }
    }
}
