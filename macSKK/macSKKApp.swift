// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import InputMethodKit
import SwiftUI
import UserNotifications
import os

let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "main")
var dictionary: UserDict!
let privateMode = CurrentValueSubject<Bool, Never>(false)

func isTest() -> Bool {
    return ProcessInfo.processInfo.environment["MACSKK_IS_TEST"] == "1"
}

@main
struct macSKKApp: App {
    /// ユニットテスト実行時はnil
    private let server: IMKServer?
    @ObservedObject var settingsViewModel: SettingsViewModel
    /// SKK辞書を配置するディレクトリ
    /// "~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries"
    private let dictionariesDirectoryUrl: URL
    private let userNotificationDelegate = UserNotificationDelegate()
    @State private var fetchReleaseTask: Task<Void, Error>?
    #if DEBUG
    private let candidatesPanel: CandidatesPanel = CandidatesPanel()
    private let inputModePanel = InputModePanel()
    #endif

    init() {
        do {
            dictionary = try UserDict(dicts: [], privateMode: privateMode)
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
        if !isTest() && Bundle.main.bundleURL.deletingLastPathComponent().lastPathComponent == "Input Methods" {
            guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
            else {
                fatalError("InputMethodConnectionName is not set")
            }
            server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
        } else {
            server = nil
        }
        setupUserDefaults()
        if !isTest() {
            do {
                try setupDictionaries()
            } catch {
                logger.error("辞書の読み込みに失敗しました")
            }
            setupNotification()
            setupReleaseFetcher()
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
                Button("AnnotationsPanel") {
                    let word = Word("インライン", annotation: String(repeating: "これはインラインのテスト用注釈です", count: 5))
                    candidatesPanel.setCandidates(.inline, selected: word)
                    candidatesPanel.setCursorPosition(NSRect(origin: NSPoint(x: 100, y: 640), size: CGSize(width: 0, height: 30)))
                    candidatesPanel.show()
                }
                Button("SystemAnnotation") {
                    let word = Word("インライン", annotation: String(repeating: "これはインラインのテスト用注釈です", count: 5))
                    candidatesPanel.viewModel.systemAnnotations = [word: (String(repeating: "これはシステム辞書の注釈です。", count: 5))]
                }
                Button("Show CandidatesPanel") {
                    let words = [Word("こんにちは", annotation: "辞書の注釈"), Word("こんばんは"), Word("おはようございます")]
                    candidatesPanel.setCandidates(.panel(words: words, currentPage: 0, totalPageCount: 1), selected: words.first)
                    candidatesPanel.setCursorPosition(NSRect(origin: NSPoint(x: 100, y: 20), size: CGSize(width: 0, height: 30)))
                    candidatesPanel.show()
                }
                Button("Add Word") {
                    let words = [Word("こんにちは", annotation: "辞書の注釈"), Word("こんばんは"), Word("おはようございます"), Word("追加したよ", annotation: "辞書の注釈")]
                    candidatesPanel.setCandidates(.panel(words: words, currentPage: 0, totalPageCount: 1), selected: words.last)
                    candidatesPanel.viewModel.systemAnnotations = [words.last!: String(repeating: "これはシステム辞書の注釈です。", count: 5)]
                }
                Button("InputMode Panel") {
                    inputModePanel.show(at: NSPoint(x: 200, y: 200), mode: .hiragana, privateMode: true)
                }
                Button("User Notification") {
                    let release = Release(version: ReleaseVersion(major: 0, minor: 4, patch: 0),
                                          updated: Date(),
                                          url: URL(string: "https://github.com/mtgto/macSKK/releases/tag/0.4.0")!)
                    sendPushNotificationForRelease(release)
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

    // UNNotificationの設定
    private func setupNotification() {
        let center = UNUserNotificationCenter.current()
        center.delegate = userNotificationDelegate
    }

    private func setupReleaseFetcher() {
        guard let shortVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let currentVersion = ReleaseVersion(string: shortVersionString) else {
            fatalError("現在のバージョンが不正な状態です")
        }
        fetchReleaseTask = Task.detached(priority: .low) {
            var sleepDuration: Duration = .seconds(12 * 60 * 60) // 12時間休み
            while true {
                try await Task.sleep(for: sleepDuration)
                logger.log("スケジュールされていた更新チェックを行います")
                do {
                    let release = try await settingsViewModel.fetchLatestRelease()
                    if release.version > currentVersion {
                        logger.log("新しいバージョン \(release.version, privacy: .public) が見つかりました")
                        sleepDuration = .seconds(7 * 24 * 60 * 60) // 1週間休み
                        await sendPushNotificationForRelease(release)
                    } else {
                        logger.log("更新チェックをしましたが新しいバージョンは見つかりませんでした")
                    }
                } catch is CancellationError {
                    logger.log("スケジュールされていた更新チェックがキャンセルされました")
                    break
                } catch {
                    // 通信エラーなどでここに来るかも? 次回は成功するかもしれないのでログだけ吐いて続行
                    logger.error("更新チェックに失敗しました: \(error)")
                }
            }
        }
    }

    private func sendPushNotificationForRelease(_ release: Release) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization { granted, error in
            if let error {
                logger.log("通知センターへの通知ができない状態です:\(error)")
                return
            }
            if !granted {
                logger.log("通知センターへの通知がユーザーに拒否されています")
                return
            }
            let release = Release(version: ReleaseVersion(major: 0, minor: 4, patch: 0),
                                  updated: Date(),
                                  url: URL(string: "https://github.com/mtgto/macSKK/releases/tag/0.4.0")!)
            let request = release.userNotificationRequest()
            center.add(request) { error in
                if let error {
                    logger.error("通知センターへの通知に失敗しました: \(error)")
                }
            }
        }
    }

    private func loadFileDict(fileURL: URL, encoding: String.Encoding) throws -> FileDict {
        return try FileDict(contentsOf: fileURL, encoding: encoding)
    }
}
