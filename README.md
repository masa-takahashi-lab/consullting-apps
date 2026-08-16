# consullting-apps

## ワークスペース分離（株式会社ふもと / 個人事業）

法人設立にともない、Mac 上の作業環境を法人と個人で分離するための設計とセットアップ手順。

| ファイル | 内容 |
|---|---|
| [`docs/workspace-separation.md`](docs/workspace-separation.md) | 設計・SharePoint 実構造・移行マッピング・GitHub Organization の分離手順 |
| [`scripts/setup-workspace.sh`](scripts/setup-workspace.sh) | ワークスペース分離のセットアップ |
| [`scripts/migrate-drive-to-sharepoint.sh`](scripts/migrate-drive-to-sharepoint.sh) | Google Drive にしかない資料を SharePoint へ移行 |

```bash
# 1. ワークスペースの分離
bash scripts/setup-workspace.sh --show-sync   # 同期フォルダの実物を確認
bash scripts/setup-workspace.sh --dry-run     # 確認（何も作成しない）
bash scripts/setup-workspace.sh               # 実行

# 2. Google Drive から SharePoint への移行
bash scripts/migrate-drive-to-sharepoint.sh --dry-run   # 確認（コピーしない）
bash scripts/migrate-drive-to-sharepoint.sh             # 実行
```

どちらのスクリプトも既存ファイルの移動・削除・上書きを一切行わず、
何度実行しても同じ結果になる（冪等）。
移行スクリプトは Google Drive 側を変更しない。
