// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Network

extension NWParameters {
    static var skkserv: NWParameters {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 5
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveInterval = 30
        tcpOptions.keepaliveCount = 3
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        let options = NWProtocolFramer.Options(definition: SKKServProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols = [options]
        // parameters.acceptLocalOnly = true
        return parameters
    }
}
