macSKK [![test](https://github.com/mtgto/macSKK/actions/workflows/test.yml/badge.svg)](https://github.com/mtgto/macSKK/actions/workflows/test.yml)
====
macSKKはmacOS用の[SKK](https://ja.wikipedia.org/wiki/SKK)方式の日本語入力システム (インプットメソッド) です。

macOS用のSKK方式の日本語入力システムにはすでに[AquaSKK](https://github.com/codefirst/aquaskk/)がありますが、いくつか独自の機能を作りたいと思い新たに開発しています。

macSKKを使用するには macOS 13.3 以降が必要です。
Universal Binaryでビルドしていますが、動作確認はApple Silicon環境でのみ行っています。

## 特徴

- 日本語入力システムはパスワードなどの機密情報を処理する可能性があるため安全性が求められるプログラムです。そのためmacSKKはmacOSのSandbox機構を使いネットワーク通信やファイルの読み書きに制限をかけることでセキュリティホールを攻撃されたときの被害を減らすように心掛けます。
- 不正なコードが含まれるリスクを避けるため、サードパーティによる外部ライブラリは使用していません。
- すべてをSwiftだけでコーディングしており、イベント処理にCombineを、UI部分にはSwiftUIを使用しています。
- 単語登録モードや送り仮名入力中などキー入力による状態変化管理が複雑なのでユニットテストを書いてエンバグのリスクを減らす努力をしています。

## 実装予定

しばらくはAquaSKKにはあるけどmacSKKにない機能を実装しつつ、徐々に独自機能を実装していこうと考えています。

- [x] 複数辞書を使用できるようにする
- [x] マイ辞書に保存しないプライベートモード
- [x] アプリごとに直接入力させるかどうかを設定できるようにする
  - ddskkを使っているときのGUI版Emacs.appなど
- [x] 過去の入力を使った入力補完
- [ ] Java AWT製アプリケーションで入力ができない問題のワークアラウンド対応 (JetBrain製品など)
- [ ] キー配列の設定 (Dvorakなど)

### 実装予定の独自機能

- [x] 自動更新確認
  - Network Outgoingが可能なXPCプロセスを作成し、GitHub Releasesから情報を定期的に取得して新しいバージョンが見つかったらNotification Centerに表示する
- [ ] iCloudにマイ辞書を保存して他環境と共有できるようにする
- [ ] マイ辞書の暗号化
  - 編集したい場合は生データでのエクスポート & インポートできるようにする

## インストール

2023年現在、Mac App Storeでは日本語入力システムを配布することができないため、[Appleのソフトウェア公証](https://support.apple.com/ja-jp/guide/security/sec3ad8e6e53/1/web/1)を受けたアプリケーションバイナリを[GitHub Releases](https://github.com/mtgto/macSKK/releases/latest)で配布しています。dmgファイルをダウンロードしマウントした中にあるpkgファイルからインストールしてください。

macSKKのインストール後に、システム設定→キーボード→入力ソースから「ひらがな (macSKK)」と「ABC (macSKK)」を追加してください。カタカナ、全角英数、半角カナは追加しなくても問題ありません。
もしインストール直後に表示されなかったり、さしかえても反映されない場合はログアウト & ログインを試してみてください。

## アンインストール

現在アンインストールする手順は用意していないためお手数ですが手動でお願いします。
今後、dmg内にアンインストーラを同梱予定です。

手動で行うには、システム設定→キーボード→入力ソースから「ひらがな (macSKK)」「ABC (macSKK)」を削除後、以下のファイルを削除してください。

- `~/Library/Input Methods/macSKK.app`
- `~/Library/Containers/net.mtgto.inputmethod.macSKK`

## FAQ

### Q. Visual Studio Code (vscode) で `C-j` を押すと行末が削除されてしまいます

A. `C-j` がVisual Studio Codeのキーボードショートカット設定の `editor.action.joinLines` にデフォルトでは割り当てられていると思われます。`Cmd-K Cmd-S` から `editor.action.joinLines` で検索し、キーバインドを削除するなり変更するなりしてみてください。

## 開発

Xcodeでビルドし、 `~/Library/Input Methods` に `macSKK.app` を配置してからシステム設定→キーボード→入力ソースで `ひらがな (macSKK)` などを追加してください。

SKK辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries` に配置してください。
その後で環境設定の辞書設定で使用する辞書を有効に切り替えてください。EUC-JPでないエンコーディングの場合はiボタンからエンコーディングを切り替えてください。

ユーザー辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/skk-jisyo.utf8` にUTF-8形式で保存されます。
ユーザー辞書はテキストエディタで更新可能です。別プロセスでユーザー辞書が更新された場合はmacSKKが自動で再読み込みを行います。

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

macSKKはGNU一般公衆ライセンスv3またはそれ移行のバージョンの条項の元で配布されるフリー・ソフトウェアです。

詳細は `LICENSE` を参照してください。
