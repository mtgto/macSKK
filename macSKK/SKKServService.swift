// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct SKKServService {
    let service: NSXPCConnection

    init() {
        service = NSXPCConnection(serviceName: "net.mtgto.inputmethod.macSKK.SKKServClient")
        service.remoteObjectInterface = NSXPCInterface(with: (any SKKServClientProtocol).self)
    }

    func serverVersion(destination: SKKServDestination) async throws -> String {
        service.activate()
        defer {
            service.invalidate()
        }
        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.unexpected
        }
        /**
         * XPCコールでエラーが発生した場合、SKKServClientErrorを投げていても正しくデコードされない。
         * (domain="SKKServClient.SKKServClientError", code=XX をもつNSErrorとなる)
         * しかたないのでNSError#domainとNSError#codeからSKKServClientErrorに変換する
         */
        do {
            return try await proxy.serverVersion(destination: destination)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "SKKServClient.SKKServClientError" {
                try SKKServClientError.allCases.forEach { skkservClientError in
                    if (skkservClientError as NSError).code == nsError.code {
                        throw skkservClientError
                    }
                }
            }
            throw error
         }
    }

    /**
     * SKK辞書の読みを受け取り、skkservの応答を返します。
     * TODO: [Word]を返すようにする?
     *
     * @param yomi 送り仮名なしなら "へんかん" のような文字列、送り仮名ありなら "おくr" のような文字列
     * @return 変換結果が見つかった場合は "1/変換/返還/" のような先頭に1がつく形式 (1はXPC側で消すかも)
     */
    func refer(yomi: String, destination: SKKServDestination) async throws -> String {
        service.activate()
        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.unexpected
        }
        return try await proxy.refer(destination: destination, yomi: yomi)
    }
}
