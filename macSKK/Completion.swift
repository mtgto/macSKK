// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum Completion {
    /// 読みの一部と読みの全部のペア
    case single(String, String)
    case multiple([Candidate])
}
