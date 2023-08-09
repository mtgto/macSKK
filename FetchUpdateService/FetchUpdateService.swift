// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

class FetchUpdateService: NSObject, FetchUpdateServiceProtocol {
    @objc func uppercase(string: String, with reply: @escaping (String) -> Void) {
        let response = string.uppercased()
        reply(response)
    }
}
