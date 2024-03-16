// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SKKServDictView: View {
    @State var address: String
    @State var port: Int?
    @State var encoding: String.Encoding

    var body: some View {
        VStack {
            Form {
                Section("SKKServ Dictionary Setting") {
                    TextField("Address", text: $address)
                    TextField("Port", value: $port, format: .number, prompt: Text("1178"))
                    Picker("Response Encoding", selection: $encoding) {
                        ForEach(AllowedEncoding.allCases, id: \.encoding) { allowedEncoding in
                            Text(allowedEncoding.description).tag(allowedEncoding.encoding)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button {

                } label: {
                    Text("Test")
                        .padding([.leading, .trailing])
                }
                Spacer()
                Button {

                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)
                Button {

                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            Spacer()
        }
        .frame(width: 480, height: 270)
    }
}

#Preview {
    SKKServDictView(address: "127.0.0.1", port: nil, encoding: .japaneseEUC)
}
