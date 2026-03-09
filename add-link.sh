#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKS_FILE="$SCRIPT_DIR/links.json"

usage() {
  cat <<EOF
使い方:
  $(basename "$0") [サブコマンド] [オプション]

サブコマンド:
  add (デフォルト)  リンクを追加する
  delete            リンクを削除する
  update            リンクを更新する
  list              リンク一覧を表示する

add オプション:
  -u, --url URL           追加するURL（必須）
  -t, --title タイトル    タイトル（省略時は自動取得）
  -c, --category カテゴリ カテゴリ（省略時: 未分類）
  -d, --desc 説明         説明文（省略可）
  --no-push               git push をスキップ

例:
  $(basename "$0") -u https://github.com -t GitHub -c 開発
  $(basename "$0") delete
  $(basename "$0") update
  $(basename "$0") list
EOF
  exit 0
}

# git commit & push
git_commit_push() {
  local msg="$1"
  local no_push="${2:-false}"
  cd "$SCRIPT_DIR"
  if ! git status --porcelain "$LINKS_FILE" 2>/dev/null | grep -q .; then
    echo "変更なし。スキップ。"
    return
  fi
  git add "$LINKS_FILE"
  git commit -m "$msg"
  if [[ "$no_push" == false ]]; then
    echo "GitHubへプッシュ中..." >&2
    git push
    echo "完了。" >&2
  else
    echo "コミット済み（push はスキップ）。" >&2
  fi
}

# リンク選択（fzf があれば使う、なければ番号選択）
select_link() {
  local prompt="${1:-選択}"
  python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f:
    data = json.load(f)
links = data.get("links", [])
for i, l in enumerate(links):
    print(f"{i+1:3}. [{l.get('category','未分類'):12}] {l.get('title','')[:30]:30}  {l.get('url','')[:50]}")
PYEOF
  echo ""
  read -rp "${prompt}（番号）: " NUM
  echo "$NUM"
}

# ── サブコマンド判定 ──
SUBCMD="add"
NO_PUSH=false
if [[ $# -gt 0 ]]; then
  case "$1" in
    add|delete|update|list) SUBCMD="$1"; shift ;;
    -h|--help) usage ;;
  esac
fi

# ════════════════════════════════
# list
# ════════════════════════════════
if [[ "$SUBCMD" == "list" ]]; then
  python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f:
    data = json.load(f)
links = data.get("links", [])
print(f"{'#':>3}  {'カテゴリ':<14} {'タイトル':<30}  URL")
print("-" * 90)
for i, l in enumerate(links):
    print(f"{i+1:3}.  {l.get('category','未分類'):<14} {l.get('title','')[:28]:<30}  {l.get('url','')[:50]}")
print(f"\n合計: {len(links)} 件")
PYEOF
  exit 0
fi

# ════════════════════════════════
# delete
# ════════════════════════════════
if [[ "$SUBCMD" == "delete" ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-push) NO_PUSH=true; shift ;;
      *) shift ;;
    esac
  done

  echo "── 削除するリンクを選択 ──"
  select_link "削除する番号" > /tmp/_myurl_sel.txt
  NUM=$(tail -1 /tmp/_myurl_sel.txt)

  RESULT=$(python3 - <<PYEOF
import json, sys
with open("$LINKS_FILE", encoding="utf-8") as f:
    data = json.load(f)
links = data.get("links", [])
idx = int("$NUM") - 1
if idx < 0 or idx >= len(links):
    print("ERROR: 無効な番号です")
    sys.exit(1)
removed = links.pop(idx)
data["links"] = links
with open("$LINKS_FILE", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(f"削除しました: {removed['title']} ({removed['url']})")
PYEOF
)
  echo "$RESULT"
  TITLE=$(echo "$RESULT" | sed 's/削除しました: \(.*\) (.*/\1/')
  git_commit_push "delete: $TITLE" "$NO_PUSH"
  exit 0
fi

# ════════════════════════════════
# update
# ════════════════════════════════
if [[ "$SUBCMD" == "update" ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-push) NO_PUSH=true; shift ;;
      *) shift ;;
    esac
  done

  echo "── 更新するリンクを選択 ──"
  select_link "更新する番号" > /tmp/_myurl_sel.txt
  NUM=$(tail -1 /tmp/_myurl_sel.txt)

  # 現在の値を表示
  python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f:
    data = json.load(f)
links = data.get("links", [])
idx = int("$NUM") - 1
l = links[idx]
print(f"  タイトル  : {l.get('title','')}")
print(f"  URL       : {l.get('url','')}")
print(f"  カテゴリ  : {l.get('category','')}")
print(f"  説明      : {l.get('description','')}")
PYEOF

  echo ""
  echo "（変更しない項目はそのままEnter）"
  read -rp "タイトル: " NEW_TITLE
  read -rp "URL: "      NEW_URL
  read -rp "カテゴリ: " NEW_CAT
  read -rp "説明: "     NEW_DESC

  python3 - <<PYEOF
import json
with open("$LINKS_FILE", encoding="utf-8") as f:
    data = json.load(f)
links = data.get("links", [])
idx = int("$NUM") - 1
l = links[idx]
if "$NEW_TITLE": l["title"]       = "$NEW_TITLE"
if "$NEW_URL":   l["url"]         = "$NEW_URL"
if "$NEW_CAT":   l["category"]    = "$NEW_CAT"
if "$NEW_DESC":  l["description"] = "$NEW_DESC"
data["links"] = links
with open("$LINKS_FILE", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(f"更新しました: {l['title']} ({l['url']})")
PYEOF

  git_commit_push "update: $(python3 -c "import json; d=json.load(open('$LINKS_FILE')); print(d['links'][int('$NUM')-1]['title'])")" "$NO_PUSH"
  exit 0
fi

# ════════════════════════════════
# add（デフォルト）
# ════════════════════════════════
URL=""
TITLE=""
CATEGORY="未分類"
DESC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url)      URL="$2";      shift 2 ;;
    -t|--title)    TITLE="$2";    shift 2 ;;
    -c|--category) CATEGORY="$2"; shift 2 ;;
    -d|--desc)     DESC="$2";     shift 2 ;;
    --no-push)     NO_PUSH=true;  shift ;;
    -h|--help)     usage ;;
    *) echo "不明なオプション: $1" >&2; usage ;;
  esac
done

if [[ -z "$URL" ]]; then
  read -rp "URL: " URL
fi
if [[ -z "$URL" ]]; then
  echo "エラー: URLは必須です。" >&2; exit 1
fi
if [[ "$URL" != http://* && "$URL" != https://* ]]; then
  URL="https://$URL"
fi

if [[ -z "$TITLE" ]]; then
  echo "タイトルを取得中..." >&2
  FETCHED_TITLE=$(curl -s --max-time 5 -L "$URL" 2>/dev/null \
    | grep -i '<title' | head -1 \
    | sed 's/.*<title[^>]*>//I; s/<\/title>.*//I' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | tr -d '\r\n' || true)
  if [[ -n "$FETCHED_TITLE" ]]; then
    echo "取得したタイトル: $FETCHED_TITLE" >&2
    read -rp "タイトル [$FETCHED_TITLE]: " INPUT_TITLE
    TITLE="${INPUT_TITLE:-$FETCHED_TITLE}"
  else
    read -rp "タイトル: " TITLE
  fi
fi
[[ -z "$TITLE" ]] && TITLE="$URL"

if [[ "$CATEGORY" == "未分類" ]]; then
  EXISTING=$(python3 -c "
import json
with open('$LINKS_FILE') as f:
    data = json.load(f)
cats = sorted(set(l.get('category','未分類') for l in data.get('links',[])))
if cats: print('既存カテゴリ: ' + ', '.join(cats))
" 2>/dev/null || true)
  [[ -n "$EXISTING" ]] && echo "$EXISTING" >&2
  read -rp "カテゴリ [未分類]: " INPUT_CAT
  CATEGORY="${INPUT_CAT:-未分類}"
fi

[[ -z "$DESC" ]] && read -rp "説明（省略可）: " DESC

ID=$(date +%s)

python3 - <<PYEOF
import json
with open("$LINKS_FILE", "r", encoding="utf-8") as f:
    data = json.load(f)
new_link = {
    "id": "$ID",
    "title": """$TITLE""",
    "url": "$URL",
    "category": """$CATEGORY""",
    "description": """$DESC""",
    "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
data["links"].append(new_link)
with open("$LINKS_FILE", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(f"追加しました: {new_link['title']} ({new_link['url']})")
PYEOF

git_commit_push "add: $TITLE" "$NO_PUSH"
