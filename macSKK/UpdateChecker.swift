// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum XPCError: Error {
    case invalidProxy // remoteObjectProxyが想定したプロトコルを満たしていない
}

struct UpdateChecker {
    func callSampleXPC() async throws -> String {
        let service = NSXPCConnection(serviceName: "net.mtgto.inputmethod.macSKK.FetchUpdateService")
        service.remoteObjectInterface = NSXPCInterface(with: FetchUpdateServiceProtocol.self)
        service.resume()
        
        defer {
            service.invalidate()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let proxy = service.remoteObjectProxy as? FetchUpdateServiceProtocol else {
                continuation.resume(throwing: XPCError.invalidProxy)
                return
            }
            proxy.uppercase(string: "hello") { aString in
                continuation.resume(returning: aString)
            }
        }
    }
}
