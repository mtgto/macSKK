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
    /// 入力元のアプリケーション情報
    struct TargetApplication {
        // Android StudioのAndroidエミュレータのようにbundle identifierをもたないGUIアプリケーションはnil
        let bundleIdentifier: String?
        // FIXME: NSRunningApplicationから取得するので、表示名が取れないときもあるかもしれない?
        let localizedName: String?
    }

    private let stateMachine = StateMachine()
    private var targetApp: TargetApplication! = nil
    private var cancellables: Set<AnyCancellable> = []
    private static let notFoundRange = NSRange(location: NSNotFound, length: NSNotFound)
    /// 変換候補として選択されている単語を流すストリーム
    private let selectedWord = PassthroughSubject<Word.Word?, Never>()
    /// 入力モードを表示するときに流すストリーム。
    private let displayInputModePanel = PassthroughSubject<InputMode, Never>()
    /// setValueで呼ばれたときに流すストリーム。非同期処理するために使用。
    private let inputModeChangedOutside = PassthroughSubject<InputMode, Never>().throttle(for: 0.1, scheduler: DispatchQueue.global(), latest: true)
    /// 入力を処理しないで直接入力させるかどうか
    private var directMode: Bool = false
    /// モード変更時に空白文字を一瞬追加するワークアラウンドを適用するかどうか
    private var insertBlankString: Bool = false
    /// 1文字目を常に未確定扱いするワークアラウンドを適用するかどうか
    private var treatFirstCharacterAsMarkedText: Bool = false

    @MainActor override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)

        guard let textInput = inputClient as? any IMKTextInput else {
            return
        }
        if let bundleIdentifier = textInput.bundleIdentifier() {
            targetApp = TargetApplication(bundleIdentifier: bundleIdentifier, localizedName: nil)
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
                if let localizedName = app.localizedName {
                    targetApp = TargetApplication(bundleIdentifier: bundleIdentifier, localizedName: localizedName)
                    break
                }
            }
        } else {
            logger.log("Bundle Identifierをもたないアプリケーションから接続されました")
            targetApp = TargetApplication(bundleIdentifier: nil, localizedName: nil)
        }

        stateMachine.inputMethodEvent.sink { [weak self] event in
            if let self {
                switch event {
                case .fixedText(let text):
                    if stateMachine.state.inputMode != .direct && textInput.bundleIdentifier() == "com.jetbrains.intellij" {
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
                case .modeChanged(let inputMode):
                    // KittyやAlacrittyなど、q/lによるモード切り替えでq/lが入力されたり、C-jで改行が入力されるのを回避するワークアラウンド
                    // AquaSKKの空文字列挿入を参考にしています。
                    // https://github.com/codefirst/aquaskk/blob/4.7.5/platform/mac/src/server/SKKInputController.mm#L405-L412
                    if self.stateMachine.state.specialState == nil && self.insertBlankString {
                        textInput.setMarkedText(String(format: "%c", 0x0c), selectionRange: Self.notFoundRange, replacementRange: Self.notFoundRange)
                        textInput.setMarkedText("", selectionRange: Self.notFoundRange, replacementRange: Self.notFoundRange)
                    }
                    if !self.directMode {
                        textInput.selectMode(inputMode.rawValue)
                        
                        let showInputModePanel = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showInputModePanel)
                        if showInputModePanel {
                            displayInputModePanel.send(inputMode)
                        }
                    }
                }
            }
        }.store(in: &cancellables)
        stateMachine.candidateEvent.sink { [weak self] candidates in
            if let self {
                let showAnnotation = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showAnnotation)
                Global.candidatesPanel.setShowAnnotationPopover(showAnnotation)
                if let candidates {
                    // 下線のスタイルがthickのときに被らないように1ピクセル下に余白を設ける
                    var cursorPosition = cursorPosition(for: textInput).offsetBy(dx: 0, dy: -1)
                    cursorPosition.size.height += 1
                    Global.candidatesPanel.setCursorPosition(cursorPosition)

                    if let page = candidates.page {
                        let currentCandidates: CurrentCandidates = .panel(words: page.words,
                                                                          currentPage: page.current,
                                                                          totalPageCount: page.total)
                        Global.candidatesPanel.setCandidates(currentCandidates, selected: candidates.selected)
                        Global.candidatesPanel.show(windowLevel: windowLevel(for: textInput))
                    } else {
                        if candidates.selected.annotations.isEmpty || !showAnnotation {
                            Global.candidatesPanel.orderOut(nil)
                        } else {
                            Global.candidatesPanel.show(windowLevel: windowLevel(for: textInput))
                        }
                        Global.candidatesPanel.setCandidates(.inline, selected: candidates.selected)
                    }
                } else {
                    // 変換→キャンセル→再変換しても注釈が表示されなくならないように状態を変えておく
                    self.selectedWord.send(nil)
                    Global.candidatesPanel.orderOut(nil)
                }
            }
        }.store(in: &cancellables)
        Global.candidatesPanel.viewModel.$selected.compactMap { $0 }.sink { [weak self] selected in
            self?.stateMachine.didSelectCandidate(selected)
            // TODO: バックグラウンドで引いて表示のときだけフォアグラウンドで処理をさせたい
            // TODO: 一度引いた単語を二度引かないようにしたい
            self?.selectedWord.send(selected.word)
        }.store(in: &cancellables)
        Global.candidatesPanel.viewModel.$doubleSelected.compactMap { $0 }.sink { [weak self] doubleSelected in
            self?.stateMachine.didDoubleSelectCandidate(doubleSelected)
        }.store(in: &cancellables)
        selectedWord.removeDuplicates().compactMap({ $0 }).sink { [weak self] word in
            if UserDefaults.standard.bool(forKey: UserDefaultsKeys.showAnnotation) {
                if let self, let systemAnnotation = SystemDict.lookup(word, for: Global.systemDict), !systemAnnotation.isEmpty {
                    Global.candidatesPanel.setSystemAnnotation(systemAnnotation, for: word)
                    Global.candidatesPanel.show(windowLevel: windowLevel(for: textInput))
                }
            }
        }.store(in: &cancellables)
        Global.directModeBundleIdentifiers.sink { [weak self] bundleIdentifiers in
            if let bundleIdentifier = self?.targetApp.bundleIdentifier {
                self?.directMode = bundleIdentifiers.contains(bundleIdentifier)
            }
        }.store(in: &cancellables)
        Global.insertBlankStringBundleIdentifiers.sink { [weak self] bundleIdentifiers in
            if let bundleIdentifier = self?.targetApp.bundleIdentifier {
                self?.insertBlankString = bundleIdentifiers.contains(bundleIdentifier)
            }
        }.store(in: &cancellables)
        Global.treatFirstCharacterAsMarkedTextBundleIdentifiers.sink { [weak self] bundleIdentifiers in
            if let self, let bundleIdentifier = self.targetApp.bundleIdentifier {
                let enabled = bundleIdentifiers.contains(bundleIdentifier)
                self.treatFirstCharacterAsMarkedText = enabled
                self.stateMachine.enableMarkedTextWorkaround = enabled
            }
        }.store(in: &cancellables)
        stateMachine.yomiEvent.sink { [weak self] yomi in
            if let self, Global.showCompletion {
                if let completion = Global.dictionary.findCompletion(prefix: yomi) {
                    self.stateMachine.completion = (yomi, completion)
                    Global.completionPanel.viewModel.completion = completion
                    let cursorPosition = cursorPosition(for: textInput)
                    if cursorPosition != .zero {
                        Global.completionPanel.show(at: cursorPosition, windowLevel: windowLevel(for: textInput))
                    }
                } else {
                    self.stateMachine.completion = nil
                    Global.completionPanel.orderOut(nil)
                }
            }
        }.store(in: &cancellables)
        // Safariでアドレスバーに移動するときなど、処理が固まることがあるので非同期で実行する
        // https://github.com/mtgto/macSKK/issues/336
        displayInputModePanel
            .merge(with: inputModeChangedOutside)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inputMode in
                if let self {
                    Global.inputModePanel.show(at: cursorPosition(for: textInput).origin,
                                               mode: inputMode,
                                               privateMode: Global.privateMode.value,
                                               windowLevel: windowLevel(for: textInput))
                }
            }.store(in: &cancellables)

        stateMachine.inlineCandidateCount = UserDefaults.standard.integer(forKey: UserDefaultsKeys.inlineCandidateCount)
        NotificationCenter.default.publisher(for: notificationNameInlineCandidateCount)
            .sink { [weak self] notification in
                if let inlineCandidateCount = notification.object as? Int, inlineCandidateCount >= 0 {
                    self?.stateMachine.inlineCandidateCount = inlineCandidateCount
                }
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: notificationNameCandidatesFontSize)
            .sink { notification in
                if let candidatesFontSize = notification.object as? Int {
                    Global.candidatesPanel.setCandidatesFontSize(candidatesFontSize)
                }
            }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: notificationNameAnnotationFontSize)
            .sink { notification in
                if let annotationFontSize = notification.object as? Int {
                    Global.candidatesPanel.setAnnotationFontSize(annotationFontSize)
                }
            }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: notificationNameFindCompletionFromAllDicts)
            .sink { notification in
                if let findCompletionFromAllDicts = notification.object as? Bool {
                    Global.findCompletionFromAllDicts.send(findCompletionFromAllDicts)
                }
            }.store(in: &cancellables)
    }

    @MainActor override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // 文字ビューアで入力した場合など、eventがnilの場合がありえる
        if event == nil {
            return false
        }
        let keyBind = Global.keyBinding.action(event: event, inputMethodState: stateMachine.state.inputMethod)
        if directMode {
            if let keyBind, keyBind == .kana || keyBind == .eisu {
                // 英数・かなキーは握り潰さないとエディタによって空白が入ってしまう
                return true
            }
            return false
        }
        // 左下座標基準でwidth=1, height=(通常だとフォントサイズ)のNSRect
        let textInput = sender as? any IMKTextInput
        if keyBind == nil && event.charactersIgnoringModifiers == nil {
            return stateMachine.handleUnhandledEvent(event)
        }

        return stateMachine.handle(Action(keyBind: keyBind, event: event, textInput: textInput))
    }

    @MainActor override func menu() -> NSMenu! {
        let preferenceMenu = NSMenu()
        preferenceMenu.addItem(
            withTitle: String(localized: "MenuItemPreference", comment: "Preferences…"),
            action: #selector(showSettings), keyEquivalent: "")
        if Global.dictionary.hasUnsavedChanges {
            preferenceMenu.addItem(
                withTitle: String(localized: "MenuItemSaveDict", comment: "Save User Dictionary"),
                action: #selector(saveDict), keyEquivalent: "")
        }
        let privateModeItem = NSMenuItem(title: String(localized: "MenuItemPrivateMode", comment: "Private mode"),
                                         action: #selector(togglePrivateMode),
                                         keyEquivalent: "")
        privateModeItem.state = Global.privateMode.value ? .on : .off
        preferenceMenu.addItem(privateModeItem)
        if targetApp.bundleIdentifier != nil {
            let directModeItem = NSMenuItem(title: String(format: String(localized: "MenuItemDirectInput", comment: "\"%@\"では直接入力"), targetApp.localizedName ?? "?"),
                                            action: #selector(toggleDirectMode),
                                            keyEquivalent: "")
            directModeItem.state = directMode ? .on : .off
            preferenceMenu.addItem(directModeItem)
            // NOTE: IMKInputControllerのmenuではsubmenuを指定してもOSに無視されるみたい
            let insertBlankStringMenuItem = NSMenuItem(title: String(localized: "MenuItemInsertBlankString", comment: "空文字挿入 (互換性)"), action: #selector(toggleInsertBlankString), keyEquivalent: "")
            insertBlankStringMenuItem.state = insertBlankString ? .on : .off
            preferenceMenu.addItem(insertBlankStringMenuItem)
            let treatFirstCharacterAsMarkedTextMenuItem = NSMenuItem(title: String(localized: "MenuItemTreadFirstCharacterAsMarkedText"), action: #selector(toggleTreatFirstCharacterAsMarkedText), keyEquivalent: "")
            treatFirstCharacterAsMarkedTextMenuItem.state = treatFirstCharacterAsMarkedText ? .on : .off
            preferenceMenu.addItem(treatFirstCharacterAsMarkedTextMenuItem)
        }
        #if DEBUG
        // デバッグ用
        preferenceMenu.addItem(
            withTitle: "Show Panel",
            action: #selector(showPanel), keyEquivalent: "")
        #endif
        return preferenceMenu
    }

    // MARK: - IMKStateSetting
    @MainActor override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
    }

    @MainActor override func deactivateServer(_ sender: Any!) {
        // 他の入力に切り替わるときには入力候補や補完候補は消す + 現在表示中の候補を確定させる
        Global.candidatesPanel.orderOut(sender)
        Global.completionPanel.orderOut(sender)
        super.deactivateServer(sender)
    }

    /// クライアントが入力中状態を即座に確定してほしいときに呼ばれる
    @MainActor override func commitComposition(_ sender: Any!) {
        // 現在未確定の入力を強制的に確定させて状態を入力前の状態にする
        stateMachine.commitComposition()
    }

    @MainActor override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        guard let value = value as? String else { return }
        guard let inputMode = InputMode(rawValue: value) else { return }
        logger.debug("入力モードが変更されました \(inputMode.rawValue)")
        stateMachine.setMode(inputMode)
        guard let textInput = sender as? any IMKTextInput else {
            logger.warning("setValueの引数clientがIMKTextInputではありません")
            return
        }
        
        let showInputModePanel = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showInputModePanel)
        if showInputModePanel && !directMode {
            // Safariでアドレスバーに移動するときなど、処理が固まることがあるので非同期で実行する
            // ただしIMKTextInputへのアクセスはsetValue内で同期で行う必要がある
            displayInputModePanel.send(inputMode)
        }
        // キー配列を設定する
        setCustomInputSource(textInput: textInput)
    }

    @objc func showSettings() {
        if #available(macOS 14, *) {
            NotificationCenter.default.post(name: notificationNameOpenSettings, object: nil)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    @objc func saveDict() {
        Global.dictionary.save()
    }

    @objc func togglePrivateMode() {
        Global.privateMode.send(!Global.privateMode.value)
    }

    /// 現在最前面にあるアプリからの入力をハンドルしないかどうかを切り替える
    @objc func toggleDirectMode() {
        if let bundleIdentifier = targetApp.bundleIdentifier {
            NotificationCenter.default.post(name: notificationNameToggleDirectMode, object: bundleIdentifier)
        }
    }

    /// 現在最前面にあるアプリで、ワークアラウンドの空文字挿入の有効無効を切り換える
    @objc func toggleInsertBlankString() {
        if let bundleIdentifier = targetApp.bundleIdentifier {
            NotificationCenter.default.post(name: notificationNameToggleInsertBlankString, object: bundleIdentifier)
        }
    }

    /// 現在最前面にあるアプリで、ワークアラウンドの1文字目を常に未確定扱いするかの有効無効を切り替える
    @objc func toggleTreatFirstCharacterAsMarkedText() {
        if let bundleIdentifier = targetApp.bundleIdentifier {
            NotificationCenter.default.post(name: notificationNameToggleTreatFirstCharacterAsMarkedText, object: bundleIdentifier)
        }
    }

    #if DEBUG
    @objc func showPanel() {
        let point = NSPoint(x: 100, y: 500)
        Global.inputModePanel.show(at: point, mode: .hiragana, privateMode: Global.privateMode.value, windowLevel: .floating)
    }
    #endif

    // MARK: -
    private func isPrintable(_ text: String) -> Bool {
        let printable = [CharacterSet.alphanumerics, CharacterSet.symbols, CharacterSet.punctuationCharacters]
            .reduce(CharacterSet()) { $0.union($1) }
        return !text.unicodeScalars.contains { !printable.contains($0) }
    }

    // キー配列を設定する
    private func setCustomInputSource(textInput: any IMKTextInput) {
        if let inputSourceID = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedInputSource) {
            logger.info("InputSourceIDを \(inputSourceID, privacy: .public) に設定します")
            textInput.overrideKeyboard(withKeyboardNamed: inputSourceID)
        } else {
            logger.info("InputSourceIDは選択されていません")
        }
    }

    /// 現在のカーソル位置。正常に取得できない場合はNSRect.zeroになっている。
    private func cursorPosition(for textInput: any IMKTextInput) -> NSRect {
        // TODO: 単語登録中など、現在のカーソル位置が0ではないときはそれに合わせて座標を取得したい
        // forCharacterIndexを0以外で取得しようとすると取得できないことがあるためひとまず断念
        var cursorPosition: NSRect = .zero
        _ = textInput.attributes(forCharacterIndex: 0, lineHeightRectangle: &cursorPosition)
        return cursorPosition
    }

    /// 変換候補パネルや補完候補などを表示するべきウィンドウレベル。
    private func windowLevel(for textInput: any IMKTextInput) -> NSWindow.Level {
        NSWindow.Level(rawValue: Int(textInput.windowLevel() + 1))
    }
}
