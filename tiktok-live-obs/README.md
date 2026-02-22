# TikTok LIVE OBS

Flutter製 2台構成の TikTok LIVE 配信演出システム。
Broadcaster（カメラ＋オーバーレイ＋BGM）と Remote（StreamDeck風リモコン）が WebSocket で通信します。

## アーキテクチャ

```
┌─────────────────────┐     WebSocket (LAN)     ┌──────────────────────┐
│   Broadcaster App   │◄──────────────────────►│     Remote App       │
│                     │                         │                      │
│  Camera Preview     │  PAIR / PLAY_CLIP /     │  StreamDeck-style    │
│  Video Overlay      │  STOP_CLIP / PLAY_BGM / │  Buttons (WIN/LOSE)  │
│  BGM Player         │  STOP_BGM / SET_MIX     │  BGM Control         │
│  WS Server          │  PING / PONG            │  Preset Toggle       │
│  QR Code Display    │                         │  QR Scanner          │
└─────────────────────┘                         └──────────────────────┘

packages/shared/ — モデル・プロトコル・定数（両アプリ共通）
```

## クイックスタート

### 前提条件
- Flutter SDK >= 3.10.0
- Dart SDK >= 3.0.0
- Android / iOS 実機 × 2台（同一WiFiネットワーク）

### ビルド & 実行

```bash
# 1. 依存関係のインストール
cd packages/shared && dart pub get && cd ../..
cd apps/broadcaster && flutter pub get && cd ../..
cd apps/remote && flutter pub get && cd ../..

# 2. Broadcaster を1台目にインストール
cd apps/broadcaster && flutter run

# 3. Remote を2台目にインストール
cd apps/remote && flutter run
```

### 接続手順
1. Broadcaster が起動すると WebSocket サーバーが自動開始
2. Broadcaster の QR ボタンをタップ → QR コードが表示
3. Remote で「QRスキャン」→ QR コードを読み取り
4. 接続完了 → Remote のコントロール画面に遷移

## WebSocket プロトコル仕様

### メッセージフォーマット
```json
{
  "type": "COMMAND_NAME",
  "reqId": "unique_request_id",
  ...payload
}
```

### コマンド一覧

| コマンド | 方向 | ペイロード | 説明 |
|---------|------|-----------|------|
| `PAIR` | Remote → Broadcaster | `token`, `deviceName` | 認証ペアリング |
| `PLAY_CLIP` | Remote → Broadcaster | `clipId` | クリップ再生 |
| `STOP_CLIP` | Remote → Broadcaster | - | クリップ停止 |
| `PLAY_BGM` | Remote → Broadcaster | `trackId` | BGM再生 |
| `STOP_BGM` | Remote → Broadcaster | - | BGM停止 |
| `SET_MIX` | Remote → Broadcaster | `name`, `clipGain`, `bgmGain` | 音量プリセット適用 |
| `ACK` | Broadcaster → Remote | `ok`, `error?` | コマンド応答 |
| `PING` | Broadcaster → Remote | - | ハートビート |
| `PONG` | Remote → Broadcaster | - | ハートビート応答 |
| `ASSET_LIST` | Broadcaster → Remote | `clips[]`, `tracks[]` | アセット一覧同期 |
| `CLIP_STARTED` | Broadcaster → Remote | `clipId` | クリップ再生開始通知 |
| `CLIP_ENDED` | Broadcaster → Remote | - | クリップ再生終了通知 |
| `BGM_STARTED` | Broadcaster → Remote | `trackId` | BGM再生開始通知 |
| `BGM_STOPPED` | Broadcaster → Remote | - | BGM停止通知 |

### ACK エラーコード

| コード | 説明 |
|--------|------|
| `CLIP_NOT_FOUND` | 指定のクリップが存在しない |
| `TRACK_NOT_FOUND` | 指定のBGMトラックが存在しない |
| `COOLDOWN_ACTIVE` | クールダウン中 |
| `INVALID_TOKEN` | 認証トークン不一致 |

### ハートビート
- Broadcaster が 15 秒間隔で `PING` を送信
- Remote は `PONG` で応答
- 30 秒無応答でタイムアウト切断

## パッケージ構成

```
tiktok-live-obs/
├── packages/shared/        # 共通モデル・プロトコル
│   ├── lib/models/         # Clip, Track, MixPreset, LayoutData
│   ├── lib/protocol/       # WsMessage, WsCmd, WsError
│   └── lib/utils/          # AppConstants, IdGen
├── apps/broadcaster/       # 配信アプリ
│   ├── lib/providers/      # Riverpod state management
│   ├── lib/screens/        # UI screens
│   ├── lib/services/       # WebSocket server
│   └── lib/widgets/        # Overlay, BGM player
└── apps/remote/            # リモコンアプリ
    ├── lib/providers/      # Button assignments
    ├── lib/screens/        # Pair, Control, Assign
    └── lib/services/       # WebSocket client
```

## テスト

```bash
# 共有パッケージのユニットテスト
cd packages/shared && dart test
```

## ライセンス

Private
