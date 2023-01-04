// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import InputMethodKit
import SwiftUI
import os

let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "main")
var dictionary: UserDict!

@main
struct macSKKApp: App {
    private var server: IMKServer!

    init() {
        if isTest() {
            do {
                dictionary = try UserDict(dicts: [])
            } catch {
                logger.error("Error while loading userDictionary")
            }
        } else {
            guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
                fatalError("InputMethodConnectionName is not set")
            }
            setupDictionaries()
            server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDictionaries() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("SKK-JISYO.L")
        let dict: Dict
        do {
            dict = try Dict(contentsOf: url, encoding: .japaneseEUC)
        } catch {
            logger.error("Error while loading SKK-JISYO.L")
            return
        }
        do {
            dictionary = try UserDict(dicts: [dict])
            logger.info("Load \(dict.words.count) words")
        } catch {
            logger.error("Error while loading userDictionary: \(error)")
        }
    }

    private func isTest() -> Bool {
        return ProcessInfo.processInfo.environment["MACSKK_IS_TEST"] == "1"
    }
}
