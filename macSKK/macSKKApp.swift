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
    private var panel: CandidatesPanel! = CandidatesPanel()

    init() {
        if isTest() {
            do {
                dictionary = try UserDict(dicts: [])
            } catch {
                logger.error("Error while loading userDictionary")
            }
        } else {
            setupDictionaries()
            if Bundle.main.bundleURL.deletingLastPathComponent().lastPathComponent == "Input Methods" {
                guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
                    fatalError("InputMethodConnectionName is not set")
                }
                server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
            }
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
                Button("Show CandidatesPanel") {
                    panel.setWords([Word("こんにちは"), Word("こんばんは"), Word("おはようございます")], selected: nil)
                    panel.setFrame(NSRect(x: 100, y: 100, width: 400, height: 400), display: true)
                    panel.level = .floating
                    panel.orderFront(nil)
                }
                Button("Add Word") {
                    panel.setWords(
                        [Word("こんにちは"), Word("こんばんは"), Word("おはようございます"), Word("追加したよ")], selected: Word("追加したよ"))
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
