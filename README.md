macSKK
====
macSKKはmacOS用の[SKK](https://ja.wikipedia.org/wiki/SKK)方式の日本語入力メソッドです。

macOS用のSKK方式の日本語入力メソッドにはすでに[AquaSKK](https://github.com/codefirst/aquaskk/)がありますが、いくつか独自の機能を作りたいと思い新たに開発しています。

使用するには macOS 13.1 以降が必要です。

## 特徴

- インプットメソッドはパスワードなどの機密情報を処理する可能性のある安全性が非常に求められるプログラムです。そのためmacSKKはmacOSのSandbox機構を使いNetwork機能やファイルの読み書きに制限をかけています。
- すべてをSwiftだけでコーディングしており、イベント処理にCombineを、UI部分にはSwiftUIを使用しています。

## 実装予定

しばらくはAquaSKKにあるけどmacSKKにない機能を実装しつつ、徐々に独自機能を実装していこうと考えています。

- 複数辞書を使用できるようにする
- マイ辞書に保存しないプライベートモード
- アプリごとに直接入力させるかどうかを設定できるようにする
  - ddskkを使っているときのGUI版Emacs.appなど
- Java AWT製アプリケーションで入力ができない問題のワークアラウンド対応 (JetBrain製品など)

### 実装予定の独自機能

- iCloudにマイ辞書を保存して他環境と共有できるようにする
- マイ辞書の暗号化
  - 編集したい場合は生データでのエクスポート & インポートできるようにする
- 自動更新確認
  - Network Outgoingが可能なXPCプロセスを作成し、GitHub Releasesから情報を定期的に取得して見つかったらNotification Centerに表示する

## インストール

Mac App Storeでインプットメソッドを配布することができないため、[Appleのソフトウェア公証](https://support.apple.com/ja-jp/guide/security/sec3ad8e6e53/1/web/1)を受けたアプリケーションバイナリをGitHub Releasesで配布する予定です。

インストール後、システム設定→キーボード→入力ソースから「ABC (macSKK)」と「ひらがな (macSKK)」を追加してください。カタカナ、全角英数、半角カナは追加しなくても問題ありません。

## アンインストール

インストーラにアンインストーラを同梱予定です (TODO)。

手動で行うには、以下のファイルを削除してください。

- `~/Library/Input Methods/macSKK.app`
- `~/Library/Containers/net.mtgto.inputmethod.macSKK`

## 開発

Xcodeでビルドし、 `~/Library/Input Methods` に `macSKK.app` を配置してからシステム設定→キーボード→入力ソースで `ひらがな (macSKK)` などを追加してください。
一覧に表示されなかったり、さしかえても反映されない場合はログアウト & ログインを試してみてください。

SKK辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries` に配置してください。
現在は `SKK-JISYO.L` のみ読み込みます。環境設定で使用する辞書を設定可能にする予定です。
ユーザー辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/skk-jisyo.utf8` にUTF-8形式で保存されます。

## ライセンス

macSKKはGNU一般公衆ライセンスv3またはそれ移行のバージョンの条項の元で配布されるフリー・ソフトウェアです。

詳細は `LICENSE` を参照してください。
