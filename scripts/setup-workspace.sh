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
# 設計上の大原則:
#   このスクリプトは「作る」だけで「動かさない・消さない」。
#   既存ファイルの移動・削除は一切行わず、現状の棚卸し結果を報告するに留める。
#   何度実行しても同じ結果になる（冪等）。
#
# 使い方:
#   bash setup-workspace.sh --dry-run   # 何が起きるか確認するだけ（推奨: まずこれ）
#   bash setup-workspace.sh             # 実際に作成する
#
# macOS 標準の bash 3.2 で動作するよう、bash 4 以降の機能は使用していない。

set -euo pipefail

# ---------------------------------------------------------------------------
# 設定（必要に応じてここだけ書き換える）
# ---------------------------------------------------------------------------

CORP_ROOT="${HOME}/fumoto-inc"
PERSONAL_ROOT="${HOME}/personal"

CORP_NAME="高橋 正憲"
CORP_EMAIL="masanori.takahashi@fumoto-inc.co.jp"

PERSONAL_NAME="高橋 正憲"
PERSONAL_EMAIL="masa.takahashi888@gmail.com"

# ---------------------------------------------------------------------------
# 内部状態
# ---------------------------------------------------------------------------

DRY_RUN=0
CREATED_COUNT=0
SKIPPED_COUNT=0

if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_RED=$'\033[31m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''
  C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_RED=''
fi

section() { printf '\n%s%s%s\n' "${C_BOLD}${C_BLUE}" "$1" "${C_RESET}"; }
ok()      { printf '  %s+%s %s\n' "${C_GREEN}" "${C_RESET}" "$1"; }
skip()    { printf '  %s=%s %s %s(既存)%s\n' "${C_DIM}" "${C_RESET}" "$1" "${C_DIM}" "${C_RESET}"; }
warn()    { printf '  %s!%s %s\n' "${C_YELLOW}" "${C_RESET}" "$1"; }
info()    { printf '    %s%s%s\n' "${C_DIM}" "$1" "${C_RESET}"; }

# ディレクトリを冪等に作成する
mkdirp() {
  local path="$1"
  if [ -d "${path}" ]; then
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    skip "${path/#$HOME/\~}"
  else
    if [ "${DRY_RUN}" -eq 0 ]; then
      mkdir -p "${path}"
    fi
    CREATED_COUNT=$((CREATED_COUNT + 1))
    ok "${path/#$HOME/\~}"
  fi
}

# ファイルを冪等に書き出す（既存なら絶対に上書きしない）
writef() {
  local path="$1"
  local body="$2"
  if [ -e "${path}" ]; then
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    skip "${path/#$HOME/\~}"
  else
    if [ "${DRY_RUN}" -eq 0 ]; then
      printf '%s\n' "${body}" > "${path}"
    fi
    CREATED_COUNT=$((CREATED_COUNT + 1))
    ok "${path/#$HOME/\~}"
  fi
}

# ---------------------------------------------------------------------------

printf '%s\n' "${C_BOLD}================================================================${C_RESET}"
printf '%s\n' "${C_BOLD} ワークスペース分離セットアップ${C_RESET}"
printf '%s\n' "${C_BOLD} 株式会社ふもと（法人） / 個人事業${C_RESET}"
printf '%s\n' "${C_BOLD}================================================================${C_RESET}"

if [ "${DRY_RUN}" -eq 1 ]; then
  printf '\n%s\n' "${C_YELLOW}${C_BOLD}[DRY RUN] 実際には何も作成しません。${C_RESET}"
fi

# ---------------------------------------------------------------------------
# 1. 法人ルート
# ---------------------------------------------------------------------------

section "1. 法人ルート  ${CORP_ROOT/#$HOME/\~}"

mkdirp "${CORP_ROOT}"

# 法人運営（案件ではない、会社そのものの運営）
mkdirp "${CORP_ROOT}/00_法人運営"
mkdirp "${CORP_ROOT}/00_法人運営/01_登記・定款"
mkdirp "${CORP_ROOT}/00_法人運営/02_規程・台帳"
mkdirp "${CORP_ROOT}/00_法人運営/03_経理・税務"
mkdirp "${CORP_ROOT}/00_法人運営/04_契約・法務"
mkdirp "${CORP_ROOT}/00_法人運営/05_人事・労務"

# 案件（自治体ごと）
mkdirp "${CORP_ROOT}/10_案件"

# 案件フォルダの雛形。新規自治体は _template をコピーして使う。
# 階層は SharePoint /sites/-10_ の既存構成に意図的に合わせてある。
for sub in \
  "00_プロジェクト管理" \
  "00_プロジェクト管理/01_WBS・スケジュール" \
  "00_プロジェクト管理/02_決定サマリー・議事録" \
  "00_プロジェクト管理/03_定例会議資料" \
  "10_受領・インプット資料" \
  "10_受領・インプット資料/01_市提供資料" \
  "10_受領・インプット資料/02_公開情報・他自治体事例" \
  "10_受領・インプット資料/03_中間事業者情報" \
  "10_受領・インプット資料/04_インタビュー記録" \
  "20_分析・作業" \
  "30_成果物" \
  "40_交渉・契約" \
  "90_アーカイブ"
do
  mkdirp "${CORP_ROOT}/10_案件/_template/${sub}"
done

# 実案件
mkdirp "${CORP_ROOT}/10_案件/takikawa_滝川市"
mkdirp "${CORP_ROOT}/10_案件/abashiri_網走市"

# サービス開発（案件横断の資産。ここが会社の中核資産になる）
mkdirp "${CORP_ROOT}/20_サービス開発"
mkdirp "${CORP_ROOT}/20_サービス開発/01_方法論・型"
mkdirp "${CORP_ROOT}/20_サービス開発/02_テンプレート"
mkdirp "${CORP_ROOT}/20_サービス開発/03_ナレッジ・調査"

mkdirp "${CORP_ROOT}/30_営業・提案"
mkdirp "${CORP_ROOT}/30_営業・提案/01_提案書"
mkdirp "${CORP_ROOT}/30_営業・提案/02_見積・契約雛形"
mkdirp "${CORP_ROOT}/30_営業・提案/03_リード管理"

mkdirp "${CORP_ROOT}/40_コード"
mkdirp "${CORP_ROOT}/90_アーカイブ"
mkdirp "${CORP_ROOT}/_sync"

# ---------------------------------------------------------------------------
# 2. 個人ルート
# ---------------------------------------------------------------------------

section "2. 個人ルート  ${PERSONAL_ROOT/#$HOME/\~}"

mkdirp "${PERSONAL_ROOT}"
mkdirp "${PERSONAL_ROOT}/10_案件"
mkdirp "${PERSONAL_ROOT}/20_学習・調査"
mkdirp "${PERSONAL_ROOT}/30_個人事業運営"
mkdirp "${PERSONAL_ROOT}/40_コード"
mkdirp "${PERSONAL_ROOT}/90_アーカイブ"
mkdirp "${PERSONAL_ROOT}/_sync"

# ---------------------------------------------------------------------------
# 3. 境界を明示する README（迷ったときの判断基準）
# ---------------------------------------------------------------------------

section "3. 境界ルールの明文化"

writef "${CORP_ROOT}/README.md" "# 株式会社ふもと — 法人ワークスペース

このディレクトリ配下は **すべて法人（株式会社ふもと）の資産** である。
個人事業のファイルをここに置かない。

## 正となる保管場所

| 種別 | 正 (source of truth) |
|---|---|
| 案件資料・法人文書 | SharePoint \`fumoto2026\` |
| コード | 法人 GitHub Organization |
| ローカル | このディレクトリ（作業用。正ではない） |

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

## 正となる保管場所

| 種別 | 正 (source of truth) |
|---|---|
| 資料 | Google Drive (${PERSONAL_EMAIL}) |
| コード | GitHub \`masa-takahashi-lab\` |
| ローカル | このディレクトリ（作業用。正ではない） |

## Git

このディレクトリ配下のコミットは自動的に以下の identity になる。

    ${PERSONAL_NAME} <${PERSONAL_EMAIL}>
"

# 滝川市は「法人へ移すが個人側にも残す」方針のため、
# どちらが正なのかをファイル自身に持たせて事故を防ぐ。
writef "${CORP_ROOT}/10_案件/takikawa_滝川市/_この案件の正はSharePointです.md" "# 滝川市案件 — 保管場所の正

**正 (source of truth): SharePoint \`/sites/-10_\` の
\`01_2026_ふるさと納税改革支援\`**

個人 Google Drive の \`滝川市向け資料\` にも同じ資料のコピーが存在するが、
あれは **参照用の複製であって正ではない**。

## 運用ルール

- 更新は必ず SharePoint 側に対して行う
- 個人 Drive 側のコピーは編集しない（編集すると二重管理が事故になる）
- 個人 Drive 側が不要になった時点でアーカイブし、この注意書きも消す

## 経緯

法人設立前に個人 Drive で進めていた案件を法人へ移管したもの。
移行リスクを避けるため個人側のコピーを当面残す判断をしている。
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
  skip "${GLOBAL_GITCONFIG/#$HOME/\~} の includeIf 設定"
  SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
else
  if [ "${DRY_RUN}" -eq 0 ]; then
    # 既存の ~/.gitconfig は保全してから追記する
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
  ok "${GLOBAL_GITCONFIG/#$HOME/\~} に includeIf を追記"
fi

# ---------------------------------------------------------------------------
# 5. クラウド同期先の検出とリンク
# ---------------------------------------------------------------------------

section "5. クラウド同期の分離"

CLOUD_DIR="${HOME}/Library/CloudStorage"

link_sync() {
  local target="$1"   # 同期実体
  local linkpath="$2" # 作るシンボリックリンク
  if [ -L "${linkpath}" ]; then
    skip "${linkpath/#$HOME/\~}"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  elif [ -e "${linkpath}" ]; then
    warn "${linkpath/#$HOME/\~} は既に実体として存在します。手動で確認してください。"
  else
    if [ "${DRY_RUN}" -eq 0 ]; then
      ln -s "${target}" "${linkpath}"
    fi
    CREATED_COUNT=$((CREATED_COUNT + 1))
    ok "${linkpath/#$HOME/\~}  ->  ${target/#$HOME/\~}"
  fi
}

if [ -d "${CLOUD_DIR}" ]; then
  FOUND_ANY=0

  # 法人: OneDrive / SharePoint
  for d in "${CLOUD_DIR}"/OneDrive-*; do
    [ -d "${d}" ] || continue
    FOUND_ANY=1
    base=$(basename "${d}")
    link_sync "${d}" "${CORP_ROOT}/_sync/${base}"
  done

  for d in "${CLOUD_DIR}"/SharePoint-*; do
    [ -d "${d}" ] || continue
    FOUND_ANY=1
    base=$(basename "${d}")
    link_sync "${d}" "${CORP_ROOT}/_sync/${base}"
  done

  # 個人: Google Drive
  for d in "${CLOUD_DIR}"/GoogleDrive-*; do
    [ -d "${d}" ] || continue
    FOUND_ANY=1
    base=$(basename "${d}")
    link_sync "${d}" "${PERSONAL_ROOT}/_sync/${base}"
  done

  if [ "${FOUND_ANY}" -eq 0 ]; then
    warn "~/Library/CloudStorage 配下に同期フォルダが見つかりませんでした。"
    info "OneDrive / Google Drive のデスクトップアプリが未設定の可能性があります。"
    info "同期アプリを設定後、このスクリプトを再実行するとリンクが作成されます。"
  fi
else
  warn "~/Library/CloudStorage が存在しません。"
  info "OneDrive / Google Drive のデスクトップアプリを先に設定してください。"
fi

# ---------------------------------------------------------------------------
# 6. 現状の棚卸し（移動はしない。報告のみ）
# ---------------------------------------------------------------------------

section "6. 現状の棚卸し — 仕分けが必要そうな既存フォルダ"

info "以下は「見つけた」だけです。移動も削除も行っていません。"
printf '\n'

scan_dir() {
  local dir="$1"
  local label="$2"
  [ -d "${dir}" ] || return 0

  local listing
  listing=$(find "${dir}" -maxdepth 1 -mindepth 1 -type d \
    ! -name '.*' \
    ! -name 'fumoto-inc' \
    ! -name 'personal' \
    2>/dev/null | sort || true)

  [ -n "${listing}" ] || return 0

  printf '  %s%s%s\n' "${C_BOLD}" "${label}" "${C_RESET}"
  printf '%s\n' "${listing}" | while IFS= read -r item; do
    printf '      %s\n' "${item/#$HOME/\~}"
  done
  printf '\n'
}

scan_dir "${HOME}" "ホーム直下"
scan_dir "${HOME}/Desktop" "デスクトップ"
scan_dir "${HOME}/Documents" "書類"
scan_dir "${HOME}/Developer" "Developer"
scan_dir "${HOME}/src" "src"
scan_dir "${HOME}/ghq" "ghq"

# git リポジトリのうち、まだ新ルートの外にあるもの
printf '  %s新ルート外にある Git リポジトリ%s\n' "${C_BOLD}" "${C_RESET}"
REPO_LIST=$(find "${HOME}/Desktop" "${HOME}/Documents" "${HOME}/Developer" "${HOME}/src" \
  -maxdepth 3 -type d -name '.git' 2>/dev/null | sed 's|/\.git$||' | sort || true)
if [ -n "${REPO_LIST}" ]; then
  printf '%s\n' "${REPO_LIST}" | while IFS= read -r repo; do
    remote=$(git -C "${repo}" remote get-url origin 2>/dev/null || echo '(remote なし)')
    printf '      %s\n' "${repo/#$HOME/\~}"
    printf '        %s%s%s\n' "${C_DIM}" "${remote}" "${C_RESET}"
  done
else
  printf '      %s(見つかりませんでした)%s\n' "${C_DIM}" "${C_RESET}"
fi

# ---------------------------------------------------------------------------
# 完了
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

  2. 上の「棚卸し」に出たフォルダを、法人 / 個人 のどちらかに手で振り分ける

  3. 法人用 GitHub Organization を作成し、会社のコードを移す
     ${C_DIM}詳細は docs/workspace-separation.md を参照${C_RESET}

EOF
fi
