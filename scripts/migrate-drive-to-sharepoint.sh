#!/usr/bin/env bash
#
# migrate-drive-to-sharepoint.sh
#
# 個人 Google Drive にしかない滝川市案件の資料を、法人 SharePoint へ移行する。
#
# なぜローカルコピーなのか:
#   API 経由の移行は 1 MiB のアップロード上限があり分割もできないため、
#   提案書などの大きいファイルが原理的に移せない。
#   Mac には Google Drive と OneDrive が両方同期されているので、
#   ローカルのファイルコピーであればサイズ無制限かつ破損なく移行できる。
#
# 前提:
#   - Google Drive for desktop が同期済み
#   - SharePoint の 100_滝川市 が OneDrive にショートカット追加済み
#   - setup-workspace.sh 実行済み（~/fumoto-inc, ~/personal のリンクがある）
#
# 安全性:
#   - コピーのみ。Google Drive 側は一切変更しない（削除も移動もしない）
#   - 移行先に同名ファイルが既にある場合はスキップする（上書きしない）
#   - 何度実行しても結果が変わらない（冪等）
#
# 使い方:
#   bash migrate-drive-to-sharepoint.sh --dry-run   # 確認（コピーしない）
#   bash migrate-drive-to-sharepoint.sh             # 実行

set -euo pipefail

# ---------------------------------------------------------------------------
# 設定 — 環境に合わせて書き換える
# ---------------------------------------------------------------------------

# Google Drive 側の「滝川市向け資料」フォルダ
SRC_ROOT="${DRIVE_SRC:-}"

# SharePoint 100_滝川市 の同期先
DST_ROOT="${SP_DST:-}"

# 案件フォルダ（100_滝川市 直下）
PROJ="01_2026_ふるさと納税改革支援"

# ---------------------------------------------------------------------------

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_RED=$'\033[31m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_RED=''
fi

section() { printf '\n%s%s%s\n' "${C_BOLD}${C_BLUE}" "$1" "${C_RESET}"; }
warn()    { printf '  %s!%s %s\n' "${C_YELLOW}" "${C_RESET}" "$1"; }
info()    { printf '    %s%s%s\n' "${C_DIM}" "$1" "${C_RESET}"; }

COPIED=0; SKIPPED=0; MISSING=0

# ---------------------------------------------------------------------------
# 同期フォルダの自動検出
# ---------------------------------------------------------------------------

CLOUD="${HOME}/Library/CloudStorage"

autodetect() {
  # Google Drive 側
  if [ -z "${SRC_ROOT}" ]; then
    local hit
    hit=$(find "${CLOUD}" -maxdepth 4 -type d -name '滝川市向け資料' 2>/dev/null | head -1 || true)
    [ -n "${hit}" ] && SRC_ROOT="${hit}"
  fi
  # SharePoint 側（100_滝川市）
  if [ -z "${DST_ROOT}" ]; then
    local hit
    hit=$(find "${CLOUD}" -maxdepth 4 -type d -name '100_滝川市*' 2>/dev/null | head -1 || true)
    [ -z "${hit}" ] && hit=$(find "${CLOUD}" -maxdepth 4 -type d -name '*滝川市*' \
      ! -name '滝川市向け資料' 2>/dev/null | head -1 || true)
    [ -n "${hit}" ] && DST_ROOT="${hit}"
  fi
}

autodetect

section "移行元 / 移行先"

if [ -z "${SRC_ROOT}" ] || [ ! -d "${SRC_ROOT}" ]; then
  printf '  %s移行元が見つかりません%s\n' "${C_RED}" "${C_RESET}"
  info "Google Drive for desktop が同期されているか確認してください。"
  info "手動指定: DRIVE_SRC=/path/to/滝川市向け資料 bash $0"
  exit 1
fi
printf '  移行元: %s\n' "${SRC_ROOT/#$HOME/\~}"

if [ -z "${DST_ROOT}" ] || [ ! -d "${DST_ROOT}" ]; then
  printf '  %s移行先が見つかりません%s\n' "${C_RED}" "${C_RESET}"
  info "SharePoint の 100_滝川市 を OneDrive にショートカット追加してください。"
  info "手動指定: SP_DST=/path/to/100_滝川市 bash $0"
  exit 1
fi
printf '  移行先: %s\n' "${DST_ROOT/#$HOME/\~}"

# ---------------------------------------------------------------------------
# 1ファイルを移行する
#   $1 = 移行元の相対パス（SRC_ROOT から）
#   $2 = 移行先の相対パス（DST_ROOT から。ディレクトリ）
# ---------------------------------------------------------------------------

migrate() {
  local rel_src="$1" rel_dst="$2"
  local src="${SRC_ROOT}/${rel_src}"
  local base; base=$(basename "${rel_src}")
  local dstdir="${DST_ROOT}/${rel_dst}"
  local dst="${dstdir}/${base}"

  if [ ! -f "${src}" ]; then
    MISSING=$((MISSING + 1))
    warn "見つかりません: ${rel_src}"
    return 0
  fi

  if [ -f "${dst}" ]; then
    SKIPPED=$((SKIPPED + 1))
    printf '  %s=%s %s %s(移行先に既存)%s\n' "${C_DIM}" "${C_RESET}" "${base}" "${C_DIM}" "${C_RESET}"
    return 0
  fi

  if [ "${DRY_RUN}" -eq 0 ]; then
    mkdir -p "${dstdir}"
    # -n: 既存を上書きしない / -p: タイムスタンプを保持
    cp -np "${src}" "${dst}"
  fi
  COPIED=$((COPIED + 1))
  printf '  %s+%s %s\n' "${C_GREEN}" "${C_RESET}" "${base}"
  info "-> ${rel_dst}/"
}

# ---------------------------------------------------------------------------
# 移行マッピング
#
# 移行先は SharePoint の実構造（2026-08-16 全走査で確認）に合わせている。
# 社内文書「フォルダ構成と運用ルール 第4版」の記載とは一部異なるが、
# 実物を正としている。
# ---------------------------------------------------------------------------

section "議事録・会議メモ  ->  00_プロジェクト管理/02_決定サマリー・議事録"

MTG="${PROJ}/00_プロジェクト管理/02_決定サマリー・議事録"
migrate "打ち合わせメモ/260714_滝川市_打合せ議事録_中間事業者最適化契約協議.docx" "${MTG}"
migrate "打ち合わせメモ/滝川市_会議メモ_20260604.docx" "${MTG}"
migrate "打ち合わせメモ/滝川市_会議メモ_20260428.docx" "${MTG}"
migrate "打ち合わせメモ/滝川市_会議メモ_20260304.docx" "${MTG}"

section "市提供資料  ->  10_受領・インプット資料/01_市提供資料"

migrate "滝川市受領資料/経費構成比.xlsx" "${PROJ}/10_受領・インプット資料/01_市提供資料"

section "納品物  ->  20_納品物（市へ提出）"

DELIV="${PROJ}/20_納品物（市へ提出）"
migrate "260714_滝川市ふるさと納税改革支援 ご提案書_Final.pptx" "${DELIV}"
migrate "01_Delivery/10_納品物（市へ提出）/P0_キックオフ・合意形成/滝川市ふるさと納税改革_キックオフ資料_v01.pptx" "${DELIV}"

section "中間事業者対応  ->  30_中間事業者対応（RFI・RFP）"

RFI="${PROJ}/30_中間事業者対応（RFI・RFP）"
migrate "01_Delivery/20_事業者対応（RFI・RFP）/21_発出文書/RFIドラフト_v.1.docx" "${RFI}"
migrate "01_Delivery/10_納品物（市へ提出）/P1_交渉窓口の設置とRFI発出/滝川市_中間事業者_RFI発出先候補企業リスト_1.pptx" "${RFI}"
migrate "01_Delivery/10_納品物（市へ提出）/P1_交渉窓口の設置とRFI発出/滝川市_中間事業者_候補企業比較表_1.xlsx" "${RFI}"

section "契約  ->  40_交渉"

migrate "契約書/滝川市_ふるさと納税中間事業者選定支援業務委託契約書_ひな型.docx" "${PROJ}/40_交渉"

section "旧版・作業資料  ->  90_アーカイブ"

ARC="${PROJ}/90_アーカイブ"
migrate "260617_滝川市ふるさと納税改革支援 ご提案書_v5.3.pptx" "${ARC}"
migrate "260617_滝川市ふるさと納税改革支援 ご提案書_v5.2.pptx" "${ARC}"
migrate "260617_滝川市ふるさと納税改革支援 ご提案書_v5.1.pptx" "${ARC}"
migrate "Work/Estimation Sheet_20260317.xlsx" "${ARC}"
migrate "Work/滝川市比較資料.xlsx" "${ARC}"

# ---------------------------------------------------------------------------
# 手動対応が必要なもの
# ---------------------------------------------------------------------------

section "手動対応が必要なもの"

cat <<EOF
  ${C_BOLD}Google ネイティブ形式（.gdoc）— 同期フォルダには実体がない${C_RESET}

    打ち合わせメモ/滝川市訪問　メモ
    01_Delivery/00_README_フォルダ運用ルール

  ブラウザで開き「ファイル > ダウンロード > Word (.docx)」で書き出してから、
  それぞれ 02_決定サマリー・議事録 と 90_アーカイブ へ置いてください。
  （後者は SharePoint 版の運用ルールに置き換わっているため、移行不要の判断も可）

  ${C_BOLD}置き場が未確定のもの${C_RESET}

    00_Admin/05_情報システム(IT基盤)/Microsoft365_導入プラン_内部検討用.pptx

  運用ルール第4版が定める 006_IT・アカウント チャネルが未作成のため保留。
  チャネルを作成してから移してください。

  ${C_BOLD}移行不要（SharePoint に既にあります）${C_RESET}

    滝川市受領資料/回答_20260513.docx      -> 01_市提供資料/回答_20260513 (1).docx
    滝川市受領資料/契約書.docx              -> 01_市提供資料/契約書 (1).docx
    260617_覚書                             -> 01_市提供資料/260617_覚書.docx
    Brand Assets/ の3点                     -> 親チーム 005_ブランドアセット/
    00_Admin/ の規程類（A/B/C/D/Z系列）     -> 親チーム 002・003・004・001

EOF

# ---------------------------------------------------------------------------

section "完了"

printf '  コピー: %s%s%s 件 / 既存のためスキップ: %s%s%s 件 / 見つからず: %s%s%s 件\n' \
  "${C_GREEN}" "${COPIED}" "${C_RESET}" \
  "${C_DIM}" "${SKIPPED}" "${C_RESET}" \
  "${C_YELLOW}" "${MISSING}" "${C_RESET}"

if [ "${DRY_RUN}" -eq 1 ]; then
  printf '\n%s\n' "${C_YELLOW}${C_BOLD}[DRY RUN] 実際にはコピーしていません。${C_RESET}"
  printf '%s\n' "本番実行: ${C_BOLD}bash migrate-drive-to-sharepoint.sh${C_RESET}"
else
  cat <<EOF

${C_BOLD}移行後の確認${C_RESET}

  1. OneDrive の同期が完了するまで待つ（メニューバーのアイコンが緑になるまで）
  2. ブラウザで SharePoint を開き、ファイルが見えることを確認する
  3. 確認できたら Google Drive 側の扱いを決める

     運用ルール第4版「二重管理の禁止 — SharePoint を唯一の正とする」に従うなら、
     Google Drive 側は削除するのが本来の姿です。
     このスクリプトは削除を行いません（判断が必要なため）。

EOF
fi
