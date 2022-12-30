// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
    private let stateMachine = StateMachine()
    private let candidates: IMKCandidates
    private let preferenceMenu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []
    private static let notFoundRange = NSRange(location: NSNotFound, length: NSNotFound)

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        candidates = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)

        preferenceMenu.addItem(
            withTitle: NSLocalizedString("PreferenceMenuItem", comment: "Preferences…"), action: nil, keyEquivalent: "")

        guard let textInput = inputClient as? IMKTextInput else {
            return
        }

        stateMachine.inputMethodEvent.sink { event in
            switch event {
            case .fixedText(let text):
                textInput.insertText(text, replacementRange: Self.notFoundRange)
            case .markedText(let text):
                textInput.setMarkedText(text, selectionRange: Self.notFoundRange, replacementRange: Self.notFoundRange)
            case .modeChanged(let inputMode):
                textInput.selectMode(inputMode.rawValue)
            }
        }.store(in: &cancellables)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        let modifiers = event.modifierFlags
        // Ctrl-J, Ctrl-Gなどは受け取るが、基本的にはCtrl, Command, Fnが押されていたら無視する
        if modifiers.contains(.control) || modifiers.contains(.command) || modifiers.contains(.function) {
            if modifiers == [.control] {
                if event.charactersIgnoringModifiers == "j" {
                    return stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: event))
                } else if event.charactersIgnoringModifiers == "g" {
                    return stateMachine.handle(Action(keyEvent: .cancel, originalEvent: event))
                }
            }
            return false
        }

        guard let keyEvent = convert(event: event) else {
            logger.log("Can not convert event to KeyEvent")
            return false
        }

        return stateMachine.handle(Action(keyEvent: keyEvent, originalEvent: event))
    }

    override func menu() -> NSMenu! {
        return preferenceMenu
    }

    // MARK: -
    private func isPrintable(_ text: String) -> Bool {
        let printable = [CharacterSet.alphanumerics, CharacterSet.symbols, CharacterSet.punctuationCharacters]
            .reduce(CharacterSet()) { $0.union($1) }
        return !text.unicodeScalars.contains { !printable.contains($0) }
    }

    private func convert(event: NSEvent) -> Action.KeyEvent? {
        if event.keyCode == 36 {  // エンター
            return .enter
        } else if event.keyCode == 51 {
            return .backspace
        } else if event.characters == " " {
            return .space
        } else if event.characters == ";" {
            return .stickyShift
        } else if let text = event.charactersIgnoringModifiers {
            if isPrintable(text) {
                return .printable(text)
            }
        }
        return nil
    }
}
