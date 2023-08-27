// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa

@MainActor
final class DirectModeViewModel: ObservableObject {
    /// 直接入力するアプリケーションのBundle Identifier
    @Published var bundleIdentifiers: [String] = []
}
