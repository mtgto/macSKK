// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import OSLog
import SwiftUI

struct LogView: View {
    @State var log: String
    @State private var loading: Bool = false

    var body: some View {
        Form {
            TextEditor(text: .constant(log))
            Spacer()
            HStack {
                if loading {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(log, forType: .string)
                } label: {
                    Text("Copy")
                }
                .disabled(loading)
            }

        }
        .padding()
        .task {
            loading = true
            do {
                self.log = try load()
            } catch {
                self.log = "アプリケーションログが取得できません: \(error)"
                logger.error("アプリケーションログが取得できません: \(error)")
            }
            loading = false
        }
    }

    private func load() throws -> String {
        func levelDescription(level: OSLogEntryLog.Level) -> String {
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
        let logStore = try OSLogStore(scope: .currentProcessIdentifier)
        let predicate = NSPredicate(format: "subsystem == %@", Bundle.main.bundleIdentifier!)
        let logs = try logStore.getEntries(matching: predicate).compactMap { $0 as? OSLogEntryLog }
        let format = Date.ISO8601FormatStyle.iso8601Date(timeZone: TimeZone.current)
            .dateTimeSeparator(.space)
            .time(includingFractionalSeconds: true)
        return logs.map { entry in
            [
                "[\(entry.date.formatted(format))]",
                "[\(levelDescription(level: entry.level))]",
                "\(entry.composedMessage)",
            ].joined(separator: " ")
        }.joined(separator: "\n")
    }
}

#Preview {
    LogView(log: ["[2024-01-01 12:34:56.789] [info] ほげほげがほげほげしました", "[2024-01-01 12:34:56.789] [info]  ふがふががふがふがしました"].joined(separator: "\n"))
}
