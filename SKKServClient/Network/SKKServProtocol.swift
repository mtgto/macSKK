// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

final class SKKServProtocol: NWProtocolFramerImplementation {
    static let label: String = "skkserv"
    static let definition = NWProtocolFramer.Definition(implementation: SKKServProtocol.self)
    var lastRequest: SKKServRequest?

    required init(framer: NWProtocolFramer.Instance) {}

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
        .ready
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var received: Data? = nil
            _ = framer.parseInput(minimumIncompleteLength: 1, maximumLength: 1024 * 1024) { buffer, isComplete -> Int in
                // 直前のリクエストがサーバーのバージョン要求、サーバーのホスト名とIPアドレスのリスト要求の場合はスペースが終端記号となりLFは送られない
                // NOTE: 2024-03-15現在、yaskkserv2はIPアドレスのリスト要求の場合、スペースが終端記号になっていない
                if let lastRequest, let buffer, let index = buffer.firstIndex(of: lastRequest.terminateCharacter) {
                    buffer[0..<index].withUnsafeBytes { pointer in
                        received = Data(pointer)
                    }
                }
                return 0
            }
            guard let received else {
                return 0
            }
            let message = NWProtocolFramer.Message(response: received)
            _ = framer.deliverInputNoCopy(length: received.count + 1, message: message, isComplete: true)
            // 次のメッセージを待つ
            return 0
        }
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        guard let request = message.request else {
            fatalError("request is not set")
        }
        // 受信時に終端記号を決めるために直前のリクエストだけ保持しておく
        lastRequest = request
        framer.writeOutput(data: request.data)
    }

    func wakeup(framer: NWProtocolFramer.Instance) {}

    func stop(framer: NWProtocolFramer.Instance) -> Bool {
        // FIXME: 終端信号を送信してもよさそう?
        return true
    }

    func cleanup(framer: NWProtocolFramer.Instance) {}
}
