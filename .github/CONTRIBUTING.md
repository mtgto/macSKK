# Contribution Guide

## ローカルでのビルドと実行

手元で修正を加えた場合はGitリポジトリのルートディレクトリにある`build_restart.sh`を起動します。
（実行中に管理者のパスワードが求められます）

```console
$ ./build_restart.sh
```

このスクリプトの実行により

1. ローカルのmacSKKがビルドされ
2. `~/Library/Input Methods/macSKK.app`が配置され
3. 既存のmacSKKのプロセスをkillして再起動

👆の3つが実行され、実行したPCで開発中のバージョンを試すことができます。
