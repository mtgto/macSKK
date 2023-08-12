// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
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
    @ObservedObject var settingsViewModel: SettingsViewModel
    private var cancellables: Set<AnyCancellable> = []
    /// SKK辞書を配置するディレクトリ
    /// "~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries"
    private let dictionariesDirectoryUrl: URL

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
        // setupDictionaries後に辞書ファイルの読み込みを開始する
        do {
            try settingsViewModel.setupEvents()
        } catch {
            logger.error("辞書フォルダの読み込みとイベントハンドラの登録に失敗しました: \(error)")
        }

        // 設定が変更されたfileDictだけを見る
        // settingsViewModel.$fileDicts
        //     .zip(settingsViewModel.$fileDicts.dropFirst())
        //     .sink { (prev, curr) in
        //
        //     }
        //     .store(in: &cancellables)
//        settingsViewModel.$fileDicts
//            .filter { !$0.isEmpty && dictionary != nil }
//            .sink { dictSettings in
//                // 差分があれば更新する
//                dictSettings.forEach { dictSetting in
//                    if let dict = dictionary.fileDict(id: dictSetting.id) {
//                        if !dictSetting.enabled {
//                            // dictをdictionaryから削除する
////                            _ = dictionary.deleteDict(id: dictSetting.id)
//                        } else if dictSetting.encoding != dict.encoding {
//                            // encodingを変えて読み込み直す
//                            let fileURL = self.dictionariesDirectoryUrl.appendingPathComponent(dictSetting.filename)
////                            do {
////                                let fileDict = try FileDict(contentsOf: fileURL, encoding: dictSetting.encoding)
////                                //dictionary.replateDict(fileDict)
////                            } catch {
////                                logger.log("SKK辞書 \(dictSetting.filename) の読み込みに失敗しました: \(error)")
////                            }
//                        }
//                    } else {
//                        // dictSettingsの設定でFileDictを読み込んでdictionaryに追加
//                    }
//                }
//                // dictSettingsをUserDefaultsに永続化する
//            }
//            .store(in: &cancellables)
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
                #endif
            }
        }
    }

    private func setupUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "dictionaries")
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
            logger.error("環境設定の辞書設定が壊れています")
            return
        }
        settingsViewModel.fileDicts = dictSettings
//
//        // 辞書ディレクトリ直下にあるファイル一覧(シンボリックリンク、サブディレクトリは探索しない)
//        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey]
//        let enumerator = FileManager.default.enumerator(at: dictionariesDirectoryUrl,
//                                                        includingPropertiesForKeys: Array(resourceKeys),
//                                                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
//        guard let enumerator else {
//            logger.error("辞書フォルダのファイル一覧が取得できません")
//            dictionary = try UserDict(dicts: [])
//            return
//        }
//        var userDicts: [FileDict] = []
//        for case let fileURL as URL in enumerator {
//            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
//                let isDirectory = resourceValues.isDirectory,
//                let filename = resourceValues.name
//                else {
//                    continue
//                }
//            if isDirectory || filename == UserDict.userDictFilename {
//                continue
//            }
//            if let setting = dictSettings.first(where: { $0.filename == filename }) {
//                if !setting.enabled {
//                    logger.log("\(filename) は読み込みをスキップします")
//                    continue
//                }
//                do {
//                    let dict = try FileDict(contentsOf: fileURL, encoding: setting.encoding)
//                    userDicts.append(dict)
//                    logger.log("\(setting.filename, privacy: .public)から \(dict.entries.count) エントリ読み込みました")
//                } catch {
//                    // TODO: NotificationCenter経由でユーザーにエラー理由を通知する
//                    logger.error("SKK辞書 \(setting.filename) の読み込みに失敗しました: \(error)")
//                    continue
//                }
//            } else {
//                // FIXME: 起動時にだけSKK辞書ファイルを検査するんじゃなくてディレクトリを監視自体を監視しておいたほうがよさそう
//                // UserDefaultsの辞書設定に存在しないファイルが見つかったのでデフォルトEUC-JPにしておく
//                logger.log("新しい辞書らしきファイル \(filename, privacy: .public) がみつかりました")
//                dictSettings.append(DictSetting(filename: filename, enabled: false, encoding: .japaneseEUC))
//            }
//        }
//        dictionary = try UserDict(dicts: userDicts)
//        UserDefaults.standard.set(dictSettings.map { $0.encode() }, forKey: "dictionaries")
//        settingsViewModel.fileDicts = dictSettings.map {
//            DictSetting(filename: $0.filename, enabled: $0.enabled, encoding: $0.encoding)
//        }
    }

    private func loadFileDict(fileURL: URL, encoding: String.Encoding) throws -> FileDict {
        return try FileDict(contentsOf: fileURL, encoding: encoding)
    }
}
