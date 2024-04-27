// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

fileprivate let requestKey = "request"
fileprivate let responseKey = "response"

extension NWProtocolFramer.Message {
    convenience init(request: SKKServRequest) {
        self.init(definition: SKKServProtocol.definition)
        self[requestKey] = request
    }

    convenience init(response: Data) {
        self.init(definition: SKKServProtocol.definition)
        self[responseKey] = response
    }

    var request: SKKServRequest? {
        self[requestKey] as? SKKServRequest
    }

    var response: Data? {
        self[responseKey] as? Data
    }
}
