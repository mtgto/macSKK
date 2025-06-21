// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Carbon.HIToolbox.Events

extension Character {
    var keyCode: UInt16? {
        switch self {
        case "a":
            return UInt16(kVK_ANSI_A)
        case "b":
            return UInt16(kVK_ANSI_B)
        case "c":
            return UInt16(kVK_ANSI_C)
        case "d":
            return UInt16(kVK_ANSI_D)
        case "e":
            return UInt16(kVK_ANSI_E)
        case "f":
            return UInt16(kVK_ANSI_F)
        case "g":
            return UInt16(kVK_ANSI_G)
        case "h":
            return UInt16(kVK_ANSI_H)
        case "i":
            return UInt16(kVK_ANSI_I)
        case "j":
            return UInt16(kVK_ANSI_J)
        case "k":
            return UInt16(kVK_ANSI_K)
        case "l":
            return UInt16(kVK_ANSI_L)
        case "m":
            return UInt16(kVK_ANSI_M)
        case "n":
            return UInt16(kVK_ANSI_N)
        case "o":
            return UInt16(kVK_ANSI_O)
        case "p":
            return UInt16(kVK_ANSI_P)
        case "q":
            return UInt16(kVK_ANSI_Q)
        case "r":
            return UInt16(kVK_ANSI_R)
        case "s":
            return UInt16(kVK_ANSI_S)
        case "t":
            return UInt16(kVK_ANSI_T)
        case "u":
            return UInt16(kVK_ANSI_U)
        case "v":
            return UInt16(kVK_ANSI_V)
        case "w":
            return UInt16(kVK_ANSI_W)
        case "x":
            return UInt16(kVK_ANSI_X)
        case "y":
            return UInt16(kVK_ANSI_Y)
        case "z":
            return UInt16(kVK_ANSI_Z)
        case ";":
            return UInt16(kVK_ANSI_Semicolon)
        case "/":
            return UInt16(kVK_ANSI_Slash)
        case " ":
            return UInt16(kVK_Space)
        case "\u{127}":
            return UInt16(kVK_Delete)
        default:
            return nil
        }
    }
}
