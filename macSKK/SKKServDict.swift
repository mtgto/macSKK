// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

protocol SKKServDictProtocol {
    var saveToUserDict: Bool { get }
    func refer(_ yomi: String, option: DictReferringOption?) -> Result<[Word], any Error>
    func findCompletions(prefix: String) -> Result<[String], any Error>
}

/// 補完候補検索でのskkserv検索オプション
struct CompletionSKKServOption {
    let dict: any SKKServDictProtocol
    /// skkservへのreferの問い合わせの上限回数
    let referLimit: Int
}

/**
 * skkservを辞書として使う辞書定義
 *
 * 複数のskkservを想定してSKKServDict(サーバー数)とSKKServService(1つ)と分けているけど、
 * 当面はサーバー数を1に固定してSKKServDictにXPCとの通信処理をもってきたほうがシンプルかも?
 */
final class SKKServDict: SKKServDictProtocol, Sendable {
    private let destination: SKKServDestination
    private let service: any SKKServServiceProtocol
    /// 変換履歴をユーザー辞書に保存するかどうか
    let saveToUserDict: Bool

    init(destination: SKKServDestination, service: any SKKServServiceProtocol = SKKServService(), saveToUserDict: Bool) {
        self.destination = destination
        self.service = service
        self.saveToUserDict = saveToUserDict
    }

    /**
     * skkservに変換候補の問い合わせを行い変換候補を返す。
     *
     * TCP接続が切れたり接続タイムアウトや応答のタイムアウトした場合はログだけ出力して .failure を返す。
     */
    func refer(_ yomi: String, option: DictReferringOption?) -> Result<[Word], any Error> {
        do {
            let result = try service.refer(yomi: yomi, destination: destination, timeout: 1.0)
            // 変換候補が見つかった場合は "1/変換/返還/" のように 1が先頭でスラッシュで区切られた文字列
            // 見つからなかった場合は "4へんかん" のように4が先頭の文字列
            guard result.hasPrefix("1/") else {
                logger.debug("skkservから変換候補が見つからなかったレスポンスが返りました")
                return .success([])
            }
            // Entry.parseWordsは先頭のスラッシュがない形を受け取る
            guard let candidates = Entry.parseWords(result.dropFirst(2), dictId: "skkserv") else {
                logger.error("skkservの返した変換候補を正常にパースできませんでした")
                return .success([])
            }
            return .success(candidates)
        } catch {
            logSKKServError(error)
            return .failure(error)
        }
    }

    func findCompletions(prefix: String) -> Result<[String], any Error> {
        do {
            let result = try service.completion(yomi: prefix, destination: destination, timeout: 1.0)
            // 補完結果が見つかった場合は "1/ほかん/ほかんこうほ/" のように 1が先頭でスラッシュで区切られた文字列
            // 見つからなかた場合は "4ほかん" のように4が先頭の文字列
            guard result.hasPrefix("1/") else {
                logger.debug("skkservから補完候補が見つからなかったレスポンスが返りました")
                return .success([])
            }
            let completions = result.dropFirst(2).split(separator: "/").map { String($0) }
            // 重複した候補、読みと同じ候補、読みを接頭辞としてもたない候補は除去
            return .success(completions.reduce(into: []) { acc, item in
                if !acc.contains(item) && item.hasPrefix(prefix) && item != prefix {
                    acc.append(item)
                }
            })
        } catch {
            logSKKServError(error)
            return .failure(error)
        }
    }

    private func logSKKServError(_ error: any Error) {
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
    }

    func disconnect() {
        do {
            try service.disconnect()
        } catch {
            logger.error("skkservとの通信切断でエラーが発生しました: \(error, privacy: .public)")
        }
    }
}
