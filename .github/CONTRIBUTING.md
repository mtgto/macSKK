# Contribution Guide

> [!WARNING]
> macOS 14以降ではApp Sandboxの制限が強くなりました。すでにリリース版macSKKを使っている環境で開発版のmacSKKを使用すると起動時に `「"macSKK"がほかのアプリからのデータへのアクセスを求めています。」` というダイアログが表示されることがあります。これはリリース版で署名に使用しているTeam IDと異なるProvisioning Profileを使用している (もしくはAd hoc署名を使っている) 場合に同じユーザー辞書ファイルにアクセスすることで発生します。この状態で「許可」を選んでしまうとリリース版のmacSKKが逆に読み込めなくなるなどの想定しない問題が発生する可能性があります。事前にユーザー辞書をバックアップしておくことを推奨します。開発時のみBundle Identifierを変更することも検討してください。

## ドキュメントへの貢献について

ドキュメント (`docs/` 以下) へのPull Requestは受け付けていません。誤りや不足に気づいた場合は [Issue](https://github.com/mtgto/macSKK/issues) でお知らせください。

## ローカルでのビルドと実行

手元で修正を加えたあと、Gitリポジトリのルートディレクトリにある`build_restart.sh`を実行することで使用するmacSKKをローカルビルドに差し替えします。

```console
$ ./build_restart.sh
```

このスクリプトの実行により

1. ローカルのmacSKKがビルドされ
2. `~/Library/Input Methods/macSKK.app`が配置され
3. 既存のmacSKKのプロセスをkillして再起動

👆の3つが実行され、実行したPCで開発中のバージョンを試すことができます。

## iCloudでの設定同期について

設定をiCloudで同期する機能 (`NSUbiquitousKeyValueStore`) には `com.apple.developer.ubiquity-kvstore-identifier` というentitlementが必要で、これを使うにはApp IDにiCloud capabilityを有効にしたプロビジョニングプロファイルが要ります。

リポジトリの標準の設定 (`macSKK/macSKK.entitlements`) にはこのentitlementを含めていないため、Apple Developer Programに参加していなくてもこれまでどおりビルドできます。このビルドでは設定画面のiCloud同期のトグルが無効になるだけで、それ以外の動作は変わりません。

手元でiCloud同期を有効にしたビルドを作る場合は、Developer PortalでApp IDにiCloud capabilityを有効にしたプロビジョニングプロファイルを作成・インストールした上で、`macSKK/Config/Local.xcconfig.sample` を `macSKK/Config/Local.xcconfig` にコピーして自分の環境に合わせて書き換えてください。`Local.xcconfig` は`.gitignore`に入れてあるのでコミットされません。
