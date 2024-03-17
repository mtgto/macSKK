// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct SKKServService {
    let service: NSXPCConnection
    //static let shared = SKKServService()

    init() {
        service = NSXPCConnection(serviceName: "net.mtgto.inputmethod.macSKK.SKKServClient")
        service.remoteObjectInterface = NSXPCInterface(with: (any SKKServClientProtocol).self)
    }

    func serverVersion(destination: SKKServDestination) async throws -> String {
        service.resume()
        defer {
            service.invalidate()
        }
        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.invalidProxy
        }
        return try await proxy.serverVersion(destination: destination)
    }
}
