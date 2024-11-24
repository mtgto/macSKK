macSKK [![test](https://github.com/mtgto/macSKK/actions/workflows/test.yml/badge.svg)](https://github.com/mtgto/macSKK/actions/workflows/test.yml)
====
macSKKはmacOS用の[SKK](https://ja.wikipedia.org/wiki/SKK)方式の日本語入力システム (インプットメソッド) です。

macOS用のSKK方式の日本語入力システムにはすでに[AquaSKK](https://github.com/codefirst/aquaskk/)がありますが、いくつか独自の機能を作りたいと思い新たに開発しています。

macSKKを使用するには macOS 13.3 (Ventura) 以降が必要です。
Universal Binary (Apple Silicon & Intel Mac) でビルドしていますが、動作確認はApple Silicon環境でのみ行っています。

## 特徴

- 日本語入力システムはパスワードなどの機密情報を処理する可能性があるため安全性が求められるプログラムです。そのためmacSKKはmacOSのSandbox機構を使いネットワーク通信やファイルの読み書きに制限をかけることでセキュリティホールを攻撃されたときの被害を減らすように心掛けます。
- 不正なコードが含まれるリスクを避けるため、サードパーティによる外部ライブラリは使用していません。
- すべてをSwiftだけでコーディングしており、イベント処理にCombineを、UI部分にはSwiftUIを使用しています。
- 単語登録モードや送り仮名入力中などキー入力による状態変化管理が複雑なのでユニットテストを書いてエンバグのリスクを減らす努力をしています。

## 実装予定

しばらくはAquaSKKにはあるけどmacSKKにない機能を実装しつつ、徐々に独自機能を実装していこうと考えています。

- [x] 複数辞書を使用できるようにする
- [x] [マイ辞書に保存しないプライベートモード](#プライベートモード)
- [x] [アプリごとに直接入力させるかどうかを設定できるようにする](#直接入力)
  - ddskkを使っているときのGUI版Emacs.appなど
- [x] [過去の入力を使った入力補完](#読みの補完)
- [x] [数値変換](#数値変換)
- [x] 送りありエントリのブロック形式
- [x] [キー配列の設定 (Dvorakなど)](#キー配列の変更)
- [x] [ローマ字変換ルールの設定](#ローマ字変換ルールの変更)
- [x] [SKKServを辞書として使う](#SKKServを辞書として使う)
- [x] [キーバインドの変更](#キーバインドの変更)
- [ ] Java AWT製アプリケーションで入力ができない問題のワークアラウンド対応 (JetBrain製品など)

### 実装予定の独自機能

- [x] [自動更新確認](#バージョンの自動チェック)
  - Network Outgoingが可能なXPCプロセスを作成し、GitHub Releasesから情報を定期的に取得して新しいバージョンが見つかったらNotification Centerに表示する
- [x] 辞書のJSON形式への対応
- [ ] iCloudにマイ辞書を保存して他環境と共有できるようにする
- [ ] マイ辞書の暗号化
  - 編集したい場合は生データでのエクスポート & インポートできるようにする

## インストール

2023年現在、Mac App Storeでは日本語入力システムを配布することができないため、[Appleのソフトウェア公証](https://support.apple.com/ja-jp/guide/security/sec3ad8e6e53/1/web/1)を受けたアプリケーションバイナリを[GitHub Releases](https://github.com/mtgto/macSKK/releases/latest)で配布しています。dmgファイルをダウンロードしマウントした中にあるpkgファイルからインストールしてください。

もしHomebrew Caskでインストールしたい場合は、 `brew install --cask mtgto/macskk/macskk` でもインストールできます。
詳しくは https://github.com/mtgto/homebrew-macSKK を参照してください。

macSKKのインストール後に、システム設定→キーボード→入力ソースから「ひらがな」(アイコンは`▼あ`)と「ABC」(アイコンは`▼A`)を追加してください。カタカナ、全角英数、半角カナは追加しても追加しなくても問題ありません。
もしインストール直後に表示されなかったり、バージョンアップしても反映されない場合はログアウト & ログインを試してみてください。

SKK辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries` に配置してください。
その後、入力メニュー→環境設定を開き、辞書設定で使用する辞書を有効に切り替えてください。EUC-JPでないエンコーディングの場合はiボタンからエンコーディングを切り替えてください。現在はEUC-JP (EUC-JIS-2004を含む) とUTF-8に対応しています。辞書ファイルの形式はYAML形式、JSON形式なども提案されていますが現在は未対応です。

辞書の削除は上記フォルダから辞書ファイルをゴミ箱に移動するかファイルを削除してください。macSKKが自動で無効化します。

ユーザー辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/skk-jisyo.utf8` にUTF-8形式で保存されます。
ユーザー辞書はテキストエディタで更新可能です。別プロセスでユーザー辞書が更新された場合はmacSKKが自動で再読み込みを行います。

## 設定

macSKKが入力メソッドとして選択されているときに入力メニューから「設定…」でGUIの設定画面を開くことができます。またプライベートモードのように入力メニューから直接有効・無効を切り替えるものがあります。

設定は Plist 形式で `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Library/Preferences/net.mtgto.inputmethod.macSKK.plist` に保存されます。

| キー                        | 値の型  | 設定の意味                              |
| :-------------------------: | :-----: | :-------------------------------------: |
| dictionaries                | Array   | 辞書設定                                |
| directModeBundleIdentifiers | Array   | 直接入力モードにしているアプリケーションのBundle Identifierの配列 |
| selectedInputSource         | String  | キー配列 (KeyLayout) のID               |
| showAnnotation              | Boolean | 注釈を変換候補のそばに表示するか        |
| inlineCandidateCount        | Number  | インラインで表示する変換候補の数        |
| workarounds                 | Array      | 互換性設定がされているアプリケーション  |
| candidatesFontSize          | Number     | 変換候補のフォントサイズ (デフォルト13) |
| annotationFontSize          | Number     | 注釈のフォントサイズ (デフォルト13)     |
| skkserv                     | Dictionary | skkservサーバーへの接続設定             |
| selectCandidateKeys         | String     | 変換候補から確定するキー配列            |
| findCompletionFromAllDicts  | Boolean    | ユーザー辞書だけでなくすべての辞書から補完を探すか |
| selectedKeyBindingSetId     | String     | 選択しているキーバインドのセットのID    |
| keyBindingSets              | Array      | キーバインドのセットの配列              |
| enterNewLine                | Boolean    | Enterキーで変換候補の確定 + 改行も行う  |
| systemDict                  | String     | 注釈に使用するシステム辞書              |
| selectingBackspace          | Number     | 変換候補選択時のバックスペースの挙動    |
| punctuation                 | Number     | カンマとピリオド押下時の句読点設定      |

## 機能

### 単語登録

有効な辞書で有効な読みが見つからない場合、単語登録モードに移行します。

例として "あああ" で変換しようとしても辞書になかった場合 `[登録：あああ]` のようなテキストが表示されます。

この状態でテキストを入力しEnterすることでユーザー辞書にその読みで登録されます。漢字変換も可能ですが単語登録モードで変換候補がない変換が行われた場合は入力されなかったと扱い、入れ子で単語登録モードには入れなくなっています。

単語登録モードでのみ `C-y` でクリップボードからペーストできます (AquaSKKと同様です)。通常のペーストコマンド `Cmd-v` はアクティブなアプリケーションに取られて利用できないため、特殊なキーバインドにしています。

単語登録をしない場合はEscキーや `C-g` でキャンセルしてください。

### ユーザー辞書から単語の削除

変換候補が選択されている状態で `Shift-x` を入力すると `(よみ) /(変換結果)/ を削除します(yes/no)` という表示に切り替わります。この状態でyesと入力してenterするとユーザー辞書から選択していた変換候補を削除します。noを選んだり Escキーや `C-g` でキャンセルした場合には何も行いません。

現状は選択されている変換候補がユーザー辞書にない場合は `削除します(yes/no)` という表示を行いますが、実際には何も行いません(ユーザー辞書以外を書き換えたくないため)。将来は他辞書からの削除ができるような対応をするかもしれませんが現在は未定です。

### 読みの補完

入力中、ユーザー辞書にある送りなし変換エントリから先頭が一致する変換履歴がある場合、入力テキストの下部に候補を表示します。タブキーを押すことで表示されているところまで入力が補完されます。

現在、補完の対象となるのはユーザー辞書の送りなしエントリだけです。

### 数値変換

辞書に "だい# /第#0/第#1/" のように、読みに"#"、変換候補に "#(数字)" を含むエントリは数値変換エントリです。

macSKKではタイプ0, 1, 2, 3, 8, 9に対応しています。
数値として使えるのは0以上2^63-1 (Int64.max) までです。

ユーザー辞書に追加される変換結果は "だい# /第#0/" のように実際の入力に使用した数値は含まない形式で追加されます。

### キー配列の変更

デフォルトではQWERTY配列になっていますが、設定画面からキー配列を変更できます。

システムで有効なキー配列のうち、英語用のキー配列のみを選択リストに表示しています。

### キーバインドの変更

qやlやCtrl-jなど、SKKで使用されるキーバインドを変更できます。
変更するには、設定画面のキーバインドからデフォルトのキーバインドのセットを複製してから修正してください。

もしおかしな挙動だったり、設定にはないような特殊なキーバインドを希望したい場合はIssueでお知らせください。

### ローマ字変換ルールの変更

どのキーを入力したときにどのような文字に変換するかをカスタマイズすることができます。
例えばローマ字入力表のカスタマイズもできますが、それ以外でも句読点としてカンマやピリオドを入力するように設定したり、全角で入力したい記号を設定することができます。

`~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Settings/kana-rule.conf` にファイルを置くことで、ローマ字テーブルの変更や記号入力をカスタマイズすることができます。

上記のパスにファイルがない場合、もしくは正常に読み込めなかった場合は `~/Library/Input Methods/macSKK.app/Contents/Resources/kana-rule.conf` がデフォルトで使用されます。
カスタマイズしたい際はmacSKK.app内にある `kana-rule.conf` ファイルもしくは https://github.com/mtgto/macSKK/blob/main/macSKK/kana-rule.conf を元にカスタマイズするのがよいでしょう。
設定ファイルの変更を監視しているため更新されたら即座に反映されます。

ローマ字変換ルール設定ファイルはUTF-8 + LF (BOMなし) で作成してください。
簡単な使い方はデフォルトファイルにもあるので参照してみてください。

ファイルを配置したのに反映されない場合はConsole.appでエラーが出てないか確認してみてください。
`ローマ字変換定義ファイルの XX 行目の記述が壊れているため読み込みできません` のようなログが出ているかもしれません。
正常に読み込めている場合は `独自のローマ字かな変換ルールを適用しました` というログが出力されます。

現在制限として、カタカナや半角カナモードでの文字をひらがなモードでの文字と異なる文字を使用する場合、未確定入力中はカタカナでも半角カナでもひらがなのルールが使用されてします。

例えば `a,あ,か,ｻ` という設定がある状態で `a` を入力した場合はこうなります。

| モード | 頭に▽がある | 結果 | 問題ある? |
| :-: | :-: | :-: | :-: |
| ひらがな | YES | ▽あ | なし |
| ひらがな | NO | あ | なし
| カタカナ | YES | ▽ア | あり |
| カタカナ | NO | カ | なし |
| 半角カナ | YES | ▽ｱ | あり |
| 半角カナ | NO | ｻ | なし |

### プライベートモード

プライベートモードが有効なときは変換結果がユーザー辞書に反映されません。ユーザー辞書以外の辞書やプライベートモードを有効にする前のユーザー辞書の変換候補は参照されます。

プライベートモードの有効・無効は入力メニュー→プライベートモードから切り替えできます。

### 直接入力

直接入力を有効にしたアプリケーションでは、日本語変換処理を行いません。独自でIME機能を持つEmacs.appなどで使用することを想定しています。

直接入力の有効・無効の切り替えは、切り替えたいアプリケーションが最前面のときに入力メニュー→"(アプリ名)で直接入力"から行えます。
また有効になっているアプリケーションのリストは設定→直接入力から確認できます。

直接入力を有効にしたアプリケーションはBundle Identifier単位で記録しているため、アプリケーションを移動させても設定は無効になりません。また特殊なGUIアプリケーションはBundle Identifierをもたないため直接入力を設定できません (Android StudioのAndroidエミュレータとか)。

### ユーザー辞書の自動保存

ユーザー辞書が更新された場合、一定期間おきにファイル書き出しが行われます。またシステム再起動時やバージョンアップのインストール実行後などmacSKKプロセスが正常終了する際にファイル書き出しが終わっていない更新がある場合はファイル書き出しを行ってから終了します。
もし即座にファイル書き出ししたい場合は入力メニューから"ユーザー辞書を今すぐ保存"を選んでください。

Command + Option + Escからの強制終了時やシグナルを送っての終了時は保存されないので注意してください。

### バージョンの自動チェック

macSKKは現在開発中のアプリケーションです。そのため安定していない可能性が高いです。
なるべく不具合が修正された最新バージョンを使っていただきたいため、定期的に新しいバージョンがないかをチェックして見つかった場合は通知センターで通知します。

新規バージョンの確認はGitHubのReleasesページのAtom情報を取得して行います。
バージョンチェックは12時間おきにバックグラウンドで実行されます。

macSKKアプリ自体はApp Sandboxでインターネット通信ができないように設定しているため、GitHubのReleaseページの取得はmacSKKからXPCを介して外部プロセスで行います。

### SKKServを辞書として使う

skkservサーバーをSKK辞書として使用することができます (macSKKがskkservサーバーとして機能するわけではないです)。
まだ作り込みが甘いのでベータ機能だと思ってください。

設定の辞書メニューからSKKServを有効にすることで使用できます。

- アドレスはIPv4, IPv6, ホスト名のいずれかを指定してください。
- ポート番号は通常は1178が使われるようです
- 応答エンコーディングは通常はEUC-JPが使われることが多いようですがskkservの実装によってはUTF-8を返すものもあるようです。
- SKKServ設定画面のテストボタンは設定中のskkservにバージョン取得コマンドを試します。正常な応答があれば「skkservへの接続に成功しました」と表示されます。

現状は以下の制限があります。

- 同時に1サーバーまで接続可能です。
- TCP接続が切断されたり1秒以内に送信できなかったり1秒以内に応答がなかった場合は取得できなかったものとして扱います。
- 常にファイル辞書よりも変換候補は後に出るようにしています。
  - 並び替えのUIで迷ったために先送り。将来並び替えできるようにすると思います。

動作確認はyaskkserv2でのみ行っています。

## アンインストール

現在アンインストールする手順は用意していないためお手数ですが手動でお願いします。
今後、dmg内にアンインストーラを同梱予定です。

手動で行うには、システム設定→キーボード→入力ソースから「ひらがな」「ABC」を削除後、以下のファイルを削除してください。

- `~/Library/Input Methods/macSKK.app`
- `~/Library/Containers/net.mtgto.inputmethod.macSKK`

## FAQ

### Q. Visual Studio Code (vscode) で `C-j` を押すと行末が削除されてしまいます

A. `C-j` がVisual Studio Codeのキーボードショートカット設定の `editor.action.joinLines` にデフォルトでは割り当てられていると思われます。`Cmd-K Cmd-S` から `editor.action.joinLines` で検索し、キーバインドを削除するなり変更するなりしてみてください。

### Q. Wezterm で `C-j` を押すと改行されてしまいます

A. [macos_forward_to_ime_modifier_mask](https://wezfurlong.org/wezterm/config/lua/config/macos_forward_to_ime_modifier_mask.html) に `CTRL` を追加することでIMEに `C-j` が渡されてひらがなモードに切り替えできるようになります。 `SHIFT` も入れておかないと漢字変換開始できなくなるので、 `SHIFT|CTRL` を設定するのがよいと思います。

### Q. 標準Terminal / iTerm2で `C-j` を押すと改行されてしまいます

A. Karabiner-Elementsで `C-j` をかなキーに置換することで対応することができます。作者は以下のようなComplex Modificationsを `~/.config/karabiner/assets/complex_modifications/macskk.json` に配置しています。将来 https://github.com/pqrs-org/KE-complex_modifications に配置して簡単にインストールできるようにしようと思っています。

```json
{
    "description": "macSKK for Terminal/iTerm2",
    "manipulators": [
        {
            "conditions": [
                {
                    "bundle_identifiers": [
                        "^com\\.googlecode\\.iterm2",
                        "^com\\.apple\\.Terminal"
                    ],
                    "type": "frontmost_application_if"
                },
                {
                    "input_sources": [
                        {
                            "input_source_id": "^net\\.mtgto\\.inputmethod\\.macSKK\\.(ascii|hiragana|katakana|hankaku|eisu)$"
                        }
                    ],
                    "type": "input_source_if"
                }
            ],
            "from": {
                "key_code": "j",
                "modifiers": {
                    "mandatory": [
                        "left_control"
                    ]
                }
            },
            "to": [
                {
                    "key_code": "japanese_kana"
                }
            ],
            "type": "basic"
        }
    ]
}
```

### Q. アプリによってq/lキーでモードを切り替えてもq/lが入力されてしまう / `C-j`で改行されてしまう

https://github.com/mtgto/macSKK/issues/119 と同じ問題と思われます。
v0.20.0ではKitty, LINE, Alacrittyについて「空文字挿入」というワークアラウンドを初期設定でもっています。

空文字挿入の設定は、アプリが最前面にあるときに入力メニューから設定可能です。
またmacSKKの設定内の「互換性の設定」からも可能です。

### Q. OS標準の入力ソース ( `日本語` や `ABC` ) を削除してmacSKKだけにしたい

`日本語` の設定で入力モードの英字を有効にしてから `ABC`,  `日本語` の順に削除するとmacSKKだけにしたりできるようです。
参考: https://zenn.dev/yoshiyoshifujii/articles/78798db6472bf4

## 開発

コントリビュートのガイドを [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) に用意しています。

Xcodeでビルドし、 `~/Library/Input Methods` に `macSKK.app` を配置してからシステム設定→キーボード→入力ソースで `ひらがな (macSKK)` などを追加してください。

macOS 14以降ではApp Sandboxの制限が強くなりました。すでにリリース版macSKKを使っている環境で開発版のmacSKKを使用すると起動時に `「"macSKK"がほかのアプリからのデータへのアクセスを求めています。」` というダイアログが表示されることがあります。これはリリース版で署名に使用しているTeam IDと異なるProvisioning Profileを使用している (もしくはAd hoc署名を使っている) 場合に同じユーザー辞書ファイルにアクセスすることで発生します。この状態で「許可」を選んでしまうとリリース版のmacSKKが逆に読み込めなくなるなどの想定しない問題が発生する可能性があります。お手数ですがBundle Identifierを変更するなどを検討してください。

### バージョンアップ

`X.Y.Z` 形式のバージョン (MARKETING_VERSION) とビルド番号 (CURRENT_PROJECT_VERSION) の更新が必要です。

#### ビルド番号

メジャー、マイナー、パッチ、どのバージョンアップでも1ずつインクリメントしてください。
Xcodeから手動でやってもいいし、`agvtool`でもいいです。

```console
agvtool next-version
```

#### MARKETING_VERSIONの更新

`Info.plist`に`CFBundleShortVersionString`で管理するのではなくpbxprojに`MARKETING_VERSION`で管理する形式だと`agvtool next-marketing-version` が使えないみたいなのでXcodeで手動で変えてください。

### リリース

- CHANGELOGを記述
- バージョンアップ
- `make clean && make release`
- GitHubのReleaseを作成、dmgとdSYMsをアップロード、CHANGELOGをコピペ

## ライセンス

macSKKはGNU一般公衆ライセンスv3またはそれ以降のバージョンの条項の元で配布されるフリー・ソフトウェアです。

詳細は `LICENSE` を参照してください。
