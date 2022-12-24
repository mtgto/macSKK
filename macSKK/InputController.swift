// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
    private let stateMachine = StateMachine()

    override init() {
        super.init()
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        return stateMachine.handle(.userInput(.cancel))
    }
}
