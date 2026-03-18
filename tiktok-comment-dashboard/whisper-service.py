"""
Whisper音声認識サービス
TikTok Liveの音声をテキストに変換して、Node.jsサーバーにWebSocketで送信
"""

import asyncio
import json
import sys
import os
import tempfile
import time
from pathlib import Path

try:
    from faster_whisper import WhisperModel
except ImportError:
    print("Error: faster-whisper not installed. Run: pip install faster-whisper")
    sys.exit(1)

try:
    import websockets
except ImportError:
    print("Installing websockets...")
    os.system(f"{sys.executable} -m pip install websockets")
    import websockets

# Whisperモデル読み込み（small = バランス良い）
print("[Whisper] モデル読み込み中 (small)...")
model = WhisperModel("small", device="cuda", compute_type="float16")
print("[Whisper] モデル読み込み完了")


async def transcribe_audio(audio_path):
    """音声ファイルをテキストに変換"""
    try:
        segments, info = model.transcribe(
            audio_path,
            language="ja",
            beam_size=5,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=500),
        )
        texts = []
        for segment in segments:
            texts.append(segment.text.strip())
        return " ".join(texts)
    except Exception as e:
        print(f"[Whisper] 認識エラー: {e}")
        return ""


async def handle_connection(websocket):
    """Node.jsサーバーからの音声データを受信して認識結果を返す"""
    print(f"[Whisper] クライアント接続")
    try:
        async for message in websocket:
            try:
                data = json.loads(message)

                if data.get("type") == "audio":
                    slot_id = data.get("slotId", 0)
                    audio_bytes = bytes.fromhex(data["audio"])

                    # 一時ファイルに書き出し
                    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                        f.write(audio_bytes)
                        tmp_path = f.name

                    # 認識実行
                    text = await transcribe_audio(tmp_path)

                    # 一時ファイル削除
                    os.unlink(tmp_path)

                    if text:
                        result = json.dumps({
                            "type": "transcription",
                            "slotId": slot_id,
                            "text": text,
                            "timestamp": int(time.time() * 1000),
                        })
                        await websocket.send(result)
                        print(f"[Whisper][スロット{slot_id + 1}] {text[:60]}")

                elif data.get("type") == "ping":
                    await websocket.send(json.dumps({"type": "pong"}))

            except json.JSONDecodeError:
                pass
            except Exception as e:
                print(f"[Whisper] 処理エラー: {e}")
    except websockets.exceptions.ConnectionClosed:
        print("[Whisper] クライアント切断")


async def main():
    port = int(os.environ.get("WHISPER_PORT", "8765"))
    print(f"[Whisper] WebSocketサーバー起動 ws://localhost:{port}")
    async with websockets.serve(handle_connection, "localhost", port):
        await asyncio.Future()  # 永久待機


if __name__ == "__main__":
    asyncio.run(main())
