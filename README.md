# MyURL

自分用のリンク集サイト。GitHub Pages で公開し、ターミナルからリンクを管理する。

## 使い方

### リンクを追加する

**対話モード（引数なし）:**
```bash
./add-link.sh
```

**引数指定モード:**
```bash
./add-link.sh -u <URL> -t <タイトル> -c <カテゴリ> -d <説明>
```

| オプション | 説明 |
|---|---|
| `-u`, `--url` | 追加する URL（必須） |
| `-t`, `--title` | タイトル（省略時は自動取得） |
| `-c`, `--category` | カテゴリ（省略時: 未分類） |
| `-d`, `--desc` | 説明文（省略可） |
| `--no-push` | git push をスキップ |

実行すると `links.json` に追記し、自動で `git commit & push` → GitHub Pages にデプロイされる。

### ローカルで確認する

```bash
python3 -m http.server 3000
```

ブラウザで http://localhost:3000 を開く。

## GitHub Pages の初期設定

1. このリポジトリを GitHub に push する
2. GitHub リポジトリの **Settings → Pages** で Source を `GitHub Actions` に設定する

## 構成

```
MyURL/
├── index.html              # サイト本体（ダークテーマ・カテゴリ別・検索付き）
├── links.json              # リンクデータ
├── add-link.sh             # CLIスクリプト
└── .github/workflows/
    └── deploy.yml          # GitHub Pages 自動デプロイ
```
