# Remote App

StreamDeck風 TikTok LIVE リモコンアプリ。

## 機能一覧

- QRコードスキャンでBroadcasterとペアリング
- 手動入力でのWebSocket接続
- StreamDeck風4ボタン（WIN / LOSE / OTHER 1 / OTHER 2）
- BGM再生/停止コントロール
- 音量プリセット切替（バトル / トーク）
- 緊急STOPボタン
- 自動再接続（指数バックオフ: 1s → 2s → 4s → 8s → 16s）
- 手動再接続ボタン
- 接続状態表示（disconnected / connecting / connected / reconnecting / error）

## ビルド手順

```bash
cd apps/remote
flutter pub get
flutter run
```

## 画面構成

- **ペアリング画面**: QRスキャン or 手動入力で接続
- **コントロール画面**: 演出ボタン + BGM + プリセット + STOP
- **ボタン割当画面**: 各ボタンにクリップを割り当て

## ボタン割当

| ボタン | 色 | 用途 |
|--------|-----|------|
| WIN | 緑 | 勝利演出クリップ |
| LOSE | 赤 | 敗北演出クリップ |
| OTHER 1 | 青 | カスタム演出1 |
| OTHER 2 | 紫 | カスタム演出2 |

各ボタンには「ボタン割当」画面からBroadcasterに登録済みのクリップを割り当てます。
