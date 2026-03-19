# GitHub へのプッシュ・更新手順

このプロジェクトは WSL 上にあるため、**WSL のターミナル**（Ubuntu など）で以下を実行してください。

---

## 既に GitHub にリポジトリがある場合（ダウンロードしたものを更新）

前にダウンロードしたリポジトリを、いまの最新コードで更新する手順です。

```bash
cd ~/Claude-Code-Communication/tiktok-comment-dashboard

# 変更をすべてステージ
git add .

# コミット（更新内容に合わせてメッセージは変えてOK）
git commit -m "feat: ADB自動コメント投稿・送信モード切替を追加"

# まだリモートを追加していない場合だけ実行（1回だけ）
# git remote add origin https://github.com/あなたのユーザー名/tiktok-comment-dashboard.git

# ブランチを main にして GitHub にプッシュ（リポジトリを更新）
git branch -M main
git push -u origin main
```

- すでに `git remote add origin ...` を実行済みなら、**コミットと `git push` だけ**で GitHub が更新されます。
- 別の場所に「前にダウンロードした」フォルダがある場合は、そのフォルダで `git pull origin main` を実行すると、同じ内容に更新できます。

---

## 初めて GitHub に上げる場合

### 1. リポジトリの準備

```bash
cd ~/Claude-Code-Communication/tiktok-comment-dashboard

git add .
git commit -m "feat: TikTok Comment Dashboard with ADB auto-comment"
```

### 2. GitHub でリポジトリを作成

1. https://github.com/new を開く
2. リポジトリ名を入力（例: `tiktok-comment-dashboard`）
3. 「Create repository」をクリック

### 3. リモートを追加してプッシュ

```bash
git remote add origin https://github.com/あなたのユーザー名/tiktok-comment-dashboard.git
git branch -M main
git push -u origin main
```

SSH を使う場合:

```bash
git remote add origin git@github.com:あなたのユーザー名/tiktok-comment-dashboard.git
git branch -M main
git push -u origin main
```

---

スクリプト: `./push-to-github.sh` でコミットまで実行できます（リモート追加とプッシュは上記を手動で実行）。
