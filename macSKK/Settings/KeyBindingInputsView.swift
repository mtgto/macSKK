// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// KeyBinding.Inputを編集可能な要素を切り出したもの
final class KeyBindingInput: ObservableObject, Identifiable, Hashable {
    var id = UUID()
    @Published var keyWithModifierFlags: (KeyBinding.Key, NSEvent.ModifierFlags)?
    var optionalModifierFlags: NSEvent.ModifierFlags
    var eventMonitor: Any!

    init(key: KeyBinding.Key, modifierFlags: NSEvent.ModifierFlags, optionalModifierFlags: NSEvent.ModifierFlags = []) {
        keyWithModifierFlags = (key, modifierFlags)
        self.optionalModifierFlags = optionalModifierFlags
    }

    init(input: KeyBinding.Input) {
        keyWithModifierFlags = (input.key, input.modifierFlags)
        optionalModifierFlags = input.optionalModifierFlags
    }

    var displayString: String {
        if let keyWithModifierFlags {
            let key = keyWithModifierFlags.0
            let modifierFlags = keyWithModifierFlags.1
            return KeyBinding.Input(key: key, displayString: key.displayString, modifierFlags: modifierFlags).localized
        } else {
            return ""
        }
    }

    static func == (lhs: KeyBindingInput, rhs: KeyBindingInput) -> Bool {
        switch (lhs.keyWithModifierFlags, rhs.keyWithModifierFlags) {
        case (.none, .none):
            return true
        case (.some, .none):
            return false
        case (.none, .some):
            return false
        case (.some(let lhs), .some(let rhs)):
            return lhs == rhs
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        if let keyWithModifierFlags {
            hasher.combine(keyWithModifierFlags.0)
            hasher.combine(keyWithModifierFlags.1.rawValue)
        }
    }
}

// あるキーバインドを変更するビュー。
struct KeyBindingInputsView: View {
    @Environment (\.dismiss) var dismiss
    @Binding var action: KeyBinding.Action
    @Binding var inputs: [KeyBindingInput]
    @State var selectedInput: KeyBindingInput?
    @State var optionalModifierFlags: NSEvent.ModifierFlags = []

    func optionalModifierFlag(_ flag: NSEvent.ModifierFlags) -> Binding<Bool> {
        Binding {
            optionalModifierFlags.contains(flag)
        } set: { newValue in
            if newValue {
                optionalModifierFlags.insert(flag)
            } else {
                optionalModifierFlags.remove(flag)
            }
        }
    }

    var body: some View {
        VStack {
            Form {
                Section(action.localizedAction) {
                    List(selection: $selectedInput) {
                        ForEach(inputs, id: \.id) { input in
                            TextField("", text: .constant(input.displayString))
                                .tag(input)
                                .onAppear {
                                    input.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                                        let key: KeyBinding.Key
                                        if let character = event.charactersIgnoringModifiers?.lowercased().first, KeyBinding.Key.characters.contains(character) {
                                            key = .character(character)
                                        } else {
                                            key = .code(event.keyCode)
                                        }
                                        let modifierFlags = event.modifierFlags
                                        print(key)
                                        print(modifierFlags)
                                        return nil
                                    }
                                }
                        }
                    }
                    .padding(.bottom, 24)
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 0) {
                            Button {

                            } label: { Image(systemName: "plus") }
                                .padding(.trailing, 8)
                            Divider()
                            Button {

                            } label: { Image(systemName: "minus") }
                                .padding(.leading, 8)
                            Spacer()
                        }
                        .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0))
                        .background(.separator)
                        .buttonStyle(.plain)
                        .controlSize(.small)
                        .frame(height: 24)
                    }
                }
                .onChange(of: optionalModifierFlags) { optionalModifierFlags in
                    if let selectedInput {
                        selectedInput.optionalModifierFlags = optionalModifierFlags
                    }
                }
                .onChange(of: selectedInput) { selectedInput in
                    if let selectedInput {
                        optionalModifierFlags = selectedInput.optionalModifierFlags
                    } else {
                        optionalModifierFlags = []
                    }
                }
                if let selectedInput {
                    Section("修飾キー (必須)") {
                        HStack {
                            Toggle("Control", isOn: .constant(selectedInput.keyWithModifierFlags?.1.contains(.control) ?? false))
                                .disabled(true)
                            Toggle("Option", isOn: .constant(selectedInput.keyWithModifierFlags?.1.contains(.option) ?? false))
                                .disabled(true)
                            Toggle("Shift", isOn: .constant(selectedInput.keyWithModifierFlags?.1.contains(.shift) ?? false))
                                .disabled(true)
                            Toggle("Function", isOn: .constant(selectedInput.keyWithModifierFlags?.1.contains(.function) ?? false))
                                .disabled(true)
                        }
                    }
                    Section("修飾キー (任意)") {
                        HStack {
                            Toggle("Control", isOn: optionalModifierFlag(.control))
                            Toggle("Option", isOn: optionalModifierFlag(.option))
                            Toggle("Shift", isOn: optionalModifierFlag(.shift))
                            Toggle("Function", isOn: optionalModifierFlag(.function))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .toggleStyle(.checkbox)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button {

                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .disabled(inputs.isEmpty)
                .keyboardShortcut(.defaultAction)
                .padding([.trailing, .bottom, .top])
            }
        }
        .frame(width: 480)
        .frame(minHeight: 400)
    }
}

#Preview {
    KeyBindingInputsView(action: .constant(.toggleKana),
                         inputs: .constant([
                            KeyBindingInput(key: .character("j"), modifierFlags: [.control]),
                            KeyBindingInput(key: .character("l"), modifierFlags: []),
                         ]),
                         selectedInput: KeyBindingInput(key: .character("j"), modifierFlags: [.control])
    )
}
