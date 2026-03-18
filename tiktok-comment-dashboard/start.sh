#!/bin/bash
# TikTok Comment Dashboard - 起動スクリプト
# 使い方: cd tiktok-comment-dashboard && ./start.sh

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=============================================="
echo "  TikTok Comment Dashboard - 起動中..."
echo "=============================================="

# 1. Ollama起動（既に起動中ならスキップ）
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
  echo "[1/3] Ollama: 既に起動中 ✓"
else
  echo "[1/3] Ollama: 起動中..."
  ~/ollama/bin/ollama serve > /dev/null 2>&1 &
  sleep 3
  if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "       Ollama: 起動完了 ✓"
  else
    echo "       Ollama: 起動失敗 ✗ (AI提案は無効)"
  fi
fi

# 2. Whisperサービス起動（既に起動中ならスキップ）
if ss -tlnp 2>/dev/null | grep -q ":8765"; then
  echo "[2/3] Whisper: 既に起動中 ✓"
else
  echo "[2/3] Whisper: モデル読み込み中（30秒〜1分かかります）..."
  python3 "$DIR/whisper-service.py" > /dev/null 2>&1 &
  WHISPER_PID=$!
  for i in $(seq 1 60); do
    if ss -tlnp 2>/dev/null | grep -q ":8765"; then
      echo "       Whisper: 起動完了 ✓"
      break
    fi
    sleep 1
  done
  if ! ss -tlnp 2>/dev/null | grep -q ":8765"; then
    echo "       Whisper: 起動失敗 ✗ (音声認識は無効)"
  fi
fi

# 3. Node.jsサーバー起動
if ss -tlnp 2>/dev/null | grep -q ":3001"; then
  echo "[3/3] Dashboard: ポート3001は使用中です。再起動しますか？ (y/n)"
  read -r ans
  if [ "$ans" = "y" ]; then
    fuser -k 3001/tcp 2>/dev/null
    sleep 1
  else
    echo "       既存のサーバーを使用します"
    exit 0
  fi
fi

echo "[3/3] Dashboard: 起動中..."
echo ""
echo "=============================================="
echo "  アクセスキー: tiktok2026"
echo "=============================================="
echo ""
node "$DIR/server.js"
