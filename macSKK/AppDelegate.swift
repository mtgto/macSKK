// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Appの初期化処理でセットされる
    var settingsWindowController: NSWindowController!

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        logger.log("アプリケーションが終了する前にユーザー辞書の永続化を行います")
        try? dictionary.save()
        return .terminateNow
    }

    func showSettingsWindow() {
        settingsWindowController.showWindow(nil)
    }
}
