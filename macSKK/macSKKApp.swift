// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct macSKKApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func isTest() -> Bool {
        return ProcessInfo.processInfo.environment["MACSKK_IS_TEST"] == "1"
    }
}
