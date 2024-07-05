// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct KeyWithModifierFlags: Hashable {
    let key: KeyBinding.Key
    let modifierFlags: NSEvent.ModifierFlags

    var displayString: String {
        KeyBinding.Input(key: key, modifierFlags: modifierFlags).localized
    }

    init(_ key: KeyBinding.Key, _ modifierFlags: NSEvent.ModifierFlags) {
        self.key = key
        self.modifierFlags = modifierFlags
    }

    // Equatable
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.key == rhs.key && lhs.modifierFlags == rhs.modifierFlags
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(modifierFlags.rawValue)
    }
}

// KeyBinding.Inputを編集可能な要素を切り出したもの
final class KeyBindingInput: ObservableObject, Identifiable, Hashable {
    var id = UUID()
    @Published var keyWithModifierFlags: KeyWithModifierFlags?
    @Published var displayString: String
    var optionalModifierFlags: NSEvent.ModifierFlags

    init(key: KeyBinding.Key, modifierFlags: NSEvent.ModifierFlags, optionalModifierFlags: NSEvent.ModifierFlags = []) {
        let keyWithModifierFlags = KeyWithModifierFlags(key, modifierFlags)
        self.keyWithModifierFlags = keyWithModifierFlags
        self.optionalModifierFlags = optionalModifierFlags
        self.displayString = keyWithModifierFlags.displayString
    }

    convenience init(input: KeyBinding.Input) {
        self.init(key: input.key, modifierFlags: input.modifierFlags, optionalModifierFlags: input.optionalModifierFlags)
    }

    init() {
        self.optionalModifierFlags = []
        self.displayString = ""
    }

    static func == (lhs: KeyBindingInput, rhs: KeyBindingInput) -> Bool {
        return lhs.keyWithModifierFlags == rhs.keyWithModifierFlags
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        if let keyWithModifierFlags {
            hasher.combine(keyWithModifierFlags)
        }
    }
}

// あるキーバインドを変更するビュー。
struct KeyBindingInputsView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @Environment (\.dismiss) var dismiss
    @Binding var action: KeyBinding.Action
    @Binding var inputs: [KeyBindingInput]
    @State var selectedInput: KeyBindingInput?
    @State var optionalModifierFlags: NSEvent.ModifierFlags = []
    @FocusState var editingInput: KeyBindingInput?
    @State var eventMonitor: Any? = nil
    @Environment(\.defaultMinListRowHeight) var defaultMinListRowHeight

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
                            TextField("", text: Binding(get: { input.displayString }, set: { _ in }))
                                .tag(input)
                                .focused($editingInput, equals: input)
                        }
                    }
                    .frame(minHeight: defaultMinListRowHeight * 3) // だいたい3行分くらい
                    .padding(.bottom, defaultMinListRowHeight)
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 0) {
                            Button {
                                let newInput = KeyBindingInput()
                                inputs.append(newInput)
                                editingInput = newInput
                            } label: {
                                Image(systemName: "plus")
                                    .contentShape(Rectangle())
                                    .frame(width: 20, height: 20)
                            }
                            .labelStyle(.iconOnly)
                            Divider()
                                .padding(.horizontal, 4)
                            Button {
                                if let selectedInput {
                                    inputs.removeAll(where: { $0 == selectedInput })
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .contentShape(Rectangle())
                                    .frame(width: 20, height: 20)
                            }
                            .labelStyle(.iconOnly)
                            .disabled(selectedInput == nil)
                            Spacer()
                        }
                        .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                        .background(.separator)
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .frame(height: defaultMinListRowHeight)
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
                .onChange(of: editingInput) { newEditingInput in
                    if let newEditingInput {
                        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                            let key: KeyBinding.Key
                            if let character = event.charactersIgnoringModifiers?.lowercased().first, KeyBinding.Key.characters.contains(character) {
                                key = .character(character)
                            } else {
                                key = .code(event.keyCode)
                            }
                            let modifierFlags = event.modifierFlags
                            if let editingInput {
                                let keyWithModifierFlags = KeyWithModifierFlags(key, modifierFlags)
                                editingInput.keyWithModifierFlags = keyWithModifierFlags
                                editingInput.displayString = keyWithModifierFlags.displayString
                            }
                            editingInput = nil
                            selectedInput = newEditingInput
                            return nil
                        }
                    } else {
                        // キー入力せずに別項目選択などで編集中じゃなくなったらその項目を削除する
                        inputs.removeAll(where: { input in
                            input.keyWithModifierFlags == nil
                        })
                        if let eventMonitor {
                            NSEvent.removeMonitor(eventMonitor)
                        }
                    }
                }
                Section("Modifier Flags (Required)") {
                    let modifierFlags = selectedInput?.keyWithModifierFlags?.modifierFlags ?? []
                    HStack {
                        Toggle("Control", isOn: .constant(modifierFlags.contains(.control)))
                        Toggle("Option", isOn: .constant(modifierFlags.contains(.option)))
                        Toggle("Shift", isOn: .constant(modifierFlags.contains(.shift)))
                        Toggle("Function", isOn: .constant(modifierFlags.contains(.function)))
                    }
                }
                .disabled(true)
                Section("Modifier Flags (Optional)") {
                    HStack {
                        Toggle("Control", isOn: optionalModifierFlag(.control))
                        Toggle("Option", isOn: optionalModifierFlag(.option))
                        Toggle("Shift", isOn: optionalModifierFlag(.shift))
                        Toggle("Function", isOn: optionalModifierFlag(.function))
                    }
                }
                .disabled(selectedInput == nil)
            }
            .formStyle(.grouped)
            .toggleStyle(.checkbox)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button {
                    let inputs = inputs.compactMap { input in
                        if let keyWithModifierFlags = input.keyWithModifierFlags {
                            return KeyBinding.Input(key: keyWithModifierFlags.key,
                                                    modifierFlags: keyWithModifierFlags.modifierFlags,
                                                    optionalModifierFlags: input.optionalModifierFlags)
                        } else {
                            return nil
                        }
                    }
                    settingsViewModel.updateKeyBindingInputs(action: action, inputs: inputs)
                    dismiss()
                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .disabled(inputs.allSatisfy({ $0.keyWithModifierFlags == nil }))
                .keyboardShortcut(.defaultAction)
                .padding([.trailing, .bottom, .top])
            }
        }
        .frame(width: 480)
        .frame(minHeight: 400)
    }
}

#Preview {
    KeyBindingInputsView(settingsViewModel: try! SettingsViewModel(),
                         action: .constant(.toggleKana),
                         inputs: .constant([
                            KeyBindingInput(key: .character("j"), modifierFlags: [.control]),
                            KeyBindingInput(key: .character("l"), modifierFlags: []),
                         ]),
                         selectedInput: KeyBindingInput(key: .character("j"), modifierFlags: [.control])
    )
}
