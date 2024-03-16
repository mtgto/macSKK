// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct SKKServService {
    func test(destination: SKKServDestination) async throws {
        let service = NSXPCConnection(serviceName: "net.mtgto.inputmethod.macSKK.FetchUpdateService")
        service.remoteObjectInterface = NSXPCInterface(with: (any SKKServClientProtocol).self)
        service.resume()

        defer {
            service.invalidate()
        }

        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.invalidProxy
        }
        let response = try await proxy.serverVersion(destination: destination)
    }
}
