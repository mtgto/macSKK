// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// あるキーバインドを変更するビュー。
struct KeyBindingInputsView: View {
    @Binding var action: KeyBinding.Action
    @Binding var inputs: [KeyBinding.Input]
    @State var selectedInput: KeyBinding.Input?
    @State var control: Bool = false
    @State var option: Bool = false
    @State var shift: Bool = false
    @State var function: Bool = false

    var body: some View {
        Form {
            Section(action.localizedAction) {
                List(inputs, selection: $selectedInput) { input in
                    // TextFieldにして編集中のキー入力を受け取れるようにする?
                    Text(input.displayString).tag(input)
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
            .onChange(of: selectedInput) { selectedInput in
                if let selectedInput {
                    control = selectedInput.optionalModifierFlags.contains(.control)
                    option = selectedInput.optionalModifierFlags.contains(.option)
                    shift = selectedInput.optionalModifierFlags.contains(.shift)
                    function = selectedInput.optionalModifierFlags.contains(.shift)
                } else {
                    control = false
                    option = false
                    shift = false
                    function = false
                }
            }
            if let selectedInput {
                Section("修飾キー (必須)") {
                    HStack {
                        Toggle(isOn: .constant(selectedInput.modifierFlags.contains(.control))) {
                            Text("Control")
                        }
                        .disabled(true)
                        Toggle(isOn: .constant(selectedInput.modifierFlags.contains(.option))) {
                            Text("Option")
                        }
                        .disabled(true)
                        Toggle(isOn: .constant(selectedInput.modifierFlags.contains(.shift))) {
                            Text("Shift")
                        }
                        .disabled(true)
                        Toggle(isOn: .constant(selectedInput.modifierFlags.contains(.function))) {
                            Text("Function")
                        }
                        .disabled(true)
                    }
                }
                Section("修飾キー (任意)") {
                    HStack {
                        Toggle(isOn: $control) {
                            Text("Control")
                        }
                        Toggle(isOn: $option) {
                            Text("Option")
                        }
                        Toggle(isOn: $shift) {
                            Text("Shift")
                        }
                        Toggle(isOn: $function) {
                            Text("Function")
                        }
                    }
                    .onChange(of: [control, option, shift, function]) { modifierFlags in
                        if let index = inputs.firstIndex(of: selectedInput) {
                            var flags: NSEvent.ModifierFlags = []
                            if modifierFlags[0] {
                                flags = flags.union(.control)
                            }
                            if modifierFlags[1] {
                                flags = flags.union(.option)
                            }
                            if modifierFlags[2] {
                                flags = flags.union(.shift)
                            }
                            if modifierFlags[3] {
                                flags = flags.union(.function)
                            }
                            inputs[index] = selectedInput.with(optionalModifierFlags: flags)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.checkbox)
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) {

            }
            Button {

            } label: {
                Text("Done")
                    .padding([.leading, .trailing])
            }
            .keyboardShortcut(.defaultAction)
            .padding([.trailing, .bottom, .top])
        }
    }
}

#Preview {
    KeyBindingInputsView(action: .constant(.toggleKana),
                         inputs: .constant([
                            KeyBinding.Input(key: .character("q"), displayString: "Q", modifierFlags: []),
                            KeyBinding.Input(key: .character("l"), displayString: "L", modifierFlags: []),
                         ]),
                         selectedInput: KeyBinding.Input(key: .character("q"), displayString: "Q", modifierFlags: [])
    )
}
