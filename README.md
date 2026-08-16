# consullting-apps

## ワークスペース分離（株式会社ふもと / 個人事業）

法人設立にともない、Mac 上の作業環境を法人と個人で分離するための設計とセットアップ手順。

| ファイル | 内容 |
|---|---|
| [`docs/workspace-separation.md`](docs/workspace-separation.md) | 設計・運用ルール・GitHub Organization の分離手順 |
| [`scripts/setup-workspace.sh`](scripts/setup-workspace.sh) | Mac 上で実行するセットアップスクリプト |

```bash
bash scripts/setup-workspace.sh --dry-run   # 確認（何も作成しない）
bash scripts/setup-workspace.sh             # 実行
```

スクリプトは既存ファイルの移動・削除・上書きを一切行わず、何度実行しても同じ結果になる。
