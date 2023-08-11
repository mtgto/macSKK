// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import InputMethodKit
import SwiftUI
import os

let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "main")
var dictionary: UserDict!

func isTest() -> Bool {
    return ProcessInfo.processInfo.environment["MACSKK_IS_TEST"] == "1"
}

@main
struct macSKKApp: App {
    private var server: IMKServer!
    private var panel: CandidatesPanel! = CandidatesPanel()
    @StateObject var settingsViewModel = SettingsViewModel()

    init() {
        if isTest() {
            do {
                dictionary = try UserDict(dicts: [])
            } catch {
                logger.error("Error while loading userDictionary")
            }
        } else {
            do {
                try setupDictionaries()
                if Bundle.main.bundleURL.deletingLastPathComponent().lastPathComponent == "Input Methods" {
                    guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
                    else {
                        fatalError("InputMethodConnectionName is not set")
                    }
                    server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
                }
            } catch {
                logger.error("辞書の読み込みに失敗しました")
            }
        }
    }

    var body: some Scene {
        Settings {
            SettingsView(settingsViewModel: settingsViewModel)
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
                #if DEBUG
                Button("Show CandidatesPanel") {
                    let words = [Word("こんにちは", annotation: "辞書の注釈"), Word("こんばんは"), Word("おはようございます")]
                    panel.setCandidates(CurrentCandidates(words: words, currentPage: 0, totalPageCount: 1), selected: words.first)
                    panel.show(cursorPosition: NSRect(origin: NSPoint(x: 100, y: 20), size: CGSize(width: 0, height: 30)))
                }
                Button("Add Word") {
                    let words = [Word("こんにちは", annotation: "辞書の注釈"), Word("こんばんは"), Word("おはようございます"), Word("追加したよ", annotation: "辞書の注釈")]
                    panel.setCandidates(CurrentCandidates(words: words, currentPage: 0, totalPageCount: 1), selected: words.last)
                    panel.viewModel.systemAnnotations = [words.last!: String(repeating: "これはシステム辞書の注釈です。", count: 5)]
                }
                Button("Alert") {
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("AlertMessageFoundNewRelease", comment: "Found New Release!")
                    alert.informativeText = String(format: NSLocalizedString("AlertInfoFoundNewRelease", comment: "macSKK %@ is now available. Would you like to download it now?"), "1.0.0")
                    alert.addButton(withTitle: NSLocalizedString("ButtonOpenReleasePage", comment: "Open Release Page in Browser"))
                    alert.addButton(withTitle: NSLocalizedString("ButtonCancel", comment: "Cancel"))
                    let result = alert.runModal()
                    if result == .alertFirstButtonReturn {
                        print("Push OK")
                    } else if result == .alertSecondButtonReturn {
                        print("Cancel")
                    }
                }
                #endif
            }
        }
    }

    private func setupDictionaries() throws {
        // "~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries"
        let url = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("Dictionaries").appendingPathComponent("SKK-JISYO.L")
        let dict: Dict
        do {
            dict = try Dict(contentsOf: url, encoding: .japaneseEUC)
        } catch {
            // TODO: NotificationCenter経由でユーザーにエラー理由を通知する
            logger.error("Error while loading SKK-JISYO.L")
            return
        }
        do {
            dictionary = try UserDict(dicts: [dict])
            logger.log("SKK-JISYO.Lから \(dict.entries.count) エントリ読み込みました")
        } catch {
            // TODO: NotificationCenter経由でユーザーにエラー理由を通知する
            logger.error("Error while loading userDictionary: \(error)")
        }
    }
}
