// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import InputMethodKit

// AppleのAPIドキュメントにはメインスレッドであるとは書かれてないけど、まあ大丈夫じゃないかな、と雑にMainActorを設定している。
// 問題があるようだったらDispatchQueue.main.(a)syncを使うように修正すること。
@MainActor
@objc(InputController)
class InputController: IMKInputController {
    private let stateMachine = StateMachine()
    private var cancellables: Set<AnyCancellable> = []
    private static let notFoundRange = NSRange(location: NSNotFound, length: NSNotFound)
    private let inputModePanel: InputModePanel
    private let candidatesPanel: CandidatesPanel
    private let selectedWord = PassthroughSubject<Word, Never>()

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        inputModePanel = InputModePanel()
        candidatesPanel = CandidatesPanel()
        super.init(server: server, delegate: delegate, client: inputClient)

        guard let textInput = inputClient as? IMKTextInput else {
            return
        }

        stateMachine.inputMethodEvent.sink { [weak self] event in
            switch event {
            case .fixedText(let text):
                if textInput.bundleIdentifier() == "com.jetbrains.intellij" {
                    // AquaSKKと同様に、非確定文字列に確定予定文字列を先に表示する
                    textInput.setMarkedText(
                        text,
                        selectionRange: NSRange(location: text.count, length: 0),
                        replacementRange: Self.notFoundRange)
                }
                textInput.insertText(text, replacementRange: Self.notFoundRange)
            case .markedText(let markedText):
                let attributedText = markedText.attributedString
                let cursorRange: NSRange = markedText.cursorRange() ?? Self.notFoundRange
                // Thingsのメモ欄などで最初の一文字をShift押しながら入力すると "▽あ" が直接入力されてしまうことがあるのを回避するワークグラウンド
                if case .markerCompose = markedText.elements.first, markedText.elements.count == 2,
                   case let .plain(text) = markedText.elements[1], text.count == 1 {
                    textInput.setMarkedText(NSAttributedString(MarkedText.Element.markerCompose.attributedString),
                                            selectionRange: cursorRange,
                                            replacementRange: Self.notFoundRange)
                }
                textInput.setMarkedText(NSAttributedString(attributedText), selectionRange: cursorRange, replacementRange: Self.notFoundRange)
            case .modeChanged(let inputMode, let cursorPosition):
                textInput.selectMode(inputMode.rawValue)
                if let self {
                    self.inputModePanel.show(at: cursorPosition.origin,
                                             mode: inputMode,
                                             privateMode: privateMode.value)
                }
            }
        }.store(in: &cancellables)
        stateMachine.candidateEvent.sink { [weak self] candidates in
            if let candidates {
                // 下線のスタイルがthickのときに被らないように1ピクセル下に余白を設ける
                var cursorPosition = candidates.cursorPosition.offsetBy(dx: 0, dy: -1)
                cursorPosition.size.height += 1
                self?.candidatesPanel.setCursorPosition(cursorPosition)

                switch candidates {
                case let .inline(selected, _):
                    self?.candidatesPanel.setCandidates(.inline, selected: selected)
                    self?.selectedWord.send(selected)
                    if selected.annotation != nil {
                        self?.candidatesPanel.setCandidates(.inline, selected: selected)
                        self?.candidatesPanel.show()
                    }
                case let .panel(words, currentPage, totalPageCount, selected, _):
                    let currentCandidates: CurrentCandidates = .panel(words: words,
                                                                      currentPage: currentPage,
                                                                      totalPageCount: totalPageCount)
                    self?.candidatesPanel.setCandidates(currentCandidates, selected: selected)
                    self?.selectedWord.send(selected)
                    self?.candidatesPanel.show()
                }
            } else {
                self?.candidatesPanel.orderOut(nil)
            }
        }.store(in: &cancellables)
        candidatesPanel.viewModel.$selected.compactMap { $0 }.sink { [weak self] (selected: Word) in
            self?.stateMachine.didSelectCandidate(selected)
            // TODO: バックグラウンドで引いて表示のときだけフォアグラウンドで処理をさせたい
            // TODO: 一度引いた単語を二度引かないようにしたい
            self?.selectedWord.send(selected)
        }.store(in: &cancellables)
        candidatesPanel.viewModel.$doubleSelected.compactMap { $0 }.sink { [weak self] doubleSelected in
            self?.stateMachine.didDoubleSelectCandidate(doubleSelected)
        }.store(in: &cancellables)
        selectedWord.removeDuplicates().sink { [weak self] word in
            if let systemAnnotation = SystemDict.lookup(word.word), !systemAnnotation.isEmpty {
                self?.candidatesPanel.setSystemAnnotation(systemAnnotation, for: word)
                self?.candidatesPanel.show()
            }
        }.store(in: &cancellables)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // 左下座標基準でwidth=1, height=(通常だとフォントサイズ)のNSRect
        var cursorPosition: NSRect = .zero
        if let textInput = sender as? IMKTextInput {
            // カーソル位置あたりを取得する
            _ = textInput.attributes(forCharacterIndex: 0, lineHeightRectangle: &cursorPosition)
            // TODO: 単語登録中など、現在のカーソル位置が0ではないときはそれに合わせて座標を取得したい
        } else {
            logger.log("IMKTextInputが取得できません")
        }
        guard let keyEvent = convert(event: event) else {
            logger.debug("Can not convert event to KeyEvent")
            return stateMachine.handleUnhandledEvent(event)
        }

        return stateMachine.handle(Action(keyEvent: keyEvent, originalEvent: event, cursorPosition: cursorPosition))
    }

    override func menu() -> NSMenu! {
        let preferenceMenu = NSMenu()
        preferenceMenu.addItem(
            withTitle: NSLocalizedString("MenuItemPreference", comment: "Preferences…"),
            action: #selector(showSettings), keyEquivalent: "")
        preferenceMenu.addItem(
            withTitle: NSLocalizedString("MenuItemSaveDict", comment: "Save User Dictionary"),
            action: #selector(saveDict), keyEquivalent: "")
        let privateModeItem = NSMenuItem(title: NSLocalizedString("MenuPrivateMode", comment: "Private mode"),
                                         action: #selector(togglePrivateMode),
                                         keyEquivalent: "")
        privateModeItem.state = privateMode.value ? .on : .off
        preferenceMenu.addItem(privateModeItem)
        #if DEBUG
        // デバッグ用
        preferenceMenu.addItem(
            withTitle: "Show Panel",
            action: #selector(showPanel), keyEquivalent: "")
        #endif
        return preferenceMenu
    }

    // MARK: - IMKStateSetting
    override func deactivateServer(_ sender: Any!) {
        // 他の入力に切り替わるときには入力候補は消す + 現在表示中の候補を確定させる
        candidatesPanel.orderOut(sender)
        super.deactivateServer(sender)
    }

    /// クライアントが入力中状態を即座に確定してほしいときに呼ばれる
    override func commitComposition(_ sender: Any!) {
        // 現在未確定の入力を強制的に確定させて状態を入力前の状態にする
        stateMachine.commitComposition()
    }

    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        guard let value = value as? String else { return }
        guard let inputMode = InputMode(rawValue: value) else { return }
        logger.debug("入力モードが変更されました \(inputMode.rawValue)")
        stateMachine.setMode(inputMode)
        guard let textInput = sender as? IMKTextInput else {
            logger.warning("setValueの引数clientがIMKTextInputではありません")
            return
        }
        // カーソル位置あたりを取得する
        var cursorPosition: NSRect = .zero
        _ = textInput.attributes(forCharacterIndex: 0, lineHeightRectangle: &cursorPosition)
        inputModePanel.show(at: cursorPosition.origin, mode: inputMode, privateMode: privateMode.value)
    }

    @objc func showSettings() {
        if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func saveDict() {
        do {
            try dictionary.save()
        } catch {
            // TODO: NotificationCenterでユーザーに通知する
            logger.error("ユーザー辞書保存中にエラーが発生しました")
        }
    }

    @objc func togglePrivateMode() {
        privateMode.send(!privateMode.value)
    }

    #if DEBUG
    @objc func showPanel() {
        let point = NSPoint(x: 100, y: 500)
        self.inputModePanel.show(at: point, mode: .hiragana, privateMode: privateMode.value)
    }
    #endif

    // MARK: -
    private func isPrintable(_ text: String) -> Bool {
        let printable = [CharacterSet.alphanumerics, CharacterSet.symbols, CharacterSet.punctuationCharacters]
            .reduce(CharacterSet()) { $0.union($1) }
        return !text.unicodeScalars.contains { !printable.contains($0) }
    }

    private func convert(event: NSEvent) -> Action.KeyEvent? {
        // Ctrl-J, Ctrl-Gなどは受け取るが、基本的にはCtrl, Command, Fnが押されていたら無視する
        // Optionは修飾キーを打つかもしれないので許容する
        let modifiers = event.modifierFlags
        let keyCode = event.keyCode
        let charactersIgnoringModifiers = event.charactersIgnoringModifiers
        if modifiers.contains(.control) || modifiers.contains(.command) || modifiers.contains(.function) {
            if modifiers == [.control] {
                switch charactersIgnoringModifiers {
                case "j":
                    return .ctrlJ
                case "g":
                    return .cancel
                case "h":
                    return .backspace
                case "b":
                    return .left
                case "f":
                    return .right
                case "p":
                    return .up
                case "n":
                    return .down
                case "a":
                    return .ctrlA
                case "e":
                    return .ctrlE
                case "y":
                    return .ctrlY
                default:
                    break
                }
            }
            // カーソルキーはFn + NumPadがmodifierFlagsに設定されている
            if !modifiers.contains(.control) && !modifiers.contains(.command) && modifiers.contains(.function) {
                if keyCode == 123 {
                    return .left
                } else if keyCode == 124 {
                    return .right
                } else if keyCode == 125 {
                    return .down
                } else if keyCode == 126 {
                    return .up
                }
            }

            return nil
        }

        if keyCode == 36 {  // エンター
            return .enter
        } else if keyCode == 123 {
            return .left
        } else if keyCode == 124 {
            return .right
        } else if keyCode == 126 {
            return .up
        } else if keyCode == 125 {
            return .down
        } else if keyCode == 51 {
            return .backspace
        } else if keyCode == 53 {  // ESC
            return .cancel
        } else if event.characters == " " {
            return .space
        } else if event.characters == ";" {
            return .stickyShift
        } else if let text = charactersIgnoringModifiers {
            if isPrintable(text) {
                return .printable(text)
            }
        }
        return nil
    }
}
