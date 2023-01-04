// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct KeyEventView: View {
    @State private var text: String = ""
    @State private var eventMonitor: Any!
    @State private var event: NSEvent?

    var body: some View {
        VStack(alignment: .leading) {
            TextField("", text: $text)
                .onAppear {
                    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                        debugPrint(event.characters ?? "nil")
                        self.event = event
                        return event
                    }
                }
                .onDisappear {
                    NSEvent.removeMonitor(eventMonitor!)
                }
            Grid(alignment: .topLeading) {
                GridRow {
                    Text("KeyCode")
                    Text(event?.keyCode.description ?? "")
                }
                Divider()
                GridRow {
                    Text("Characters")
                    Text(event?.characters ?? "")
                }
                Divider()
                GridRow {
                    Text("CharactersIgnoringModifiers")
                    Text(event?.charactersIgnoringModifiers ?? "")
                }
                Divider()
                GridRow {
                    Text("Shift")
                    Text(event?.modifierFlags.contains(.shift).description ?? "")
                }
            }
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.blue, lineWidth: 4)
            )
        }
        .padding()
    }
}

struct KeyEventView_Previews: PreviewProvider {
    static var previews: some View {
        KeyEventView()
    }
}
