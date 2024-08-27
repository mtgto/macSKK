// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

final class SettingsWindow: NSWindow {
    init(settingsViewModel: SettingsViewModel) {
        let rootView = SettingsView(settingsViewModel: settingsViewModel)
        let viewController = NSHostingController(rootView: rootView)
        super.init(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView, .unifiedTitleAndToolbar], backing: .buffered, defer: true)
        contentViewController = viewController
        isExcludedFromWindowsMenu = true
        center()
    }
}
