// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
    private let stateMachine = StateMachine()
    private let candidates: IMKCandidates
    private let preferenceMenu = NSMenu()

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        candidates = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)

        preferenceMenu.addItem(withTitle: NSLocalizedString("PreferenceMenuItem", comment: "Preferences…"), action: nil, keyEquivalent: "")

        guard let textInput = inputClient as? IMKTextInput else {
            return
        }
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        return stateMachine.handle(.userInput(.cancel))
    }
    
    override func menu() -> NSMenu! {
        return preferenceMenu
    }
}
