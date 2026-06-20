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
- [x] [マイ辞書に保存しないプライベートモード](https://mtgto.github.io/macSKK/features/private-mode)
- [x] [アプリごとに直接入力させるかどうかを設定できるようにする](https://mtgto.github.io/macSKK/config/direct-mode)
  - ddskkを使っているときのGUI版Emacs.appなど
- [x] [過去の入力を使った入力補完](https://mtgto.github.io/macSKK/features/word-registration#読みの補完)
- [x] [数値変換](https://mtgto.github.io/macSKK/features/numeric)
- [x] 送りありエントリのブロック形式
- [x] [キー配列の設定 (Dvorakなど)](https://mtgto.github.io/macSKK/config/general#キーボードレイアウト)
- [x] [ローマ字変換ルールの設定](https://mtgto.github.io/macSKK/config/kana-rule)
- [x] [SKKServを辞書として使う](https://mtgto.github.io/macSKK/config/dictionary#skkserv)
- [x] [キーバインドの変更](https://mtgto.github.io/macSKK/config/keybinding)
- [ ] Java AWT製アプリケーションで入力ができない問題のワークアラウンド対応 (JetBrain製品など)

### 実装予定の独自機能

- [x] [自動更新確認](https://mtgto.github.io/macSKK/config/software-update)
  - Network Outgoingが可能なXPCプロセスを作成し、GitHub Releasesから情報を定期的に取得して新しいバージョンが見つかったらNotification Centerに表示する
- [x] 辞書のJSON形式への対応
- [x] xterm.jsを利用するアプリケーションでaiueoでひらがなが入力できない問題のワークアラウンド対応 (VSCode Terminal, Hyperなど)
- [ ] iCloudにマイ辞書を保存して他環境と共有できるようにする
- [ ] マイ辞書の暗号化
  - 編集したい場合は生データでのエクスポート & インポートできるようにする

## インストール

2026年現在、Mac App Storeでは日本語入力システムを配布することができないため、[Appleのソフトウェア公証](https://support.apple.com/ja-jp/guide/security/sec3ad8e6e53/1/web/1)を受けたアプリケーションバイナリを[GitHub Releases](https://github.com/mtgto/macSKK/releases/latest)で配布しています。dmgファイルをダウンロードしマウントした中にあるpkgファイルからインストールしてください。

Homebrew Caskでインストールする場合:

```console
brew install --cask macskk
```

詳しいインストール手順・辞書の導入方法は **[ドキュメントサイト](https://mtgto.github.io/macSKK/guide/install)** を参照してください。

## ドキュメント

設定・機能・FAQ などの詳細は **https://mtgto.github.io/macSKK/** を参照してください。

## 開発

コントリビュートのガイドを [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) に用意しています。

Xcodeでビルドし、 `/Library/Input Methods` に `macSKK.app` を配置してからシステム設定→キーボード→入力ソースで `ひらがな` などを追加してください。

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
