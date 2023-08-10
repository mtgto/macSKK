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

    // atomをパースして返すので新しい順で返す
    func fetch() async throws -> [Release] {
        let service = NSXPCConnection(serviceName: "net.mtgto.inputmethod.macSKK.FetchUpdateService")
        service.remoteObjectInterface = NSXPCInterface(with: FetchUpdateServiceProtocol.self)
        service.resume()
        
        defer {
            service.invalidate()
        }

        guard let proxy = service.remoteObjectProxy as? FetchUpdateServiceProtocol else {
            throw FetchUpdateServiceError.invalidProxy
        }
        let response = try await proxy.fetch()
        let doc = try XMLDocument(data: response)
        return try parseDocument(doc)
    }

    func parseDocument(_ doc: XMLDocument) throws -> [Release] {
        return try doc.nodes(forXPath: "feed/entry").compactMap { node -> Release? in
            try parseEntryNode(node)
        }
    }

    func parseEntryNode(_ node: XMLNode) throws -> Release? {
        guard let version = try node.nodes(forXPath: "title").first?.stringValue.flatMap({ ReleaseVersion(string: $0) }) else {
            logger.warning("リリース情報のXMLが不正です (title)")
            return nil
        }
        guard let link = try node.nodes(forXPath: "link/@href").first?.stringValue.flatMap({ URL(string: $0) }) else {
            logger.warning("リリース情報のXMLが不正です (link)")
            return nil
        }
        guard let updated = try node.nodes(forXPath: "updated").first?.stringValue.flatMap({ ISO8601DateFormatter().date(from: $0) }) else {
            logger.warning("リリース情報のXMLが不正です (updated)")
            return nil
        }
        return Release(version: version, updated: updated, url: link)
    }
}
