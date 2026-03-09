# MyURL

自分用のリンク集サイト。GitHub Pages で公開し、ターミナルからリンクを管理する。

## 使い方

```bash
./add-link.sh
```

起動するとメニューが表示される。

```
  a  追加
  d  削除
  u  更新
  l  一覧
  q  終了
```

| 操作 | 流れ |
|---|---|
| 追加 | URL → タイトル自動取得 → カテゴリ・説明を入力 |
| 削除 | 一覧から番号選択 → 確認 |
| 更新 | 一覧から番号選択 → 変更する項目だけ入力（Enterでスキップ） |
| 一覧 | カテゴリ別で全件表示 |

操作後は自動で `git commit & push` → GitHub Pages にデプロイされる。

`fzf` をインストールすると削除・更新の選択がファジー検索になる。

```bash
brew install fzf
```

## ローカルで確認する

```bash
python3 -m http.server 3000
```

ブラウザで http://localhost:3000 を開く。

## GitHub Pages の初期設定

1. このリポジトリを GitHub に push する
2. **Settings → Pages** で Source を `GitHub Actions` に設定する

## 構成

```
MyURL/
├── index.html              # サイト本体
├── links.json              # リンクデータ
├── add-link.sh             # CLIスクリプト
└── .github/workflows/
    └── deploy.yml          # GitHub Pages 自動デプロイ
```
