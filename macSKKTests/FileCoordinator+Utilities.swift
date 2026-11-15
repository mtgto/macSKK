// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension NSFileCoordinator {
    /// 別のNSFileCoordinatorから協調して書き込み、外部エディタでの変更を模倣する
    static func writeExternally(_ source: String, to fileURL: URL) throws {
        var coordinationError: NSError?
        var writingError: (any Error)?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { url in
            do {
                try source.data(using: .utf8)!.write(to: url)
            } catch {
                writingError = error
            }
        }
        if let error = coordinationError ?? writingError {
            throw error
        }
    }
}
