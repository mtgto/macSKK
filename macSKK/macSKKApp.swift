// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import InputMethodKit
import SwiftUI
import os

let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "main")
var dictionary: UserDict!
let privateMode = CurrentValueSubject<Bool, Never>(false)

func isTest() -> Bool {
    return ProcessInfo.processInfo.environment["MACSKK_IS_TEST"] == "1"
}

@main
struct macSKKApp: App {
    private var server: IMKServer!
    @ObservedObject var settingsViewModel: SettingsViewModel
    /// SKK辞書を配置するディレクトリ
    /// "~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries"
    private let dictionariesDirectoryUrl: URL
    #if DEBUG
    private var panel: CandidatesPanel! = CandidatesPanel()
    private let inputModePanel = InputModePanel()
    #endif

    init() {
        do {
            dictionary = try UserDict(dicts: [])
            dictionariesDirectoryUrl = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ).appendingPathComponent("Dictionaries")
            settingsViewModel = try SettingsViewModel(dictionariesDirectoryUrl: dictionariesDirectoryUrl)
        } catch {
            fatalError("辞書設定でエラーが発生しました: \(error)")
        }
        setupUserDefaults()
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
                Button("InputMode Panel") {
                    inputModePanel.show(at: NSPoint(x: 200, y: 200), mode: .hiragana, privateMode: true)
                }
                #endif
            }
        }
    }

    private func setupUserDefaults() {
        UserDefaults.standard.register(defaults: [
            "dictionaries": [
                DictSetting(filename: "SKK-JISYO.L", enabled: true, encoding: .japaneseEUC).encode()
            ],
        ])
    }

    // Dictionariesフォルダのファイルのうち、UserDefaultsで有効になっているものだけ読み込む
    private func setupDictionaries() throws {
        let dictSettings = UserDefaults.standard.array(forKey: "dictionaries")?.compactMap { obj in
            if let setting = obj as? [String: Any] {
                return DictSetting(setting)
            } else {
                return nil
            }
        }
        guard let dictSettings else {
            // 再起動してもおそらく同じ理由でこけるので、リセットしちゃう
            // TODO: Notification Center経由でユーザーにも破壊的処理が起きたことを通知してある
            logger.error("環境設定の辞書設定が壊れています")
            UserDefaults.standard.removeObject(forKey: "dictionaries")
            return
        }
        try settingsViewModel.setDictSettings(dictSettings)
    }

    private func loadFileDict(fileURL: URL, encoding: String.Encoding) throws -> FileDict {
        return try FileDict(contentsOf: fileURL, encoding: encoding)
    }
}
