const express = require('express');
const { createServer } = require('http');
const { createServer: createHttpsServer } = require('https');
const { Server } = require('socket.io');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const WebSocket = require('ws');
const { exec, execSync } = require('child_process');

const app = express();

// ============================================================
//  Ollama (ローカルLLM) 設定
// ============================================================
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://localhost:11434';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'gemma3:4b';

async function ollamaGenerate(prompt) {
  try {
    const res = await fetch(`${OLLAMA_URL}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: OLLAMA_MODEL,
        prompt,
        stream: false,
        options: { temperature: 0.7, num_predict: 150 },
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    return data.response || null;
  } catch (e) {
    return null;
  }
}

// 会話コンテキストを保持（スロット別）
const slotContexts = Array.from({ length: 5 }, () => []);
const MAX_CONTEXT = 20; // 直近20件のコメント/音声を保持

function addToContext(slotId, type, text) {
  slotContexts[slotId].push({ type, text, time: Date.now() });
  if (slotContexts[slotId].length > MAX_CONTEXT) {
    slotContexts[slotId].shift();
  }
}

// ============================================================
//  ADB デバイス管理
// ============================================================
const deviceSlotMap = {};

function getConnectedDevices() {
  try {
    const output = execSync('adb devices', { encoding: 'utf-8' });
    return output.split('\n').slice(1)
      .filter(l => l.includes('\tdevice'))
      .map(l => l.split('\t')[0].trim());
  } catch (e) { return []; }
}

function syncDevices() {
  const connected = getConnectedDevices();
  for (const serial of Object.keys(deviceSlotMap)) {
    if (!connected.includes(serial)) {
      const slotId = deviceSlotMap[serial];
      delete deviceSlotMap[serial];
      io.emit('device-status', { slotId, connected: false, serial: '' });
    }
  }
  for (const serial of connected) {
    if (!deviceSlotMap.hasOwnProperty(serial)) {
      const usedSlots = Object.values(deviceSlotMap);
      let freeSlot = -1;
      for (let i = 0; i < MAX_SLOTS; i++) {
        if (!usedSlots.includes(i)) { freeSlot = i; break; }
      }
      if (freeSlot !== -1) {
        deviceSlotMap[serial] = freeSlot;
        console.log(`[ADB] 接続: ${serial} → スロット${freeSlot + 1}`);
        io.emit('device-status', { slotId: freeSlot, connected: true, serial });
        io.emit('system-toast', { message: `📱 スロット${freeSlot + 1}にスマホ接続` });
      }
    }
  }
}
setInterval(syncDevices, 3000);

// ランダム整数（min〜max）
function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// ランダム待機（ms）
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ADB設定（後からSocket.IOで変更可能）
let adbConfig = {
  tapOffsetPx: 10,      // タップ座標ランダム幅（±px）
  waitMin: 1000,        // 送信前待機 最短ms
  waitMax: 3000,        // 送信前待機 最長ms
  tapSpeedMin: 50,      // タップ速度 最短ms
  tapSpeedMax: 150,     // タップ速度 最長ms
  commentX: 360,       // コメント欄のX座標（基準値）
  commentY: 1400,       // コメント欄のY座標（基準値）
};

// コメントをテキスト入力（送信なし）
async function adbInputComment(serial, text) {
  const offsetX = randInt(-adbConfig.tapOffsetPx, adbConfig.tapOffsetPx);
  const offsetY = randInt(-adbConfig.tapOffsetPx, adbConfig.tapOffsetPx);
  const tapX = adbConfig.commentX + offsetX;
  const tapY = adbConfig.commentY + offsetY;
  const escaped = text.replace(/"/g, '\\"');

  const tapSpeed = randInt(adbConfig.tapSpeedMin, adbConfig.tapSpeedMax); // ms

  const cmds = [
    `adb -s ${serial} shell input tap ${tapX} ${tapY}`,
    `sleep ${tapSpeed / 1000}`,
    `adb -s ${serial} shell input keyevent KEYCODE_CTRL_A`,
    `adb -s ${serial} shell input keyevent KEYCODE_DEL`,
    `adb -s ${serial} shell am broadcast -a ADB_INPUT_TEXT --es msg "${escaped}"`,
  ];

  return new Promise((resolve, reject) => {
    exec(cmds.join(' && '), { timeout: 10000 }, (error) => {
      if (error) { reject(error); } else { resolve(); }
    });
  });
}

// 送信（Enterキー）
async function adbSendComment(serial) {
  return new Promise((resolve, reject) => {
    exec(
      `adb -s ${serial} shell input keyevent KEYCODE_ENTER`,
      { timeout: 5000 },
      (error) => { if (error) reject(error); else resolve(); }
    );
  });
}

// 入力→ランダム待機→送信（1クリックモード用）
async function adbInputAndSend(serial, text) {
  await adbInputComment(serial, text);
  const wait = randInt(adbConfig.waitMin, adbConfig.waitMax);
  await sleep(wait);
  await adbSendComment(serial);
}

function buildPrompt(slotId, latestComment) {
  const ctx = slotContexts[slotId];
  let contextStr = '';
  ctx.forEach(c => {
    if (c.type === 'audio') contextStr += `[配信者の発言] ${c.text}\n`;
    else contextStr += `[視聴者コメント] ${c.text}\n`;
  });

  return `あなたはTikTokライブ配信を盛り上げるコメント補助アシスタントです。
視聴者として配信を盛り上げるコメントを3つ提案してください。

## ルール
- 各提案は1行で短く（30文字以内）
- 自然な視聴者のコメントに見える口調（「！」「〜」「w」など使ってOK）
- 配信の話題や流れに合った内容にする
- 盛り上がっていないときは話題を広げるコメントを提案
- 配信者の発言に共感・リアクション・質問で盛り上げる
- 各提案を改行で区切って出力
- 番号や記号は付けない

## 最近の会話の流れ
${contextStr}
## 最新のコメント
${latestComment}

## 盛り上げコメント提案（3つ）:`;
}

// ============================================================
//  Whisper WebSocket クライアント
// ============================================================
let whisperWs = null;
let whisperConnected = false;

function connectWhisper() {
  const wsUrl = process.env.WHISPER_URL || 'ws://localhost:8765';
  try {
    whisperWs = new WebSocket(wsUrl);

    whisperWs.on('open', () => {
      whisperConnected = true;
      console.log('[Whisper] 接続成功');
    });

    whisperWs.on('message', (data) => {
      try {
        const msg = JSON.parse(data);
        if (msg.type === 'transcription' && msg.text) {
          const slotId = msg.slotId || 0;
          addToContext(slotId, 'audio', msg.text);
          io.emit('transcription', {
            slotId,
            text: msg.text,
            timestamp: msg.timestamp,
          });
          console.log(`[Whisper][スロット${slotId + 1}] ${msg.text.slice(0, 60)}`);
        }
      } catch (e) { /* ignore */ }
    });

    whisperWs.on('close', () => {
      whisperConnected = false;
      console.log('[Whisper] 切断 - 5秒後に再接続');
      setTimeout(connectWhisper, 5000);
    });

    whisperWs.on('error', () => {
      whisperConnected = false;
    });
  } catch (e) {
    console.log('[Whisper] 接続失敗 - 5秒後に再試行');
    setTimeout(connectWhisper, 5000);
  }
}

// Whisperサービスへの接続を開始
connectWhisper();

// ============================================================
//  認証
// ============================================================
const ACCESS_KEY = process.env.TCD_ACCESS_KEY || 'tiktok2026';
const AUTH_COOKIE_NAME = 'tcd_auth';
const AUTH_TOKEN = crypto.randomBytes(16).toString('hex');

function parseCookies(cookieHeader) {
  const cookies = {};
  cookieHeader.split(';').forEach(c => {
    const [k, ...v] = c.trim().split('=');
    if (k) cookies[k] = v.join('=');
  });
  return cookies;
}

function isAuthenticated(req) {
  if (req.query && req.query.key === ACCESS_KEY) return true;
  const cookies = parseCookies(req.headers.cookie || '');
  if (cookies[AUTH_COOKIE_NAME] === AUTH_TOKEN) return true;
  return false;
}

// ============================================================
//  HTTPS
// ============================================================
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
  console.log('[HTTP]');
}

const io = new Server(httpServer);

// ============================================================
//  認証ミドルウェア
// ============================================================
app.get('/login', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

app.post('/api/auth', express.json(), (req, res) => {
  if (req.body && req.body.key === ACCESS_KEY) {
    res.setHeader('Set-Cookie', `${AUTH_COOKIE_NAME}=${AUTH_TOKEN}; Path=/; HttpOnly; SameSite=Strict; Max-Age=86400`);
    res.json({ ok: true });
  } else {
    res.status(401).json({ ok: false, error: 'キーが違います' });
  }
});

// 認証なし（ローカル専用）
app.use((req, res, next) => next());

app.use(express.static('public'));
app.use(express.json());

// ============================================================
//  5スロット TikTok Live 接続管理
// ============================================================
const MAX_SLOTS = 5;

// slots[0..4] — 各スロットの接続状態
const slots = Array.from({ length: MAX_SLOTS }, (_, i) => ({
  id: i,
  connection: null,
  connected: false,
  username: '',
  viewers: 0,
  title: '',
  profilePic: '',
}));

// 全スロット統合コメント履歴（最新500件）
const commentHistory = [];
const MAX_COMMENTS = 500;

// 定型文テンプレート
const defaultTemplates = [
  { id: 1, category: '挨拶', text: 'こんにちは〜！初見です！' },
  { id: 2, category: '挨拶', text: 'きた〜！今日も配信ありがとう！' },
  { id: 3, category: 'リアクション', text: 'それめっちゃわかる！' },
  { id: 4, category: 'リアクション', text: 'すごい！上手すぎるw' },
  { id: 5, category: 'リアクション', text: 'wwwww' },
  { id: 6, category: '盛り上げ', text: '面白すぎるw もっと聞きたい！' },
  { id: 7, category: '盛り上げ', text: '神配信きた🔥🔥' },
  { id: 8, category: '盛り上げ', text: 'みんなもっとコメントして〜！' },
  { id: 9, category: '質問', text: 'それってどうやるの？' },
  { id: 10, category: '質問', text: '次は何する予定？' },
  { id: 11, category: '応援', text: '頑張って〜！応援してる！💪' },
  { id: 12, category: '応援', text: 'いつも楽しみにしてます！' },
];

const TEMPLATES_PATH = path.join(__dirname, 'templates.json');

function loadTemplates() {
  try {
    if (fs.existsSync(TEMPLATES_PATH)) {
      return JSON.parse(fs.readFileSync(TEMPLATES_PATH, 'utf-8'));
    }
  } catch (e) { /* ignore */ }
  return defaultTemplates;
}

function saveTemplates(templates) {
  fs.writeFileSync(TEMPLATES_PATH, JSON.stringify(templates, null, 2), 'utf-8');
}

// コメント分析: キーワードベースのフォールバック
function analyzeCommentKeyword(comment) {
  const text = comment.text.toLowerCase();
  const suggestions = [];

  if (/こんにちは|こんばんは|はじめまして|初めて|hello|hi|hey/.test(text)) {
    suggestions.push({ type: 'greeting', text: '自分も初見です！よろしく〜' });
    suggestions.push({ type: 'greeting', text: 'こんにちは！今日も来ちゃった！' });
  }
  if (/\?|？|何|なに|どう|いつ|どこ|誰|なぜ|教えて/.test(text)) {
    suggestions.push({ type: 'question', text: 'それ気になる！教えてほしい！' });
    suggestions.push({ type: 'question', text: '自分も知りたかった！' });
  }
  if (/かわいい|かっこいい|すごい|上手|素敵|cute|cool|amazing/.test(text)) {
    suggestions.push({ type: 'agree', text: 'ほんとそれ！すごすぎるw' });
    suggestions.push({ type: 'agree', text: 'わかる〜！めっちゃいいよね！' });
  }
  if (/www|笑|草|ワロタ|おもしろ|面白/.test(text)) {
    suggestions.push({ type: 'laugh', text: 'wwwww' });
    suggestions.push({ type: 'laugh', text: '腹痛いwww' });
  }
  if (/ギフト|gift|ローズ|rose/.test(text)) {
    suggestions.push({ type: 'hype', text: 'ギフト飛んでる〜！🔥' });
  }
  if (suggestions.length === 0) {
    suggestions.push({ type: 'default', text: 'いいね〜！' });
    suggestions.push({ type: 'default', text: 'それな！わかるw' });
  }
  return suggestions;
}

// Ollama AI提案（非同期）
async function analyzeCommentAI(comment, slotId) {
  // コンテキストに追加
  addToContext(slotId, 'comment', `${comment.nickname}: ${comment.text}`);

  // Ollamaでの提案生成を試みる
  const prompt = buildPrompt(slotId, `${comment.nickname}: ${comment.text}`);
  const response = await ollamaGenerate(prompt);

  if (response) {
    const lines = response.split('\n')
      .map(l => l.replace(/^[\d\-\.\)]+\s*/, '').trim())
      .filter(l => l.length > 0 && l.length < 60);
    if (lines.length > 0) {
      return lines.slice(0, 3).map(text => ({ type: 'ai', text }));
    }
  }

  // フォールバック: キーワードベース
  return analyzeCommentKeyword(comment);
}

// ============================================================
//  盛り上がり度（Hype Meter）
// ============================================================
const hypeData = Array.from({ length: 5 }, () => ({
  comments: [],   // タイムスタンプ配列
  gifts: [],
  likes: [],
  members: [],
  score: 0,
  level: 'low',   // low / medium / high
}));

const HYPE_WINDOW = 60000;        // 直近60秒で計測
const HYPE_LOW_THRESHOLD = 3;     // これ以下で「低い」
const HYPE_HIGH_THRESHOLD = 15;   // これ以上で「高い」
const AUTO_SUGGEST_INTERVAL = 30000; // 盛り上がり低いとき30秒ごとに自動提案

function addHypeEvent(slotId, type) {
  const now = Date.now();
  hypeData[slotId][type].push(now);
}

function calcHypeScore(slotId) {
  const now = Date.now();
  const d = hypeData[slotId];

  // 古いイベントを除去
  ['comments', 'gifts', 'likes', 'members'].forEach(type => {
    d[type] = d[type].filter(t => t > now - HYPE_WINDOW);
  });

  // スコア計算: コメント×1 + ギフト×3 + いいね×0.2 + 入室×0.5
  const score = d.comments.length * 1
    + d.gifts.length * 3
    + d.likes.length * 0.2
    + d.members.length * 0.5;

  d.score = Math.round(score * 10) / 10;

  if (score <= HYPE_LOW_THRESHOLD) d.level = 'low';
  else if (score >= HYPE_HIGH_THRESHOLD) d.level = 'high';
  else d.level = 'medium';

  return { score: d.score, level: d.level };
}

// 盛り上がりが低いとき自動でコメント提案を生成
function buildAutoSuggestPrompt(slotId) {
  const ctx = slotContexts[slotId];
  let contextStr = '';
  ctx.forEach(c => {
    if (c.type === 'audio') contextStr += `[配信者の発言] ${c.text}\n`;
    else contextStr += `[視聴者コメント] ${c.text}\n`;
  });

  return `あなたはTikTokライブ配信を盛り上げる視聴者コメント補助アシスタントです。
現在、配信の盛り上がりが低い状態です。場を盛り上げるコメントを3つ提案してください。

## ルール
- 各提案は1行で短く（30文字以内）
- 自然な視聴者のコメントに見える口調
- 配信の話題に合わせつつ、会話のきっかけになるコメント
- 質問系・共感系・リアクション系をバランスよく
- 各提案を改行で区切って出力
- 番号や記号は付けない

## 最近の会話の流れ
${contextStr || '（まだコメントがありません）'}

## 盛り上げコメント提案（3つ）:`;
}

async function autoSuggestForSlot(slotId) {
  if (!slots[slotId].connected) return;
  const hype = calcHypeScore(slotId);
  if (hype.level !== 'low') return;

  const prompt = buildAutoSuggestPrompt(slotId);
  const response = await ollamaGenerate(prompt);

  if (response) {
    const lines = response.split('\n')
      .map(l => l.replace(/^[\d\-\.\)]+\s*/, '').trim())
      .filter(l => l.length > 0 && l.length < 60);
    if (lines.length > 0) {
      const suggestions = lines.slice(0, 3).map(text => ({ type: 'auto', text }));
      io.emit('auto-suggestions', { slotId, suggestions, hype });
    }
  }
}

// 定期的に盛り上がり度を計算して配信 + 低いとき自動提案
setInterval(() => {
  for (let i = 0; i < 5; i++) {
    if (!slots[i].connected) continue;
    const hype = calcHypeScore(i);
    io.emit('hype-update', { slotId: i, ...hype });
  }
}, 5000);

setInterval(() => {
  for (let i = 0; i < 5; i++) {
    autoSuggestForSlot(i).catch(() => {});
  }
}, AUTO_SUGGEST_INTERVAL);

// スロットにTikTok Liveを接続
function connectSlot(slotId, username) {
  const slot = slots[slotId];
  if (!slot) return { ok: false, error: '無効なスロットID' };
  if (slot.connected) return { ok: false, error: `スロット${slotId + 1}は既に接続中 (@${slot.username})` };

  slot.username = username;

  try {
    const { WebcastPushConnection } = require('tiktok-live-connector');
    slot.connection = new WebcastPushConnection(username);

    slot.connection.connect().then(state => {
      slot.connected = true;
      slot.viewers = state.roomInfo?.user_count || 0;
      slot.title = state.roomInfo?.title || '';
      console.log(`[TikTok][スロット${slotId + 1}] 接続成功: @${username}`);
      io.emit('slot-status', getSlotInfo(slotId));
    }).catch(err => {
      console.error(`[TikTok][スロット${slotId + 1}] 接続失敗:`, err.message);
      slot.connected = false;
      slot.connection = null;
      slot.username = '';
      io.emit('slot-status', { ...getSlotInfo(slotId), error: err.message });
    });

    // コメント受信
    slot.connection.on('chat', (data) => {
      const comment = {
        id: crypto.randomUUID(),
        slotId,
        username: slot.username,
        userId: data.userId,
        nickname: data.nickname,
        text: data.comment,
        profilePic: data.profilePictureUrl,
        timestamp: Date.now(),
        followRole: data.followRole,
        isSubscriber: data.isSubscriber || false,
        isModerator: data.isModerator || false,
      };

      commentHistory.push(comment);
      if (commentHistory.length > MAX_COMMENTS) {
        commentHistory.splice(0, commentHistory.length - MAX_COMMENTS);
      }

      addHypeEvent(slotId, 'comments');

      // まずキーワード提案で即時配信
      const quickSuggestions = analyzeCommentKeyword(comment);
      io.emit('new-comment', { comment, suggestions: quickSuggestions });

      // 非同期でOllama AI提案を生成して追加配信
      analyzeCommentAI(comment, slotId).then(aiSuggestions => {
        if (aiSuggestions && aiSuggestions.some(s => s.type === 'ai')) {
          io.emit('ai-suggestions', {
            commentId: comment.id,
            slotId,
            suggestions: aiSuggestions,
          });
        }
      }).catch(() => {});
    });

    // ギフト受信
    slot.connection.on('gift', (data) => {
      addHypeEvent(slotId, 'gifts');
      io.emit('new-gift', {
        id: crypto.randomUUID(),
        slotId,
        username: slot.username,
        userId: data.userId,
        nickname: data.nickname,
        giftName: data.giftName,
        giftId: data.giftId,
        repeatCount: data.repeatCount,
        diamondCount: data.diamondCount,
        timestamp: Date.now(),
      });
    });

    // 視聴者数更新
    slot.connection.on('roomUser', (data) => {
      slot.viewers = data.viewerCount;
      io.emit('slot-status', getSlotInfo(slotId));
    });

    // いいね
    slot.connection.on('like', (data) => {
      addHypeEvent(slotId, 'likes');
      io.emit('new-like', {
        slotId,
        username: slot.username,
        nickname: data.nickname,
        likeCount: data.likeCount,
        totalLikes: data.totalLikeCount,
      });
    });

    // 入室
    slot.connection.on('member', (data) => {
      addHypeEvent(slotId, 'members');
      io.emit('new-member', {
        slotId,
        username: slot.username,
        nickname: data.nickname,
      });
    });

    // 切断
    slot.connection.on('disconnected', () => {
      slot.connected = false;
      slot.connection = null;
      console.log(`[TikTok][スロット${slotId + 1}] 切断されました: @${slot.username}`);
      io.emit('slot-status', getSlotInfo(slotId));
    });

    return { ok: true };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

// スロット切断
function disconnectSlot(slotId) {
  const slot = slots[slotId];
  if (!slot) return;
  if (slot.connection) {
    slot.connection.disconnect();
  }
  slot.connection = null;
  slot.connected = false;
  slot.username = '';
  slot.viewers = 0;
  slot.title = '';
  io.emit('slot-status', getSlotInfo(slotId));
}

// スロット情報取得
function getSlotInfo(slotId) {
  const s = slots[slotId];
  return {
    id: s.id,
    connected: s.connected,
    username: s.username,
    viewers: s.viewers,
    title: s.title,
  };
}

function getAllSlotInfo() {
  return slots.map((_, i) => getSlotInfo(i));
}

// ============================================================
//  API
// ============================================================
app.get('/api/templates', (req, res) => res.json(loadTemplates()));

app.post('/api/templates', (req, res) => {
  const templates = loadTemplates();
  const t = { id: Date.now(), category: req.body.category || 'カスタム', text: req.body.text };
  templates.push(t);
  saveTemplates(templates);
  res.json(t);
});

app.delete('/api/templates/:id', (req, res) => {
  let templates = loadTemplates();
  templates = templates.filter(t => t.id !== parseInt(req.params.id));
  saveTemplates(templates);
  res.json({ ok: true });
});

app.get('/api/comments', (req, res) => res.json(commentHistory));

app.get('/api/slots', (req, res) => res.json(getAllSlotInfo()));

// ============================================================
//  Socket.IO
// ============================================================
// 認証なし（ローカル専用）

io.on('connection', (socket) => {
  console.log(`[接続] ${socket.id}`);

  // 初期データ送信
  socket.emit('init-data', {
    slots: getAllSlotInfo(),
    comments: commentHistory,
    templates: loadTemplates(),
    services: {
      whisper: whisperConnected,
      ollama: true, // Ollamaはリクエスト時にフォールバックするので常にtrue
    },
  });

  // スロット接続
  socket.on('slot-connect', ({ slotId, username }) => {
    if (slotId < 0 || slotId >= MAX_SLOTS) {
      socket.emit('slot-error', { slotId, error: '無効なスロットID' });
      return;
    }
    const result = connectSlot(slotId, username.replace(/^@/, ''));
    if (!result.ok) {
      socket.emit('slot-error', { slotId, error: result.error });
    }
  });

  // スロット切断
  socket.on('slot-disconnect', ({ slotId }) => {
    disconnectSlot(slotId);
  });

  // テンプレート更新
  socket.on('update-templates', (templates) => {
    saveTemplates(templates);
    socket.broadcast.emit('templates-updated', templates);
  });

  // デバイス一覧取得
  socket.on('get-devices', () => {
    socket.emit('device-map', deviceSlotMap);
  });

  // ADB設定変更
  socket.on('update-adb-config', (config) => {
    adbConfig = { ...adbConfig, ...config };
    console.log('[ADB] 設定更新:', adbConfig);
  });

  // 1クリックモード: 入力→自動送信
  socket.on('post-comment-auto', async ({ text, slotId }) => {
    const serial = Object.keys(deviceSlotMap)
      .find(s => deviceSlotMap[s] === slotId);
    if (!serial) {
      socket.emit('slot-error', {
        slotId,
        error: `スロット${slotId + 1}にスマホが未接続`
      });
      return;
    }
    try {
      await adbInputAndSend(serial, text.trim());
      io.emit('comment-posted', { text, slotId, timestamp: Date.now() });
    } catch (err) {
      socket.emit('slot-error', { slotId, error: `投稿失敗: ${err.message}` });
    }
  });

  // 2クリックモード: 入力のみ
  socket.on('input-comment', async ({ text, slotId }) => {
    const serial = Object.keys(deviceSlotMap)
      .find(s => deviceSlotMap[s] === slotId);
    if (!serial) {
      socket.emit('slot-error', {
        slotId,
        error: `スロット${slotId + 1}にスマホが未接続`
      });
      return;
    }
    try {
      await adbInputComment(serial, text.trim());
      socket.emit('comment-ready', { text, slotId });
    } catch (err) {
      socket.emit('slot-error', { slotId, error: `入力失敗: ${err.message}` });
    }
  });

  // 2クリックモード: 送信のみ
  socket.on('send-comment', async ({ slotId }) => {
    const serial = Object.keys(deviceSlotMap)
      .find(s => deviceSlotMap[s] === slotId);
    if (!serial) return;
    try {
      await adbSendComment(serial);
      io.emit('comment-posted', { slotId, timestamp: Date.now() });
    } catch (err) {
      socket.emit('slot-error', { slotId, error: `送信失敗: ${err.message}` });
    }
  });

  // コメント履歴クリア
  socket.on('clear-comments', () => {
    commentHistory.length = 0;
    io.emit('comments-cleared');
  });

  socket.on('disconnect', () => {
    console.log(`[切断] ${socket.id}`);
  });
});

// ============================================================
//  サーバー起動
// ============================================================
const PORT = process.env.PORT || 3001;
httpServer.listen(PORT, '0.0.0.0', () => {
  const proto = fs.existsSync(keyPath) ? 'https' : 'http';
  const nets = require('os').networkInterfaces();
  let lanIp = 'localhost';
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) { lanIp = net.address; break; }
    }
  }
  console.log('');
  console.log('==============================================');
  console.log('  TikTok Comment Dashboard - サーバー起動');
  console.log('  5スロット同時配信監視対応');
  console.log('==============================================');
  console.log(`  ポート: ${PORT}`);
  console.log('');
  console.log(`  \x1b[33m\x1b[1mアクセスキー: ${ACCESS_KEY}\x1b[0m`);
  console.log('');
  console.log(`  URL: ${proto}://${lanIp}:${PORT}/?key=${ACCESS_KEY}`);
  console.log('==============================================');
  console.log('');
});
