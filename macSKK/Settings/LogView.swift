// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import OSLog
import SwiftUI

struct LogView: View {
    @State var log: String

    var body: some View {
        Form {
            TextEditor(text: .constant(log))
            Spacer()
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(log, forType: .string)
            } label: {
                Text("Copy")
            }

        }
        .padding()
        .task {
            do {
                let logStore = try OSLogStore(scope: .currentProcessIdentifier)
                let entries = try logStore.getEntries()
                    .compactMap { entry -> OSLogEntryLog? in
                        guard let entry = entry as? OSLogEntryLog else { return nil }
                        guard entry.subsystem == Bundle.main.bundleIdentifier! else { return nil }
                        return entry
                    }
                let format = Date.ISO8601FormatStyle.iso8601Date(timeZone: TimeZone.current)
                    .dateTimeSeparator(.space)
                    .time(includingFractionalSeconds: true)
                self.log = entries.map { entry in
                    [
                        "[\(entry.date.formatted(format))]",
                        "[\(levelDescription(level: entry.level))]",
                        "\(entry.composedMessage)",
                    ].joined(separator: " ")
                }.joined(separator: "\n")
            } catch {
                self.log = "アプリケーションログが取得できません: \(error)"
                logger.error("アプリケーションログが取得できません: \(error)")
            }
        }
    }

    private func levelDescription(level: OSLogEntryLog.Level) -> String {
        switch level {
        case .undefined:
            return "undefined"
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .notice:
            return "notice"
        case .error:
            return "error"
        case .fault:
            return "fault"
        @unknown default:
            logger.error("未知のログレベル \(level.rawValue) が使用されました")
            return "unknown"
        }
    }
}

#Preview {
    LogView(log: ["12:34:56 ほげほげがほげほげしました", "12:34:56 ふがふががふがふがしました"].joined(separator: "\n"))
}
