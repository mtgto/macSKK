// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct KeyEventView: View {
    @State private var text: String = ""
    @State private var eventMonitor: Any!
    @State private var characters: String = ""
    @State private var charactersIgnoringModifiers: String = ""
    @State private var keyCode: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            TextField("", text: $text)
                .onAppear {
                    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                        characters = event.characters ?? ""
                        charactersIgnoringModifiers = event.charactersIgnoringModifiers ?? ""
                        keyCode = event.keyCode.description
                        return event
                    }
                }
                .onDisappear {
                    NSEvent.removeMonitor(eventMonitor!)
                }
            Form {
                Section {
                    TextField("KeyCode", text: .constant(keyCode))
                }
                Section {
                    TextField("Characters", text: .constant(characters))
                }
                Section {
                    TextField("CharactersIgnoringModifiers", text: .constant(charactersIgnoringModifiers))
                }
            }
        }
        .padding()
    }
}

struct KeyEventView_Previews: PreviewProvider {
    static var previews: some View {
        KeyEventView()
    }
}
