#!/usr/bin/env bash
#
# setup-workspace.sh
#
# 株式会社ふもと（法人）と個人事業のワークスペースを Mac 上で完全に分離する。
#
#   1. ローカルフォルダ構成   ~/fumoto-inc（法人） / ~/personal（個人）
#   2. Git のコミット識別子   ディレクトリごとに author を自動切替（includeIf）
#   3. クラウド同期の分離     法人=SharePoint/OneDrive, 個人=Google Drive
#   4. GitHub リポジトリ      法人用 Organization を前提とした配置
#
# 設計上の大原則（重要）:
#
#   文書のフォルダ階層をローカルに作らない。
#
#   SharePoint に既にフォルダ体系がある以上、同じ階層をローカルにも作れば
#   「どちらが正か分からない」二重管理が生まれる。このスクリプトは
#   OneDrive が同期している SharePoint ライブラリ実体へのリンクを張るだけで、
#   文書用のディレクトリは一切作らない。
#
#   ローカルに実体を作るのは SharePoint に存在しないもの（コード・一時作業）に限る。
#
#   したがってフォルダ構成は常に SharePoint 側が正であり、
#   このスクリプトが構成を知っている必要がない（＝ズレようがない）。
#
# 使い方:
#   bash setup-workspace.sh --show-sync   # 同期フォルダの実物を一覧するだけ
#   bash setup-workspace.sh --dry-run     # 何が起きるか確認するだけ
#   bash setup-workspace.sh               # 実行
#
# macOS 標準の bash 3.2 で動作するよう、bash 4 以降の機能は使用していない。

set -euo pipefail

# ---------------------------------------------------------------------------
# 設定
# ---------------------------------------------------------------------------

CORP_ROOT="${HOME}/fumoto-inc"
PERSONAL_ROOT="${HOME}/personal"

CORP_NAME="高橋 正憲"
CORP_EMAIL="masanori.takahashi@fumoto-inc.co.jp"

PERSONAL_NAME="高橋 正憲"
PERSONAL_EMAIL="masa.takahashi888@gmail.com"

CLOUD_DIR="${HOME}/Library/CloudStorage"

# ---------------------------------------------------------------------------
# 内部状態
# ---------------------------------------------------------------------------

DRY_RUN=0
SHOW_SYNC_ONLY=0
CREATED_COUNT=0
SKIPPED_COUNT=0

case "${1:-}" in
  --dry-run)   DRY_RUN=1 ;;
  --show-sync) SHOW_SYNC_ONLY=1 ;;
  '')          ;;
  *)           printf 'usage: %s [--dry-run|--show-sync]\n' "$0" >&2; exit 2 ;;
esac

if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''
  C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

section() { printf '\n%s%s%s\n' "${C_BOLD}${C_BLUE}" "$1" "${C_RESET}"; }
ok()      { printf '  %s+%s %s\n' "${C_GREEN}" "${C_RESET}" "$1"; }
skip()    { printf '  %s=%s %s %s(既存)%s\n' "${C_DIM}" "${C_RESET}" "$1" "${C_DIM}" "${C_RESET}"; }
warn()    { printf '  %s!%s %s\n' "${C_YELLOW}" "${C_RESET}" "$1"; }
info()    { printf '    %s%s%s\n' "${C_DIM}" "$1" "${C_RESET}"; }
tilde()   { printf '%s' "${1/#$HOME/\~}"; }

mkdirp() {
  local path="$1"
  if [ -d "${path}" ]; then
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1)); skip "$(tilde "${path}")"
  else
    [ "${DRY_RUN}" -eq 0 ] && mkdir -p "${path}"
    CREATED_COUNT=$((CREATED_COUNT + 1)); ok "$(tilde "${path}")"
  fi
}

writef() {
  local path="$1" body="$2"
  if [ -e "${path}" ]; then
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1)); skip "$(tilde "${path}")"
  else
    [ "${DRY_RUN}" -eq 0 ] && printf '%s\n' "${body}" > "${path}"
    CREATED_COUNT=$((CREATED_COUNT + 1)); ok "$(tilde "${path}")"
  fi
}

# 既存を壊さずシンボリックリンクを張る
link_to() {
  local target="$1" linkpath="$2"
  if [ -L "${linkpath}" ]; then
    local cur
    cur=$(readlink "${linkpath}")
    if [ "${cur}" = "${target}" ]; then
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1)); skip "$(tilde "${linkpath}")"
    else
      warn "$(tilde "${linkpath}") は別の場所を指しています。手動で確認してください。"
      info "現在: ${cur}"
      info "想定: ${target}"
    fi
  elif [ -e "${linkpath}" ]; then
    warn "$(tilde "${linkpath}") は実体として存在するためリンクを張れません。"
    info "中身を退避してから再実行してください。"
  else
    [ "${DRY_RUN}" -eq 0 ] && ln -s "${target}" "${linkpath}"
    CREATED_COUNT=$((CREATED_COUNT + 1))
    ok "$(tilde "${linkpath}")"
    info "-> $(tilde "${target}")"
  fi
}

# ---------------------------------------------------------------------------
# 同期フォルダの検出
#
# macOS の OneDrive は以下の命名で同期する:
#   OneDrive-<組織名>                    個人の OneDrive（法人テナント）
#   OneDrive-SharedLibraries-<組織名>    SharePoint サイトのライブラリ（配下に1サイト1フォルダ）
#   GoogleDrive-<メールアドレス>          Google Drive
# ---------------------------------------------------------------------------

show_sync_inventory() {
  section "同期フォルダの実物"

  if [ ! -d "${CLOUD_DIR}" ]; then
    warn "$(tilde "${CLOUD_DIR}") が存在しません。"
    info "OneDrive / Google Drive のデスクトップアプリを先に設定してください。"
    return 0
  fi

  local found=0
  local d
  for d in "${CLOUD_DIR}"/*; do
    [ -d "${d}" ] || continue
    found=1
    local base
    base=$(basename "${d}")

    case "${base}" in
      OneDrive-SharedLibraries-*)
        printf '  %s%s%s  %s(SharePoint ライブラリ / 法人)%s\n' \
          "${C_BOLD}" "${base}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
        local lib
        for lib in "${d}"/*; do
          [ -d "${lib}" ] || continue
          printf '      %s\n' "$(basename "${lib}")"
        done
        ;;
      OneDrive-*)
        printf '  %s%s%s  %s(OneDrive / 法人)%s\n' \
          "${C_BOLD}" "${base}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
        ;;
      GoogleDrive-*)
        printf '  %s%s%s  %s(Google Drive / 個人)%s\n' \
          "${C_BOLD}" "${base}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
        ;;
      *)
        printf '  %s%s%s  %s(分類不明 — 手動で確認)%s\n' \
          "${C_BOLD}" "${base}" "${C_RESET}" "${C_YELLOW}" "${C_RESET}"
        ;;
    esac
  done

  if [ "${found}" -eq 0 ]; then
    warn "$(tilde "${CLOUD_DIR}") 配下に同期フォルダがありません。"
  fi
}

# --show-sync は一覧だけ出して終了
if [ "${SHOW_SYNC_ONLY}" -eq 1 ]; then
  show_sync_inventory
  printf '\n'
  exit 0
fi

# ---------------------------------------------------------------------------

printf '%s\n' "${C_BOLD}================================================================${C_RESET}"
printf '%s\n' "${C_BOLD} ワークスペース分離セットアップ${C_RESET}"
printf '%s\n' "${C_BOLD} 株式会社ふもと（法人） / 個人事業${C_RESET}"
printf '%s\n' "${C_BOLD}================================================================${C_RESET}"

if [ "${DRY_RUN}" -eq 1 ]; then
  printf '\n%s\n' "${C_YELLOW}${C_BOLD}[DRY RUN] 実際には何も作成しません。${C_RESET}"
fi

# ---------------------------------------------------------------------------
# 1. ルートの作成（文書フォルダは作らない）
# ---------------------------------------------------------------------------

section "1. ルートの作成"

info "文書の階層はローカルに作りません。SharePoint 側が正です。"
printf '\n'

mkdirp "${CORP_ROOT}"
mkdirp "${CORP_ROOT}/40_コード"        # SharePoint にないもの（GitHub が正）
mkdirp "${CORP_ROOT}/_local"           # 一時作業。消えても困らないもの置き場

mkdirp "${PERSONAL_ROOT}"
mkdirp "${PERSONAL_ROOT}/40_コード"
mkdirp "${PERSONAL_ROOT}/_local"

# ---------------------------------------------------------------------------
# 2. クラウド同期先へのリンク（ここが本体）
# ---------------------------------------------------------------------------

section "2. クラウド同期先へのリンク"

if [ ! -d "${CLOUD_DIR}" ]; then
  warn "$(tilde "${CLOUD_DIR}") が存在しません。"
  info "OneDrive / Google Drive のデスクトップアプリを設定後、再実行してください。"
else
  LINKED=0
  for d in "${CLOUD_DIR}"/*; do
    [ -d "${d}" ] || continue
    base=$(basename "${d}")

    case "${base}" in
      OneDrive-SharedLibraries-*)
        # SharePoint ライブラリは 1 サイト 1 フォルダ。個別にリンクする。
        for lib in "${d}"/*; do
          [ -d "${lib}" ] || continue
          libname=$(basename "${lib}")
          link_to "${lib}" "${CORP_ROOT}/${libname}"
          LINKED=1
        done
        ;;
      OneDrive-*)
        link_to "${d}" "${CORP_ROOT}/OneDrive"
        LINKED=1
        ;;
      GoogleDrive-*)
        link_to "${d}" "${PERSONAL_ROOT}/GoogleDrive"
        LINKED=1
        ;;
      *)
        warn "${base} は分類できませんでした。手動でリンクしてください。"
        ;;
    esac
  done

  if [ "${LINKED}" -eq 0 ]; then
    warn "リンク対象の同期フォルダが見つかりませんでした。"
    info "bash setup-workspace.sh --show-sync で実物を確認できます。"
  fi
fi

# ---------------------------------------------------------------------------
# 3. 境界ルールの明文化
# ---------------------------------------------------------------------------

section "3. 境界ルールの明文化"

writef "${CORP_ROOT}/README.md" "# 株式会社ふもと — 法人ワークスペース

このディレクトリ配下は **すべて法人（株式会社ふもと）の資産** である。
個人事業のファイルをここに置かない。

## このディレクトリの構造

| 名前 | 実体 | 正 (source of truth) |
|---|---|---|
| \`<サイト名> - Documents\` | SharePoint 同期へのリンク | **SharePoint** |
| \`OneDrive\` | OneDrive 同期へのリンク | **OneDrive** |
| \`40_コード\` | ローカル実体 | **GitHub（法人 org）** |
| \`_local\` | ローカル実体 | なし（消えてよいもの専用） |

## 重要: 文書のフォルダ階層をここに作らないこと

SharePoint に既にフォルダ体系がある。同じ階層をローカルにも作ると
「どちらが最新か分からない」二重管理になる。

文書を置きたいときは **リンク経由で SharePoint 側に置く**。
ローカルに実体を作ってよいのは \`40_コード\` と \`_local\` だけ。

## 判断に迷ったときの基準

ふるさと納税制度に関する自治体サポートに関わるものは、
たとえ個人名義で受注した経緯があっても **法人側** に置く。

## Git

このディレクトリ配下のコミットは自動的に以下の identity になる。

    ${CORP_NAME} <${CORP_EMAIL}>

\`git config user.email\` で確認できる。個人メールが出たら設定が効いていない。
"

writef "${PERSONAL_ROOT}/README.md" "# 個人事業ワークスペース

このディレクトリ配下は **すべて個人事業の資産** である。
株式会社ふもとの案件・法人文書をここに置かない。

## このディレクトリの構造

| 名前 | 実体 | 正 (source of truth) |
|---|---|---|
| \`GoogleDrive\` | Google Drive 同期へのリンク | **Google Drive** |
| \`40_コード\` | ローカル実体 | **GitHub \`masa-takahashi-lab\`** |
| \`_local\` | ローカル実体 | なし（消えてよいもの専用） |

## Git

このディレクトリ配下のコミットは自動的に以下の identity になる。

    ${PERSONAL_NAME} <${PERSONAL_EMAIL}>

## 滝川市案件について

Google Drive の \`滝川市向け資料\` は **参照用の複製であり正ではない**。
正は法人 SharePoint 側。更新は必ず SharePoint に対して行い、
こちらのコピーは編集しないこと。
"

# ---------------------------------------------------------------------------
# 4. Git identity の自動切替
# ---------------------------------------------------------------------------

section "4. Git identity の分離"

writef "${CORP_ROOT}/.gitconfig" "[user]
	name = ${CORP_NAME}
	email = ${CORP_EMAIL}
"

writef "${PERSONAL_ROOT}/.gitconfig" "[user]
	name = ${PERSONAL_NAME}
	email = ${PERSONAL_EMAIL}
"

GLOBAL_GITCONFIG="${HOME}/.gitconfig"

if [ -f "${GLOBAL_GITCONFIG}" ] && grep -q 'gitdir:~/fumoto-inc/' "${GLOBAL_GITCONFIG}" 2>/dev/null; then
  SKIPPED_COUNT=$((SKIPPED_COUNT + 1)); skip "$(tilde "${GLOBAL_GITCONFIG}") の includeIf 設定"
else
  if [ "${DRY_RUN}" -eq 0 ]; then
    if [ -f "${GLOBAL_GITCONFIG}" ]; then
      cp "${GLOBAL_GITCONFIG}" "${GLOBAL_GITCONFIG}.bak-before-workspace-split"
      info "既存の ~/.gitconfig を ~/.gitconfig.bak-before-workspace-split に退避しました"
    fi
    cat >> "${GLOBAL_GITCONFIG}" <<'GITEOF'

# --- ワークスペース分離: ディレクトリごとに identity を切り替える ---
# 法人ディレクトリ配下では会社メール、個人ディレクトリ配下では個人メールで
# 自動的にコミットされる。手動で切り替える必要はない。
[includeIf "gitdir:~/fumoto-inc/"]
	path = ~/fumoto-inc/.gitconfig
[includeIf "gitdir:~/personal/"]
	path = ~/personal/.gitconfig
GITEOF
  fi
  CREATED_COUNT=$((CREATED_COUNT + 1))
  ok "$(tilde "${GLOBAL_GITCONFIG}") に includeIf を追記"
fi

# ---------------------------------------------------------------------------
# 5. 同期フォルダの実物一覧
# ---------------------------------------------------------------------------

show_sync_inventory

# ---------------------------------------------------------------------------
# 6. 棚卸し（移動はしない。報告のみ）
# ---------------------------------------------------------------------------

section "棚卸し — 新ルート外にある Git リポジトリ"

info "以下は「見つけた」だけです。移動も削除も行っていません。"
printf '\n'

REPO_LIST=$(find "${HOME}/Desktop" "${HOME}/Documents" "${HOME}/Developer" "${HOME}/src" \
  -maxdepth 3 -type d -name '.git' 2>/dev/null | sed 's|/\.git$||' | sort || true)

if [ -n "${REPO_LIST}" ]; then
  printf '%s\n' "${REPO_LIST}" | while IFS= read -r repo; do
    remote=$(git -C "${repo}" remote get-url origin 2>/dev/null || echo '(remote なし)')
    printf '  %s\n' "$(tilde "${repo}")"
    printf '    %s%s%s\n' "${C_DIM}" "${remote}" "${C_RESET}"
  done
else
  printf '  %s(見つかりませんでした)%s\n' "${C_DIM}" "${C_RESET}"
fi

# ---------------------------------------------------------------------------

section "完了"

printf '  作成: %s%s%s 件 / 既存のためスキップ: %s%s%s 件\n' \
  "${C_GREEN}" "${CREATED_COUNT}" "${C_RESET}" \
  "${C_DIM}" "${SKIPPED_COUNT}" "${C_RESET}"

if [ "${DRY_RUN}" -eq 1 ]; then
  printf '\n%s\n' "${C_YELLOW}${C_BOLD}[DRY RUN] 実際には何も作成していません。${C_RESET}"
  printf '%s\n' "本番実行: ${C_BOLD}bash setup-workspace.sh${C_RESET}"
else
  cat <<EOF

${C_BOLD}次にやること${C_RESET}

  1. Git identity が効いているか確認する

       mkdir -p ~/fumoto-inc/40_コード/tmp && cd \$_ && git init -q
       git config user.email      ${C_DIM}# → ${CORP_EMAIL}${C_RESET}
       cd ~ && rm -rf ~/fumoto-inc/40_コード/tmp

  2. 上の棚卸しに出たリポジトリを 40_コード 配下へ手で移す

  3. 法人用 GitHub Organization を作成し、会社のコードを移管する
     ${C_DIM}詳細は docs/workspace-separation.md を参照${C_RESET}

EOF
fi
