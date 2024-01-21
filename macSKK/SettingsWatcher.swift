// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa

/**
 * App Sandbox Data ContainerのSettingsフォルダを監視する
 *
 * 現状はローマ字かな変換ルールファイル (kana-rule.conf) のみを対象としています。
 */
class SettingsWatcher: NSObject {
    private let kanaRuleFileName: String
    private let settingsDirectoryURL: URL
    // MARK: NSFilePresenter
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = OperationQueue()

    init(kanaRuleFileName: String = "kana-rule.conf") throws {
        self.kanaRuleFileName = kanaRuleFileName
        settingsDirectoryURL = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ).appending(path: "Settings")
        if !FileManager.default.fileExists(atPath: settingsDirectoryURL.path) {
            logger.log("設定フォルダがないため作成します")
            try FileManager.default.createDirectory(at: settingsDirectoryURL, withIntermediateDirectories: true)
        }
        self.presentedItemURL = settingsDirectoryURL
        super.init()
        let kanaRuleURL = settingsDirectoryURL.appending(path: kanaRuleFileName)
        if FileManager.default.fileExists(atPath: kanaRuleURL.path) {
            loadKanaRule(contentsOf: kanaRuleURL)
        }
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }

    func loadKanaRule(contentsOf url: URL) {
        do {
            if try url.isReadable() {
                kanaRule = try Romaji(contentsOf: url)
                logger.log("独自のローマ字かな変換ルールを適用しました")
            } else {
                logger.log("ローマ字かなルールファイルとして不適合なファイルであるため読み込みできませんでした")
            }
        } catch {
            logger.error("ローマ字かな変換ルールの読み込みでエラーが発生しました: \(error)")
        }
    }
}

extension SettingsWatcher: NSFilePresenter {
    func presentedSubitemDidAppear(at url: URL) {
        if url.lastPathComponent == kanaRuleFileName {
            logger.log("ローマ字かな変換ルールファイルが作成されたため読み込みます")
            loadKanaRule(contentsOf: url)
        }
    }

    func presentedSubitemDidChange(at url: URL) {
        if url.lastPathComponent == kanaRuleFileName {
            // 削除されたときにaccommodatePresentedSubitemDeletionが呼ばれないがこのメソッドは呼ばれるようだった。
            // そのためこのメソッドで削除のとき同様の処理を行う。
            if !FileManager.default.fileExists(atPath: settingsDirectoryURL.appending(path: kanaRuleFileName).path) {
                logger.log("ローマ字かな変換ルールファイルが存在しなくなったためデフォルトのルールに戻します")
                kanaRule = defaultKanaRule
                return
            }

            var relationship: FileManager.URLRelationship = .same
            do {
                try FileManager.default.getRelationship(&relationship, ofDirectoryAt: settingsDirectoryURL, toItemAt: url)
                if case .contains = relationship {
                    logger.log("ローマ字かな変換ルールファイルが変更されたため読み込みます")
                    loadKanaRule(contentsOf: url)
                }
            } catch {
                logger.error("ローマ字かな変換ルールファイルが更新されましたが情報取得に失敗しました: \(error)")
            }
        }
    }
}
