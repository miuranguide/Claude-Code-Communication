const express = require('express');
const { createServer } = require('http');
const { createServer: createHttpsServer } = require('https');
const { Server } = require('socket.io');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { execFile } = require('child_process');

const app = express();

// HTTPS対応（カメラアクセスに必須）
let httpServer;
const keyPath = path.join(__dirname, 'key.pem');
const certPath = path.join(__dirname, 'cert.pem');
if (fs.existsSync(keyPath) && fs.existsSync(certPath)) {
  httpServer = createHttpsServer({
    key: fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath)
  }, app);
  console.log('[HTTPS有効]');
} else {
  httpServer = createServer(app);
  console.log('[HTTP] ※カメラ使用にはHTTPSが必要です');
}

const io = new Server(httpServer, {
  maxHttpBufferSize: 50 * 1024 * 1024 // 50MB for large file transfers
});

// ============================================================
//  メディア設定ファイル
// ============================================================
const CONFIG_PATH = path.join(__dirname, 'media', 'config.json');

function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
    }
  } catch (e) { /* ignore */ }
  return { videos: [], audio: [] };
}

function saveConfig(config) {
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), 'utf-8');
}

// 初期config作成
if (!fs.existsSync(CONFIG_PATH)) {
  fs.mkdirSync(path.join(__dirname, 'media', 'videos'), { recursive: true });
  fs.mkdirSync(path.join(__dirname, 'media', 'audio'), { recursive: true });
  saveConfig({ videos: [], audio: [] });
}

// サムネイルディレクトリ (3.4)
const thumbDir = path.join(__dirname, 'media', 'thumbs');
fs.mkdirSync(thumbDir, { recursive: true });

// ============================================================
//  静的ファイル配信
// ============================================================
app.use(express.static('public'));
app.use('/media', express.static('media'));
app.use('/nn', express.static(path.join(__dirname, 'node_modules', 'facefilter', 'neuralNets')));
app.use('/facefilter', express.static(path.join(__dirname, 'node_modules', 'facefilter', 'dist')));
app.use(express.json());

// ============================================================
//  メディアアップロード API
// ============================================================
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const type = file.mimetype.startsWith('video/') ? 'videos' : 'audio';
    const dir = path.join(__dirname, 'media', type);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    // 日本語ファイル名対応
    const ext = path.extname(file.originalname);
    const safeName = Date.now() + ext;
    cb(null, safeName);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB制限
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('video/') || file.mimetype.startsWith('audio/')) {
      cb(null, true);
    } else {
      cb(new Error('動画または音声ファイルのみアップロード可能です'));
    }
  }
});

// サーバーサイドサムネイル生成 (3.4)
function generateThumbnail(videoPath, thumbPath) {
  return new Promise((resolve) => {
    execFile('ffmpeg', [
      '-i', videoPath,
      '-ss', '00:00:00.5',
      '-vframes', '1',
      '-vf', 'scale=240:-1',
      '-y',
      thumbPath
    ], { timeout: 10000 }, (err) => {
      if (err) {
        resolve(false);
      } else {
        resolve(true);
      }
    });
  });
}

// アップロード
app.post('/api/upload', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'ファイルがありません' });

  const isVideo = req.file.mimetype.startsWith('video/');
  const type = isVideo ? 'videos' : 'audio';
  const item = {
    id: Date.now().toString(),
    name: req.body.name || req.file.originalname,
    filename: req.file.filename,
    url: `/media/${type}/${req.file.filename}`,
    mime: req.file.mimetype,
    size: req.file.size,
    createdAt: new Date().toISOString()
  };

  // サーバーサイドサムネイル生成 (3.4)
  if (isVideo) {
    const thumbName = req.file.filename.replace(/\.[^.]+$/, '.jpg');
    const thumbPath = path.join(thumbDir, thumbName);
    const ok = await generateThumbnail(req.file.path, thumbPath);
    if (ok) {
      item.thumbUrl = `/media/thumbs/${thumbName}`;
    }
  }

  const config = loadConfig();
  if (isVideo) {
    config.videos.push(item);
  } else {
    config.audio.push(item);
  }
  saveConfig(config);

  // 全コントローラーに通知
  io.emit('media-updated', loadConfig());

  res.json(item);
});

// メディア一覧
app.get('/api/media', (req, res) => {
  res.json(loadConfig());
});

// メディア名称変更
app.patch('/api/media/:id', (req, res) => {
  const config = loadConfig();
  const item = [...config.videos, ...config.audio].find(m => m.id === req.params.id);
  if (!item) return res.status(404).json({ error: '見つかりません' });
  item.name = req.body.name || item.name;
  saveConfig(config);
  io.emit('media-updated', config);
  res.json(item);
});

// メディア削除
app.delete('/api/media/:id', (req, res) => {
  const config = loadConfig();
  let found = null;

  config.videos = config.videos.filter(m => {
    if (m.id === req.params.id) { found = m; return false; }
    return true;
  });
  config.audio = config.audio.filter(m => {
    if (m.id === req.params.id) { found = m; return false; }
    return true;
  });

  if (!found) return res.status(404).json({ error: '見つかりません' });

  // ファイル削除
  const filePath = path.join(__dirname, found.url);
  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);

  // サムネイル削除
  if (found.thumbUrl) {
    const tp = path.join(__dirname, found.thumbUrl);
    if (fs.existsSync(tp)) fs.unlinkSync(tp);
  }

  saveConfig(config);
  io.emit('media-updated', config);
  res.json({ ok: true });
});

// ============================================================
//  Socket.IO - リアルタイム通信
// ============================================================
// roomId -> { displays: Set, controllers: Set, state: {} }
const rooms = new Map();

function getRoomState(roomId) {
  if (!rooms.has(roomId)) return null;
  return rooms.get(roomId).state || {};
}

function setRoomState(roomId, state) {
  if (!rooms.has(roomId)) return;
  rooms.get(roomId).state = state;
}

// ACKリレーヘルパー: displayに転送し、displayのACKをcontrollerに返す (1.3)
function relayWithAck(socket, event, data, ack) {
  const roomId = socket.roomId;
  if (!roomId) {
    if (ack) ack({ ok: false, error: 'not in room' });
    return;
  }
  const room = rooms.get(roomId);
  if (!room || room.displays.size === 0) {
    if (ack) ack({ ok: false, error: 'no display connected' });
    return;
  }

  // displayソケットを見つけてACK付きで送信
  const displayIds = [...room.displays];
  let responded = false;

  for (const did of displayIds) {
    const dsocket = io.sockets.sockets.get(did);
    if (dsocket) {
      dsocket.emit(event, data, (resp) => {
        if (!responded) {
          responded = true;
          if (ack) ack(resp || { ok: true });
        }
      });
    }
  }

  // displayが応答しない場合のタイムアウト
  setTimeout(() => {
    if (!responded) {
      responded = true;
      if (ack) ack({ ok: true, timeout: true });
    }
  }, 3000);
}

io.on('connection', (socket) => {
  console.log(`[接続] ${socket.id}`);

  // ルーム参加
  socket.on('join-room', ({ roomId, role }) => {
    socket.join(roomId);
    socket.roomId = roomId;
    socket.role = role;

    if (!rooms.has(roomId)) {
      rooms.set(roomId, { displays: new Set(), controllers: new Set(), state: {} });
    }
    const room = rooms.get(roomId);
    if (role === 'display') {
      room.displays.add(socket.id);
    } else {
      room.controllers.add(socket.id);
    }

    // 接続状態を通知
    io.to(roomId).emit('room-status', {
      displays: room.displays.size,
      controllers: room.controllers.size
    });

    console.log(`[入室] ${socket.id} → Room:${roomId} Role:${role}`);
  });

  // ===== コントローラー → ディスプレイ コマンド（ACKリレー対応 1.3） =====

  // 動画再生 (layer対応 2.2)
  socket.on('play-video', (data, ack) => {
    relayWithAck(socket, 'play-video', data, ack);
  });

  // 動画停止
  socket.on('stop-video', (data, ack) => {
    relayWithAck(socket, 'stop-video', data || {}, ack);
  });

  // 音楽再生
  socket.on('play-audio', (data, ack) => {
    relayWithAck(socket, 'play-audio', data, ack);
  });

  // 音楽停止
  socket.on('stop-audio', (data, ack) => {
    relayWithAck(socket, 'stop-audio', data, ack);
  });

  // 全停止
  socket.on('stop-all', (data, ack) => {
    relayWithAck(socket, 'stop-all', data || {}, ack);
  });

  // 音量変更
  socket.on('set-volume', (data, ack) => {
    relayWithAck(socket, 'set-volume', data, ack);
  });

  // 動画サイズ・位置変更
  socket.on('set-overlay', (data, ack) => {
    relayWithAck(socket, 'set-overlay', data, ack);
  });

  // オーバーレイ位置テスト表示
  socket.on('preview-video-position', (data, ack) => {
    relayWithAck(socket, 'preview-video-position', data, ack);
  });

  // テスト表示を非表示
  socket.on('hide-overlay-preview', (data, ack) => {
    relayWithAck(socket, 'hide-overlay-preview', data || {}, ack);
  });

  // 美顔フィルター設定
  socket.on('set-beauty', (data, ack) => {
    relayWithAck(socket, 'set-beauty', data, ack);
  });

  // プレビュー画像（display → controller）
  socket.on('preview-frame', (data) => {
    socket.to(socket.roomId).emit('preview-frame', data);
  });

  // ===== 状態同期 (1.4) =====

  // displayが現在の状態を報告
  socket.on('report-state', (state) => {
    if (socket.roomId) {
      setRoomState(socket.roomId, state);
    }
  });

  // controllerが状態同期を要求
  socket.on('request-state', () => {
    if (!socket.roomId) return;
    const room = rooms.get(socket.roomId);
    if (!room) return;

    // displayに状態報告を要求
    for (const did of room.displays) {
      const dsocket = io.sockets.sockets.get(did);
      if (dsocket) {
        dsocket.emit('request-state', {}, (state) => {
          socket.emit('sync-state', state);
        });
      }
    }
  });

  // 切断
  socket.on('disconnect', () => {
    if (socket.roomId && rooms.has(socket.roomId)) {
      const room = rooms.get(socket.roomId);
      room.displays.delete(socket.id);
      room.controllers.delete(socket.id);

      io.to(socket.roomId).emit('room-status', {
        displays: room.displays.size,
        controllers: room.controllers.size
      });

      if (room.displays.size === 0 && room.controllers.size === 0) {
        rooms.delete(socket.roomId);
      }
    }
    console.log(`[切断] ${socket.id}`);
  });
});

// ============================================================
//  サーバー起動
// ============================================================
const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('===========================================');
  console.log('  TikTok Live Controller - サーバー起動');
  console.log('===========================================');
  console.log(`  ポート: ${PORT}`);
  const proto = fs.existsSync(keyPath) ? 'https' : 'http';
  console.log(`  表示ページ:     ${proto}://localhost:${PORT}/display.html`);
  console.log(`  コントローラー: ${proto}://localhost:${PORT}/controller.html`);
  console.log('===========================================');
  console.log('');
});
