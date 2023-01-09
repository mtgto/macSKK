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
    private var inputModePanel: InputModePanel!

    init() {
        if isTest() {
            do {
                dictionary = try UserDict(dicts: [])
            } catch {
                logger.error("Error while loading userDictionary")
            }
        } else {
            setupDictionaries()
            logger.log("Bundle Path: \(Bundle.main.bundlePath, privacy: .public)")
            if Bundle.main.bundleURL.deletingLastPathComponent().lastPathComponent == "Input Methods" {
                guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
                    fatalError("InputMethodConnectionName is not set")
                }
                server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
            }
            inputModePanel = InputModePanel()
        }
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Save User Directory") {
                    do {
                        try dictionary.save()
                    } catch {
                        print(error)
                    }
                }.keyboardShortcut("S")
                Button("Show Panel") {
                    let point = NSPoint(x: 100, y: 200)
                    self.inputModePanel.show(at: point, mode: .hiragana)
                }
            }
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
            logger.info("Load \(dict.entries.count) entries")
        } catch {
            logger.error("Error while loading userDictionary: \(error)")
        }
    }

    private func isTest() -> Bool {
        return ProcessInfo.processInfo.environment["MACSKK_IS_TEST"] == "1"
    }
}
