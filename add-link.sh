#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKS_FILE="$SCRIPT_DIR/links.json"

usage() {
  cat <<EOF
使い方:
  $(basename "$0") [オプション]

オプション:
  -u, --url URL           追加するURL（必須）
  -t, --title タイトル    リンクのタイトル（省略時はURLから自動取得）
  -c, --category カテゴリ カテゴリ名（省略時: 未分類）
  -d, --desc 説明         説明文（省略可）
  --no-push               git push をスキップする
  -h, --help              このヘルプを表示

例:
  $(basename "$0") -u https://github.com -t GitHub -c 開発
  $(basename "$0") -u https://example.com -t "Example" -c Web -d "サンプルサイト"
EOF
  exit 0
}

# デフォルト値
URL=""
TITLE=""
CATEGORY="未分類"
DESC=""
NO_PUSH=false

# 引数パース
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

# URLが指定されていない場合はインタラクティブに入力
if [[ -z "$URL" ]]; then
  read -rp "URL: " URL
fi

if [[ -z "$URL" ]]; then
  echo "エラー: URLは必須です。" >&2
  exit 1
fi

# URLにスキームがなければ補完
if [[ "$URL" != http://* && "$URL" != https://* ]]; then
  URL="https://$URL"
fi

# タイトルが未指定なら入力を促す
if [[ -z "$TITLE" ]]; then
  # curlでタイトルを自動取得（失敗したらURLを使用）
  echo "タイトルを取得中..." >&2
  FETCHED_TITLE=$(curl -s --max-time 5 -L "$URL" 2>/dev/null \
    | grep -i '<title' \
    | head -1 \
    | sed 's/.*<title[^>]*>//I; s/<\/title>.*//I' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | tr -d '\r\n' \
    || true)

  if [[ -n "$FETCHED_TITLE" ]]; then
    echo "取得したタイトル: $FETCHED_TITLE" >&2
    read -rp "タイトル [$FETCHED_TITLE]: " INPUT_TITLE
    TITLE="${INPUT_TITLE:-$FETCHED_TITLE}"
  else
    read -rp "タイトル: " TITLE
  fi
fi

if [[ -z "$TITLE" ]]; then
  TITLE="$URL"
fi

# カテゴリとの説明をインタラクティブに（引数未指定なら）
if [[ "$CATEGORY" == "未分類" ]]; then
  # 既存カテゴリを表示
  if command -v python3 &>/dev/null; then
    EXISTING=$(python3 -c "
import json, sys
with open('$LINKS_FILE') as f:
    data = json.load(f)
cats = sorted(set(l.get('category','未分類') for l in data.get('links',[])))
if cats:
    print('既存カテゴリ: ' + ', '.join(cats))
" 2>/dev/null || true)
    [[ -n "$EXISTING" ]] && echo "$EXISTING" >&2
  fi
  read -rp "カテゴリ [未分類]: " INPUT_CAT
  CATEGORY="${INPUT_CAT:-未分類}"
fi

if [[ -z "$DESC" ]]; then
  read -rp "説明（省略可）: " DESC
fi

# IDを生成（タイムスタンプベース）
ID=$(date +%s)

# Python3でJSONに追加
python3 - <<PYEOF
import json, sys

links_file = "$LINKS_FILE"
with open(links_file, 'r', encoding='utf-8') as f:
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

with open(links_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')

print(f"追加しました: {new_link['title']} ({new_link['url']})")
PYEOF

# git commit & push
cd "$SCRIPT_DIR"

if ! git status --porcelain "$LINKS_FILE" 2>/dev/null | grep -q .; then
  echo "変更なし。スキップ。"
  exit 0
fi

git add "$LINKS_FILE"
git commit -m "add: $TITLE"

if [[ "$NO_PUSH" == false ]]; then
  echo "GitHubへプッシュ中..." >&2
  git push
  echo "完了。GitHub Pagesに反映されるまで数分かかる場合があります。" >&2
else
  echo "コミット済み（push はスキップ）。" >&2
fi
