// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import InputMethodKit
import SwiftUI
import os

let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "main")

@main
struct macSKKApp: App {
    private var server: IMKServer!

    init() {
        if !self.isTest() {
            guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
                fatalError("InputMethodConnectionName is not set")
            }
            self.server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func isTest() -> Bool {
        return ProcessInfo.processInfo.environment["MACSKK_IS_TEST"] == "1"
    }
}
