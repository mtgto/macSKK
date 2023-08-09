// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct UpdateChecker {
    func callSampleXPC() async throws -> String {
        let service = NSXPCConnection(serviceName: "net.mtgto.inputmethod.macSKK.FetchUpdateService")
        service.remoteObjectInterface = NSXPCInterface(with: FetchUpdateServiceProtocol.self)
        service.resume()
        
        defer {
            service.invalidate()
        }

        guard let proxy = service.remoteObjectProxy as? FetchUpdateServiceProtocol else {
            return "ERROR"
        }
        let response = try await proxy.fetch()
        return String(data: response, encoding: .utf8) ?? "ERROR2"
    }
}
