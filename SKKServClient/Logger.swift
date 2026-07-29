// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os

/// SKKServClientターゲット共通のロガー。
///
/// - NOTE: テストターゲット (SKKServClientTests) からも参照するため、
///         XPCの実装 (SKKServClient.swift) とは別ファイルに置いている。
let logger: Logger = Logger(subsystem: "net.mtgto.inputmethod.macSKK", category: "skkserv")

/// startからの経過ミリ秒。ログ出力用。
func elapsedMilliseconds(since start: DispatchTime) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
}
