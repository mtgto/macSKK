// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa

/// ローマ字かな変換ルールファイルの変更を監視する
class KanaRuleWatcher: NSObject {
    // MARK: NSFilePresenter
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = OperationQueue()

    init(kanaRuleFileName: String = "kana-rule.conf") throws {
        presentedItemURL = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ).appending(path: kanaRuleFileName)
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }
}

extension KanaRuleWatcher: NSFilePresenter {
    func presentedItemDidChange() {
        logger.log("ローマ字かな変換ルールファイルが変更されました")
    }

    func presentedItemDidMove(to newURL: URL) {
        logger.log("ローマ字かな変換ルールファイルが移動されました")
    }

    func accommodatePresentedItemDeletion(completionHandler: @escaping @Sendable (Error?) -> Void) {
        logger.log("ローマ字かな変換ルールファイルが削除されます")
    }
}
