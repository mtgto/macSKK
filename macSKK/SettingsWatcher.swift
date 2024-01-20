// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa

/**
 * App Sandbox Data ContainerのSettingsフォルダを監視する
 *
 * 現状はローマ字かな変換ルールファイル (kana-rule.conf) のみを対象としています。
 */
class SettingsWatcher: NSObject {
    let kanaRuleFileName: String
    // MARK: NSFilePresenter
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = OperationQueue()

    init(kanaRuleFileName: String = "kana-rule.conf") throws {
        self.kanaRuleFileName = kanaRuleFileName
        let settingsDirectoryURL = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ).appending(path: "Settings")
        if !FileManager.default.fileExists(atPath: settingsDirectoryURL.path) {
            logger.log("設定フォルダがないため作成します")
            try FileManager.default.createDirectory(at: settingsDirectoryURL, withIntermediateDirectories: true)
        }
        self.presentedItemURL = settingsDirectoryURL
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }
}

extension SettingsWatcher: NSFilePresenter {
    func presentedSubitemDidAppear(at url: URL) {
        if url.lastPathComponent == kanaRuleFileName {
            logger.log("ローマ字かな変換ルールファイルが作成されたため読み込みます")
        }
    }

    func presentedSubitemDidChange(at url: URL) {
        if url.lastPathComponent == kanaRuleFileName {
            // 削除されたときにaccommodatePresentedSubitemDeletionが呼ばれないがこのメソッドは呼ばれるようだった。
            // そのためこのメソッドで削除のとき同様の処理を行う。
            logger.log("ローマ字かな変換ルールファイルが変更されたため読み込みます")
        }
    }
}
