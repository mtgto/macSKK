// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import OSLog
import SwiftUI

struct LogView: View {
    @State var log: String

    var body: some View {
        Form {
            Text(log)
                .textSelection(.enabled)
            Spacer()
            Button {
                
            } label: {
                Text("クリップボードにコピー")
            }

        }
        .padding()
        .onAppear(perform: {
            do {
                let logStore = try OSLogStore(scope: .currentProcessIdentifier)
                let entries = try logStore.getEntries()
                self.log = entries.map { $0.composedMessage }.joined(separator: "\n")
            } catch {
                self.log = "アプリケーションログが取得できません: \(error)"
                logger.error("アプリケーションログが取得できません: \(error)")
            }
        })
    }
}

#Preview {
    LogView(log: ["12:34:56 ほげほげがほげほげしました", "12:34:56 ふがふががふがふがしました"].joined(separator: "\n"))
}
