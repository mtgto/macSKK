// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import Combine

// ローマ字かな変換ファイルが作成されたイベントの通知の名前。objectはRomaji
let notificationNameKanaRuleDidAppear = Notification.Name("kanaRuleDidAppear")
// ローマ字かな変換ファイルが更新されたイベントの通知の名前。objectはRomaji
let notificationNameKanaRuleDidChange = Notification.Name("kanaRuleDidChange")
// ローマ字かな変換ファイルが移動されたイベントの通知の名前。objectはRomaji.ID
let notificationNameKanaRuleDidMove = Notification.Name("kanaRuleDidMove")

/**
 * App Sandbox Data ContainerのSettingsフォルダを監視する
 *
 * 現状はローマ字かな変換ルールファイル (kana-rule.conf) のみを対象としています。
 */
final class SettingsWatcher: NSObject, Sendable {
    private let kanaRuleFileName: String
    private let settingsDirectoryURL: URL
    // MARK: NSFilePresenter
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = OperationQueue()

    @MainActor init(kanaRuleFileName: String = "kana-rule.conf") throws {
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
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }

    @MainActor func availableKanaRules() throws -> [Romaji] {
        let urls = try FileManager.default.contentsOfDirectory(at: settingsDirectoryURL,
                                                               includingPropertiesForKeys: [.isReadableKey],
                                                               options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        return try urls.compactMap { url -> Romaji? in
            let resourceValues = try url.resourceValues(forKeys: [.isReadableKey])
            guard let isReadable = resourceValues.isReadable, isReadable else { return nil }
            let filename = url.lastPathComponent
            if filename.hasPrefix("kana-rule") && filename.hasSuffix(".conf") {
                do {
                    return try Romaji(contentsOf: url, initialRomaji: Global.defaultKanaRule)
                } catch {
                    logger.warning("ローマ字かな変換ルール \(filename, privacy: .public) の読み込みに失敗しました: \(String(describing: error), privacy: .public)")
                    return nil
                }
            } else {
                return nil
            }
        }
    }
}

extension SettingsWatcher: NSFilePresenter {
    func presentedSubitemDidAppear(at url: URL) {
        let filename = url.lastPathComponent
        if filename.hasPrefix("kana-rule") && filename.hasSuffix(".conf") {
            logger.log("ローマ字かな変換ルールファイル \(filename, privacy: .public)が作成されたため読み込みます")
            Task { @MainActor in
                let kanaRule = try Romaji(contentsOf: url, initialRomaji: Global.defaultKanaRule)
                NotificationCenter.default.post(name: notificationNameKanaRuleDidAppear, object: kanaRule)
            }
        } else {
            return
        }
    }

    func presentedSubitemDidChange(at url: URL) {
        // macOS 26.2では同一フォルダ内でのリネームの場合、このメソッドが二回呼び出される
        let filename = url.lastPathComponent
        if filename.hasPrefix("kana-rule") && filename.hasSuffix(".conf") {
            logger.log("ローマ字かな変換ルールファイル \(filename, privacy: .public)が修正されたため読み込みます")
            Task { @MainActor in
                let kanaRule = try Romaji(contentsOf: url, initialRomaji: Global.defaultKanaRule)
                NotificationCenter.default.post(name: notificationNameKanaRuleDidChange, object: kanaRule)
            }
        }
    }

    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
        logger.log("ファイル \(oldURL.lastPathComponent, privacy: .public) が移動されました")
        NotificationCenter.default.post(name: notificationNameKanaRuleDidMove, object: oldURL.lastPathComponent)
    }
}
