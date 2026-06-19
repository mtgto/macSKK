# バージョン自動チェック

macSKKは12時間おきにGitHub Releasesの新しいバージョンを確認します。新バージョンが見つかった場合は通知センターで通知します。

## 仕組み

macSKK本体はApp Sandboxによりインターネット通信ができないため、バージョンチェックはXPCを介した外部プロセス (`FetchUpdateService`) で行われます。GitHub ReleasesページのAtomフィードを取得して確認しています。
