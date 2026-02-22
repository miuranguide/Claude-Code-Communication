# Changelog

## v1.1.0 (2026-02-20)

### Bug Fixes
- WebSocketサーバー: バイナリデータによるクラッシュを防止（型チェック追加）
- WebSocketサーバー: 空catchをdebugPrintログに変更
- WebSocketサーバー: IPアドレス取得失敗時にnull返却+UI通知に変更（`0.0.0.0`フォールバック廃止）
- WebSocketサーバー: QRデータを`jsonEncode()`で生成（文字列補間廃止）
- WebSocketサーバー: disposeを同期的に実行
- アセットプロバイダー: `Completer`による初期化完了保証（競合状態修正）
- アセットプロバイダー: ファイルバリデーション追加（存在確認・拡張子・サイズ）
- アセットプロバイダー: `firstWhereOrNull`パターンでクラッシュ防止
- アセットプロバイダー: Hiveボックス参照をキャッシュ
- ホーム画面: `token.substring(0,8)` に長さチェック追加
- ホーム画面: `permission_handler`でカメラ権限を明示的にリクエスト
- ホーム画面: カメラ初期化中のローディング表示追加
- オーバーレイレイヤー: リスナーを名前付きメソッドに変更しdispose時にremoveListener
- オーバーレイレイヤー: aspectRatio==0のゼロ除算ガード追加
- オーバーレイレイヤー: ハードコード`3.14159` → `dart:math`の`pi`に変更
- レイアウトエディタ: Y軸clampにビデオ高さを考慮
- レイアウトエディタ: リセットボタンに確認ダイアログ追加
- リモートWsClient: 空catch → エラーログ追加
- リモートWsClient: `data as String` → 型チェック追加
- ペアリング画面: JSON fieldのnullチェック追加
- ペアリング画面: URL/トークンバリデーション追加
- ペアリング画面: TextEditingControllerのdispose追加
- コントロール画面: `track['id'] as String` → nullチェック追加
- LayoutData: バウンダリバリデーション追加（xNorm 0..1, scale 0.1..2.0等）
- LayoutData: fitModeをString → enum FitModeに変更

### Improvements
- WebSocketハートビート機構追加（PING/PONG、15秒間隔、30秒タイムアウト）
- Hive永続化パフォーマンス改善（ボックス参照キャッシュ）
- エラー表示改善（SnackBar、5秒自動クリア、ACK日本語表示）
- 再接続: 指数バックオフ（1s→2s→4s→8s→16s）、手動再接続ボタン、再接続バナー
- ConnectionStatus enum追加（disconnected/connecting/connected/reconnecting/error）
- クリップ検索: Map<String,Clip>によるO(1)検索
- 静的解析: 全パッケージにanalysis_options.yaml追加
- ユニットテスト: モデルJSON往復テスト・プロトコルテスト追加
- Track: durationMsフィールド追加、copyWithメソッド追加
- shared: 未使用のuuid依存削除

### New Features
- キュー機能: 再生中にコマンド受信時のIGNORE/QUEUE切替
- 回転スライダー: レイアウトエディタに-180〜180度の回転調整追加
- BGMループ切替: 素材管理画面でトグルSwitch追加
- カメラ切替: フロント/バックカメラ切替ボタン追加
- カスタムオーディオプリセット: 追加/編集/削除UI
- バージョン表示: 共有定数から取得（ハードコード廃止）

### Documentation
- プロジェクトREADME: アーキテクチャ図・クイックスタート・WebSocketプロトコル仕様
- Broadcaster README: 機能一覧・ビルド手順・必要権限
- Remote README: 機能一覧・ビルド手順・ボタン割当説明
- CHANGELOG: バージョン管理開始

## v1.0.0 (MVP)

- 初回リリース
- Broadcaster: カメラプレビュー、動画オーバーレイ、BGM再生、WebSocketサーバー
- Remote: QRペアリング、StreamDeck風4ボタン、BGMコントロール
- 共有パッケージ: モデル、プロトコル、定数
