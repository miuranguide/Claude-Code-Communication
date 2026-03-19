#!/bin/bash
# GitHub にプッシュ／更新するためのスクリプト（WSL のターミナルで実行してください）
set -e
cd "$(dirname "$0")"

git add .
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "feat: ADB自動コメント投稿・送信モード切替を追加"
  echo "コミットしました。"
else
  echo "コミットする変更がありません。"
fi

if git remote get-url origin 2>/dev/null; then
  echo "リモート: $(git remote get-url origin)"
  git branch -M main
  git push -u origin main
  echo "GitHub を更新しました（push 完了）。"
else
  echo ""
  echo "=== リモートが未設定です ==="
  echo "1. https://github.com/new でリポジトリを作成"
  echo "2. 以下を実行:"
  echo "   git remote add origin https://github.com/あなたのユーザー名/tiktok-comment-dashboard.git"
  echo "   ./push-to-github.sh"
  echo ""
fi
