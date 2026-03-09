#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKS_FILE="$SCRIPT_DIR/links.json"

# ── 色 ──────────────────────────────────
BOLD="\033[1m"; DIM="\033[2m"; RESET="\033[0m"
CYAN="\033[36m"; GREEN="\033[32m"; RED="\033[31m"; YELLOW="\033[33m"

header() {
  clear
  echo -e "${BOLD}${CYAN}  MyURL${RESET}  ${DIM}$(python3 -c "import json; d=json.load(open('$LINKS_FILE')); print(str(len(d['links'])) + ' 件')" 2>/dev/null)${RESET}"
  echo -e "${DIM}  ──────────────────────────────────${RESET}"
}

# ── git commit & push ────────────────────
git_save() {
  local msg="$1" no_push="${2:-false}"
  cd "$SCRIPT_DIR"
  if ! git status --porcelain "$LINKS_FILE" 2>/dev/null | grep -q .; then return; fi
  git add "$LINKS_FILE"
  git commit -m "$msg" -q
  if [[ "$no_push" == false ]]; then
    echo -e "${DIM}  pushing...${RESET}"
    git push -q
    echo -e "${GREEN}  ✓ 保存・デプロイ完了${RESET}"
  else
    echo -e "${GREEN}  ✓ 保存完了（push スキップ）${RESET}"
  fi
}

# ── リンク一覧を配列で取得 ───────────────
get_links_display() {
  python3 - <<'PYEOF'
import json
with open("LINKS_FILE_PH", encoding="utf-8") as f:
    links = json.load(f)["links"]
for i, l in enumerate(links):
    cat  = l.get("category","未分類")[:10]
    title = l.get("title","")[:28]
    host = ""
    try:
        from urllib.parse import urlparse
        host = urlparse(l.get("url","")).hostname or ""
        host = host.replace("www.","")[:30]
    except: pass
    print(f"{i+1:3}  {cat:<11} {title:<28}  {host}")
PYEOF
}

# ── リンク選択（fzf or 番号入力）──────────
pick_link() {
  local prompt="${1:-選択}"
  local lines
  lines=$(python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f:
    links = json.load(f)["links"]
for i, l in enumerate(links):
    cat  = l.get("category","未分類")[:10]
    title = l.get("title","")[:28]
    try:
        from urllib.parse import urlparse
        host = urlparse(l.get("url","")).hostname or ""
        host = host.replace("www.","")[:30]
    except: host = ""
    print(f"{i+1:3}  {cat:<11} {title:<28}  {host}")
PYEOF
)

  if command -v fzf &>/dev/null; then
    SELECTED=$(echo "$lines" | fzf --prompt="$prompt > " --height=40% --reverse --no-info)
    NUM=$(echo "$SELECTED" | awk '{print $1}')
  else
    echo ""
    echo -e "${DIM}$lines${RESET}"
    echo ""
    read -rp "  番号を入力: " NUM
  fi
  echo "$NUM"
}

# ════════════════════════════════════════
# ADD
# ════════════════════════════════════════
cmd_add() {
  header
  echo -e "${BOLD}  ＋ リンクを追加${RESET}"
  echo ""

  # URL
  read -rp "  URL: " URL
  [[ -z "$URL" ]] && { echo "  キャンセル"; return; }
  [[ "$URL" != http://* && "$URL" != https://* ]] && URL="https://$URL"

  # タイトル自動取得
  echo -e "  ${DIM}タイトルを取得中...${RESET}"
  FETCHED=$(curl -s --max-time 5 -L "$URL" 2>/dev/null \
    | grep -i '<title' | head -1 \
    | sed 's/.*<title[^>]*>//I; s/<\/title>.*//I; s/^[[:space:]]*//; s/[[:space:]]*$//' \
    | tr -d '\r\n' || true)
  [[ -n "$FETCHED" ]] && echo -e "  ${DIM}取得: $FETCHED${RESET}"
  read -rp "  タイトル${FETCHED:+ [$FETCHED]}: " TITLE
  TITLE="${TITLE:-$FETCHED}"
  [[ -z "$TITLE" ]] && TITLE="$URL"

  # カテゴリ（既存を表示）
  CATS=$(python3 -c "
import json
with open('$LINKS_FILE') as f: d=json.load(f)
cats=sorted(set(l.get('category','未分類') for l in d.get('links',[])))
print(', '.join(cats))" 2>/dev/null || true)
  [[ -n "$CATS" ]] && echo -e "  ${DIM}既存: $CATS${RESET}"
  read -rp "  カテゴリ [未分類]: " CATEGORY
  CATEGORY="${CATEGORY:-未分類}"

  # 保存
  python3 - <<PYEOF
import json, time
with open("$LINKS_FILE", encoding="utf-8") as f: data=json.load(f)
from datetime import datetime, timezone
data["links"].append({
    "id": str(int(time.time())),
    "title": """$TITLE""",
    "url": "$URL",
    "category": """$CATEGORY""",
    "createdAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
})
with open("$LINKS_FILE", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2); f.write("\n")
PYEOF

  echo ""
  git_save "add: $TITLE"
  echo ""
  read -rp "  Enterで戻る" _
}

# ════════════════════════════════════════
# DELETE
# ════════════════════════════════════════
cmd_delete() {
  header
  echo -e "${BOLD}  － リンクを削除${RESET}"

  NUM=$(pick_link "削除するリンクを選択")
  [[ -z "$NUM" ]] && return

  INFO=$(python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f: data=json.load(f)
l=data["links"][int("$NUM")-1]
print(l.get("title","") + "  (" + l.get("url","") + ")")
PYEOF
)
  echo ""
  echo -e "  ${YELLOW}削除: $INFO${RESET}"
  read -rp "  本当に削除しますか？ [y/N]: " CONFIRM
  [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { echo "  キャンセル"; sleep 1; return; }

  TITLE=$(python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f: data=json.load(f)
links=data["links"]
removed=links.pop(int("$NUM")-1)
data["links"]=links
with open("$LINKS_FILE","w",encoding="utf-8") as f:
    json.dump(data,f,ensure_ascii=False,indent=2); f.write("\n")
print(removed.get("title",""))
PYEOF
)
  echo ""
  git_save "delete: $TITLE"
  echo ""
  read -rp "  Enterで戻る" _
}

# ════════════════════════════════════════
# UPDATE
# ════════════════════════════════════════
cmd_update() {
  header
  echo -e "${BOLD}  ✎  リンクを更新${RESET}"

  NUM=$(pick_link "更新するリンクを選択")
  [[ -z "$NUM" ]] && return

  # 現在の値を取得
  eval "$(python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f: data=json.load(f)
l=data["links"][int("$NUM")-1]
print("CUR_TITLE=" + repr(l.get("title","")))
print("CUR_URL="   + repr(l.get("url","")))
print("CUR_CAT="   + repr(l.get("category","")))
PYEOF
)"

  echo ""
  echo -e "  ${DIM}変更しない項目はそのままEnter${RESET}"
  echo ""
  read -rp "  タイトル  [$CUR_TITLE]: " NEW_TITLE
  read -rp "  URL       [$CUR_URL]: "   NEW_URL
  read -rp "  カテゴリ  [$CUR_CAT]: "  NEW_CAT

  TITLE=$(python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f: data=json.load(f)
l=data["links"][int("$NUM")-1]
if "$NEW_TITLE": l["title"]    = "$NEW_TITLE"
if "$NEW_URL":   l["url"]      = "$NEW_URL"
if "$NEW_CAT":   l["category"] = "$NEW_CAT"
with open("$LINKS_FILE","w",encoding="utf-8") as f:
    json.dump(data,f,ensure_ascii=False,indent=2); f.write("\n")
print(l["title"])
PYEOF
)
  echo ""
  git_save "update: $TITLE"
  echo ""
  read -rp "  Enterで戻る" _
}

# ════════════════════════════════════════
# LIST
# ════════════════════════════════════════
cmd_list() {
  header
  python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f:
    links=json.load(f)["links"]
prev_cat=""
for i,l in enumerate(links):
    cat=l.get("category","未分類")
    if cat!=prev_cat:
        print(f"\n  \033[2m{cat}\033[0m")
        prev_cat=cat
    title=l.get("title","")[:32]
    try:
        from urllib.parse import urlparse
        host=urlparse(l.get("url","")).hostname or ""
        host=host.replace("www.","")
    except: host=""
    print(f"  {i+1:3}.  {title:<32}  \033[2m{host}\033[0m")
print(f"\n  合計: {len(links)} 件")
PYEOF
  echo ""
  read -rp "  Enterで戻る" _
}

# ════════════════════════════════════════
# MAIN MENU
# ════════════════════════════════════════
while true; do
  header
  echo ""
  echo -e "  ${BOLD}a${RESET}  追加"
  echo -e "  ${BOLD}d${RESET}  削除"
  echo -e "  ${BOLD}u${RESET}  更新"
  echo -e "  ${BOLD}l${RESET}  一覧"
  echo -e "  ${BOLD}q${RESET}  終了"
  echo ""
  read -rp "  > " KEY

  case "$KEY" in
    a|A) cmd_add ;;
    d|D) cmd_delete ;;
    u|U) cmd_update ;;
    l|L) cmd_list ;;
    q|Q) clear; exit 0 ;;
    *) ;;
  esac
done
