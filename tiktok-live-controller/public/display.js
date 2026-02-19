// ============================================================
//  TikTok Live Controller - Display (Device A)
//  カメラ映像 + AI顔認識（選択式） + 美顔フィルター + オーバーレイ
// ============================================================

// ========== 顔検出エンジン管理 ==========
let faceEngine = 'mediapipe'; // 'basic' | 'jeeliz' | 'mediapipe'
let JEELIZFACEFILTER = null;
let jeelizReady = false;
let mediapipeFaceMesh = null;
let mediapipeReady = false;
let mediapipeLandmarks = null; // 最新の468点ランドマーク

// スクリプト動的ロード
function loadScript(src) {
  return new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = src;
    s.crossOrigin = 'anonymous';
    s.onload = resolve;
    s.onerror = reject;
    document.head.appendChild(s);
  });
}

// jeeliz読み込み（フランス製）
async function loadJeelizEngine() {
  if (JEELIZFACEFILTER) return true;
  try {
    updateEngineStatus('jeeliz AI 読み込み中...');
    const mod = await import('/facefilter/jeelizFaceFilter.moduleES6.js');
    JEELIZFACEFILTER = mod.JEELIZFACEFILTER || mod.default;
    if (!JEELIZFACEFILTER) throw new Error('export not found');
    return true;
  } catch (e) {
    console.warn('jeeliz load failed:', e);
    updateEngineStatus('jeeliz読み込み失敗');
    return false;
  }
}

// MediaPipe読み込み（Google製）
async function loadMediaPipeEngine() {
  if (mediapipeFaceMesh) return true;
  try {
    updateEngineStatus('MediaPipe 読み込み中...');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4/face_mesh.js');
    mediapipeFaceMesh = new window.FaceMesh({
      locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4/${file}`
    });
    mediapipeFaceMesh.setOptions({
      maxNumFaces: 1,
      refineLandmarks: true,
      minDetectionConfidence: 0.5,
      minTrackingConfidence: 0.5
    });
    mediapipeFaceMesh.onResults((results) => {
      if (results.multiFaceLandmarks && results.multiFaceLandmarks.length > 0) {
        mediapipeLandmarks = results.multiFaceLandmarks[0];
      } else {
        mediapipeLandmarks = null;
      }
    });
    // 初回のモデルロードをトリガー
    if (cameraVideo.readyState >= 2) {
      await mediapipeFaceMesh.send({ image: cameraVideo });
    }
    mediapipeReady = true;
    return true;
  } catch (e) {
    console.warn('MediaPipe load failed:', e);
    updateEngineStatus('MediaPipe読み込み失敗');
    return false;
  }
}

function updateEngineStatus(text) {
  const el = document.getElementById('engine-status');
  if (el) el.textContent = text;
}

// Socket.IO（自動再接続設定 1.2）
const socket = io({
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 5000,
  reconnectionAttempts: 20
});

// ============================================================
//  DOM要素
// ============================================================
const joinScreen = document.getElementById('join-screen');
const checklistScreen = document.getElementById('checklist-screen');
const displayScreen = document.getElementById('display-screen');
const roomInput = document.getElementById('room-input');
const joinBtn = document.getElementById('join-btn');
const joinError = document.getElementById('join-error');
const roomLabel = document.getElementById('room-label');
const connectionStatus = document.getElementById('connection-status');
const faceStatusEl = document.getElementById('face-status-badge');
const cameraVideo = document.getElementById('camera-video');
const beautyCanvas = document.getElementById('beauty-canvas');
const beautyPanel = document.getElementById('beauty-panel');
const beautyToggle = document.getElementById('beauty-toggle');
const beautyCloseBtn = document.getElementById('beauty-close-btn');
const reconnectBanner = document.getElementById('reconnect-banner');

// オーバーレイレイヤー (2.2)
const overlayLayers = [0, 1, 2].map(i => ({
  container: document.getElementById(`video-overlay-${i}`),
  video: document.getElementById(`overlay-video-${i}`),
  playing: false,
  videoId: null
}));

// 美顔スライダー
const sliderKeys = ['smooth','bright','glow','eye','face','chin','jaw','nose','mouth','facelen','blush','lip','temp','sharp','vignette'];
const sliders = {};
const valLabels = {};
sliderKeys.forEach(key => {
  sliders[key] = document.getElementById(key + '-level');
  valLabels[key] = document.getElementById(key + '-val');
});

// チェックリスト
const checklistDoneBtn = document.getElementById('checklist-done-btn');
const checklistSkipBtn = document.getElementById('checklist-skip-btn');
const checkInputs = document.querySelectorAll('.check-input');

// ============================================================
//  状態
// ============================================================
let currentRoomId = null;
let mediaConfig = { videos: [], audio: [] };
let audioPlayers = {};
let preloadedVideos = {};

// 美顔パラメータ
let beautyParams = {
  smooth: 50, bright: 30, glow: 20,
  eye: 15, face: 10, chin: 0, jaw: 0, nose: 0, mouth: 0, facelen: 0,
  blush: 0, lip: 0,
  temp: 0, sharp: 0, vignette: 0
};

// カラーフィルター
let currentColorFilter = 'none';
let colorFilterIntensity = 100;
const colorFilters = {
  none:     { name: 'なし', steps: [] },
  natural:  { name: 'ナチュラル', steps: [
    { op: 'overlay', color: 'rgba(255,235,215,0.08)' },
    { op: 'screen', color: 'rgba(255,248,240,0.04)' }
  ]},
  clear:    { name: 'クリア', steps: [
    { op: 'overlay', color: 'rgba(210,235,255,0.07)' },
    { op: 'screen', color: 'rgba(240,250,255,0.05)' }
  ]},
  peach:    { name: 'ピーチ', steps: [
    { op: 'overlay', color: 'rgba(255,200,180,0.10)' },
    { op: 'screen', color: 'rgba(255,220,210,0.05)' }
  ]},
  sunshine: { name: '日差し', steps: [
    { op: 'overlay', color: 'rgba(255,210,100,0.12)' },
    { op: 'screen', color: 'rgba(255,245,200,0.06)' }
  ]},
  spring:   { name: '春', steps: [
    { op: 'overlay', color: 'rgba(180,255,180,0.07)' },
    { op: 'screen', color: 'rgba(230,255,240,0.04)' }
  ]},
  retro:    { name: 'レトロ', steps: [
    { op: 'multiply', color: 'rgba(240,220,180,0.12)' },
    { op: 'overlay', color: 'rgba(200,170,130,0.08)' },
    { op: 'saturation', color: 'rgb(160,160,160)', alpha: 0.25 }
  ]},
  cinema:   { name: 'シネマ', steps: [
    { op: 'overlay', color: 'rgba(50,80,120,0.10)' },
    { op: 'multiply', color: 'rgba(230,230,250,0.06)' },
    { op: 'soft-light', color: 'rgba(20,40,80,0.05)' }
  ]},
  mono:     { name: 'モノクロ', steps: [
    { op: 'saturation', color: 'rgb(128,128,128)', alpha: 1.0 }
  ]},
  pink:     { name: 'ピンク', steps: [
    { op: 'overlay', color: 'rgba(255,180,200,0.09)' },
    { op: 'screen', color: 'rgba(255,220,230,0.05)' }
  ]},
  paris:    { name: 'パリ', steps: [
    { op: 'overlay', color: 'rgba(230,210,220,0.08)' },
    { op: 'screen', color: 'rgba(255,240,245,0.04)' },
    { op: 'soft-light', color: 'rgba(200,180,210,0.06)' }
  ]},
  tokyo:    { name: '東京', steps: [
    { op: 'overlay', color: 'rgba(80,140,200,0.08)' },
    { op: 'multiply', color: 'rgba(220,230,245,0.05)' },
    { op: 'soft-light', color: 'rgba(40,60,100,0.04)' }
  ]}
};

// ズーム
let cameraZoom = 1.0;
let cameraStream = null;

// 顔検出データ (jeeliz用)
let faceData = {
  detected: false,
  x: 0, y: 0,
  s: 0,
  rx: 0, ry: 0, rz: 0
};

// MediaPipe送信間隔制御
let mpLastSend = 0;
const mpInterval = 50; // 50ms間隔（20fps）

// Canvas描画用
const ctx = beautyCanvas.getContext('2d');
let tempCanvas = null;
let tempCtx = null;
let smallCanvas = null;
let smallCtx = null;
let animFrameId = null;

// グラデーションキャッシュ (3.2)
let gradientCache = {
  blush: { key: '', left: null, right: null },
  nose: { key: '', left: null, right: null, center: null },
  vignette: { key: '', grad: null }
};

// ============================================================
//  入室 → チェックリスト → 配信画面
// ============================================================
joinBtn.addEventListener('click', joinRoom);
roomInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') joinRoom();
});

function joinRoom() {
  const roomId = roomInput.value.trim();
  if (!roomId) {
    joinError.textContent = 'ルームIDを入力してください';
    return;
  }
  joinError.textContent = '';
  currentRoomId = roomId;

  // チェックリスト画面へ
  joinScreen.classList.remove('active');
  checklistScreen.classList.add('active');
}

// チェックリスト
checkInputs.forEach(input => {
  input.addEventListener('change', () => {
    const allChecked = [...checkInputs].every(i => i.checked);
    checklistDoneBtn.disabled = !allChecked;
  });
});

checklistDoneBtn.addEventListener('click', startDisplay);
checklistSkipBtn.addEventListener('click', startDisplay);

function startDisplay() {
  // Socket.IO ルーム参加
  socket.emit('join-room', { roomId: currentRoomId, role: 'display' });

  checklistScreen.classList.remove('active');
  displayScreen.classList.add('active');
  roomLabel.textContent = `Room: ${currentRoomId}`;

  // カメラ起動 → 顔検出初期化 → 描画ループ
  initCamera();
  fetchMedia();
}

// ============================================================
//  美顔パネル
// ============================================================
beautyToggle.addEventListener('click', () => {
  beautyPanel.classList.toggle('hidden');
});
beautyCloseBtn.addEventListener('click', () => {
  beautyPanel.classList.add('hidden');
});

// パネルタブ切替
document.querySelectorAll('.panel-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.panel-tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.panel-content').forEach(c => c.classList.remove('active'));
    tab.classList.add('active');
    document.getElementById('panel-' + tab.dataset.panel).classList.add('active');
  });
});

// ========== サブカテゴリ切り替え ==========
document.querySelectorAll('.beauty-subcat').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.beauty-subcat').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.subcat-content').forEach(c => c.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById('subcat-' + btn.dataset.subcat).classList.add('active');
  });
});

// ========== カラーフィルター選択 ==========
document.querySelectorAll('.cf-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    currentColorFilter = btn.dataset.filter;
    document.querySelectorAll('.cf-btn').forEach(b => b.classList.remove('selected'));
    btn.classList.add('selected');
  });
});
const filterIntensitySlider = document.getElementById('filter-intensity');
const filterIntensityVal = document.getElementById('filter-intensity-val');
if (filterIntensitySlider) {
  filterIntensitySlider.addEventListener('input', () => {
    colorFilterIntensity = parseInt(filterIntensitySlider.value);
    filterIntensityVal.textContent = colorFilterIntensity + '%';
  });
}

// ========== AI顔検出エンジン選択 ==========
document.querySelectorAll('.engine-card').forEach(card => {
  card.addEventListener('click', async () => {
    const engine = card.dataset.engine;
    if (engine === faceEngine) return;

    // ローディング表示
    card.classList.add('loading');

    let ok = true;
    if (engine === 'jeeliz') {
      ok = await loadJeelizEngine();
      if (ok && !jeelizReady) {
        ok = await initJeelizDetection();
      }
    } else if (engine === 'mediapipe') {
      ok = await loadMediaPipeEngine();
    }

    card.classList.remove('loading');

    if (ok) {
      faceEngine = engine;
      document.querySelectorAll('.engine-card').forEach(c => c.classList.remove('selected'));
      card.classList.add('selected');

      const names = { basic: '基本モード', jeeliz: 'jeeliz AI (FR)', mediapipe: 'MediaPipe (Google)' };
      updateEngineStatus(names[engine] + ' 使用中');
      faceStatusEl.textContent = names[engine];
      faceStatusEl.style.color = engine === 'basic' ? '#888' : '#4caf50';
    }
  });
});

// カメラ前後切替
let facingMode = 'user';
document.getElementById('flip-btn').addEventListener('click', async () => {
  facingMode = facingMode === 'user' ? 'environment' : 'user';
  if (cameraStream) {
    cameraStream.getTracks().forEach(t => t.stop());
  }
  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: facingMode, width: { ideal: 1920 }, height: { ideal: 1080 } }, audio: false
    });
    cameraStream = stream;
    cameraVideo.srcObject = stream;
    // フロントカメラのみ反転
    beautyCanvas.style.transform = facingMode === 'user' ? 'scaleX(-1)' : 'none';
  } catch (err) {
    console.error('カメラ切替エラー:', err);
  }
});

// ズームスライダー
const zoomSlider = document.getElementById('zoom-level');
const zoomVal = document.getElementById('zoom-val');
zoomSlider.addEventListener('input', () => {
  cameraZoom = parseInt(zoomSlider.value) / 10;
  zoomVal.textContent = cameraZoom.toFixed(1) + 'x';

  // ハードウェアズームを試行
  if (cameraStream) {
    const track = cameraStream.getVideoTracks()[0];
    const caps = track.getCapabilities ? track.getCapabilities() : {};
    if (caps.zoom) {
      track.applyConstraints({ advanced: [{ zoom: cameraZoom }] }).catch(() => {});
    }
  }
});

// スライダー連動
Object.keys(sliders).forEach(key => {
  if (!sliders[key]) return;
  sliders[key].addEventListener('input', () => {
    beautyParams[key] = parseInt(sliders[key].value);
    valLabels[key].textContent = key === 'temp' ? beautyParams[key] : beautyParams[key] + '%';
  });
});

// プリセット
const presets = {
  off:      { smooth:0,  bright:0,  glow:0,  eye:0,  face:0,  chin:0,  jaw:0,  nose:0,  mouth:0,  facelen:0,  blush:0,  lip:0,  temp:0,  sharp:0,  vignette:0 },
  natural:  { smooth:30, bright:15, glow:10, eye:0,  face:0,  chin:0,  jaw:0,  nose:0,  mouth:0,  facelen:0,  blush:0,  lip:0,  temp:0,  sharp:0,  vignette:0 },
  standard: { smooth:50, bright:30, glow:20, eye:15, face:10, chin:5,  jaw:10, nose:5,  mouth:0,  facelen:0,  blush:15, lip:10, temp:5,  sharp:0,  vignette:0 },
  max:      { smooth:80, bright:50, glow:40, eye:40, face:30, chin:20, jaw:25, nose:20, mouth:15, facelen:10, blush:40, lip:30, temp:10, sharp:20, vignette:10 },
  korean:   { smooth:80, bright:45, glow:30, eye:10, face:15, chin:15, jaw:20, nose:15, mouth:0,  facelen:10, blush:10, lip:5,  temp:-5, sharp:0,  vignette:0 },
  gal:      { smooth:40, bright:20, glow:15, eye:35, face:10, chin:5,  jaw:5,  nose:0,  mouth:10, facelen:0,  blush:40, lip:35, temp:10, sharp:10, vignette:5 }
};

// プリセットボタン（TikTok風エフェクトアイコン）
document.querySelectorAll('.effect-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const p = presets[btn.dataset.preset];
    if (!p) return;
    beautyParams = { ...p };
    Object.keys(sliders).forEach(key => {
      if (!sliders[key]) return;
      sliders[key].value = beautyParams[key];
      valLabels[key].textContent = key === 'temp' ? beautyParams[key] : beautyParams[key] + '%';
    });
    document.querySelectorAll('.effect-circle').forEach(c => c.classList.remove('active-effect'));
    btn.querySelector('.effect-circle').classList.add('active-effect');
  });
});

// ============================================================
//  カメラ起動 + jeeliz顔検出初期化
// ============================================================
async function initCamera() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: 'user', width: { ideal: 1920 }, height: { ideal: 1080 } },
      audio: false
    });
    cameraStream = stream;
    cameraVideo.srcObject = stream;

    // ハードウェアズーム対応チェック
    const track = stream.getVideoTracks()[0];
    const caps = track.getCapabilities ? track.getCapabilities() : {};
    if (caps.zoom) {
      document.getElementById('zoom-level').min = Math.round(caps.zoom.min * 10);
      document.getElementById('zoom-level').max = Math.round(caps.zoom.max * 10);
      document.getElementById('zoom-level').value = Math.round(caps.zoom.min * 10);
    }

    cameraVideo.addEventListener('loadedmetadata', async () => {
      const vw = cameraVideo.videoWidth;
      const vh = cameraVideo.videoHeight;

      beautyCanvas.width = vw;
      beautyCanvas.height = vh;

      tempCanvas = document.createElement('canvas');
      tempCanvas.width = vw;
      tempCanvas.height = vh;
      tempCtx = tempCanvas.getContext('2d');

      smallCanvas = document.createElement('canvas');
      smallCtx = smallCanvas.getContext('2d');

      // jeeliz顔検出を初期化
      await initFaceDetection();

      // 描画ループ開始
      startRenderLoop();
    });
  } catch (err) {
    console.error('カメラ起動エラー:', err);
    faceStatusEl.textContent = 'カメラエラー';
  }
}

async function initFaceDetection() {
  // MediaPipeをデフォルトで自動ロード
  const ok = await loadMediaPipeEngine();
  if (ok) {
    faceStatusEl.textContent = 'MediaPipe (Google)';
    faceStatusEl.style.color = '#4caf50';
    updateEngineStatus('MediaPipe (Google) 使用中');
  } else {
    faceEngine = 'basic';
    faceStatusEl.textContent = '基本モード';
    updateEngineStatus('MediaPipe読み込み失敗・基本モード');
    // HTML上のselected状態も修正
    document.querySelectorAll('.engine-card').forEach(c => c.classList.remove('selected'));
    document.querySelector('[data-engine="basic"]').classList.add('selected');
  }
}

// jeeliz初期化（エンジン選択時に呼ばれる）
function initJeelizDetection() {
  if (!JEELIZFACEFILTER) return Promise.resolve(false);
  return new Promise((resolve) => {
    try {
      JEELIZFACEFILTER.init({
        canvasId: 'jeeliz-canvas',
        NNCPath: '/nn/',
        maxFacesDetected: 1,
        scanSettings: { nDetectsPerLoop: 3, threshold: 0.6 },
        videoSettings: { videoElement: cameraVideo },
        callbackReady: (errCode) => {
          if (errCode) {
            console.warn('jeeliz init error:', errCode);
            updateEngineStatus('jeeliz初期化エラー');
            resolve(false);
          } else {
            jeelizReady = true;
            updateEngineStatus('jeeliz AI (FR) 使用中');
            resolve(true);
          }
        },
        callbackTrack: (detectState) => {
          faceData.detected = detectState.detected > 0.5;
          if (faceData.detected) {
            faceData.x = detectState.x;
            faceData.y = detectState.y;
            faceData.s = detectState.s;
            faceData.rx = detectState.rx;
            faceData.ry = detectState.ry;
            faceData.rz = detectState.rz;
          }
        }
      });
    } catch (err) {
      console.warn('jeeliz init exception:', err);
      updateEngineStatus('jeeliz初期化エラー');
      resolve(false);
    }
  });
}

// ============================================================
//  描画ループ - 美顔フィルター適用
// ============================================================
function startRenderLoop() {
  function render() {
    animFrameId = requestAnimationFrame(render);
    if (cameraVideo.readyState < 2) return;

    // MediaPipeにフレーム送信（間引き）
    if (faceEngine === 'mediapipe' && mediapipeReady && mediapipeFaceMesh) {
      const now = performance.now();
      if (now - mpLastSend > mpInterval) {
        mpLastSend = now;
        mediapipeFaceMesh.send({ image: cameraVideo }).catch(() => {});
      }
    }

    const w = beautyCanvas.width;
    const h = beautyCanvas.height;

    // 元映像を描画（ズーム適用）
    if (cameraZoom > 1.01) {
      // ズームイン：中央をクロップして拡大
      const zw = w / cameraZoom;
      const zh = h / cameraZoom;
      const zx = (w - zw) / 2;
      const zy = (h - zh) / 2;
      ctx.drawImage(cameraVideo, zx, zy, zw, zh, 0, 0, w, h);
    } else if (cameraZoom < 0.99) {
      // ズームアウト：映像を縮小して中央配置（周囲は黒）
      ctx.fillStyle = '#000';
      ctx.fillRect(0, 0, w, h);
      const dw = w * cameraZoom;
      const dh = h * cameraZoom;
      const dx = (w - dw) / 2;
      const dy = (h - dh) / 2;
      ctx.drawImage(cameraVideo, 0, 0, w, h, dx, dy, dw, dh);
    } else {
      ctx.drawImage(cameraVideo, 0, 0, w, h);
    }

    // 顔の位置をCanvas座標に変換
    const face = getFaceCoords(w, h);

    // 美肌（ぼかしブレンド - 顔領域のみ）
    if (beautyParams.smooth > 0) {
      applySkinSmoothing(w, h, face);
    }

    // 美白（明度アップ - 顔領域のみ）
    if (beautyParams.bright > 0) {
      applyBrightening(w, h, face);
    }

    // グロー（ソフトフォーカス）
    if (beautyParams.glow > 0) {
      applyGlow(w, h);
    }

    // 目の大きさ
    if (beautyParams.eye > 0 && face) {
      applyEyeEnlarge(w, h, face);
    }

    // 小顔
    if (beautyParams.face > 0 && face) {
      applyFaceSlim(w, h, face);
    }

    // チーク
    if (beautyParams.blush > 0 && face && face.leftCheek) {
      applyBlush(w, h, face);
    }

    // リップ
    if (beautyParams.lip > 0 && face && face.lips) {
      applyLipColor(w, h, face);
    }

    // 鼻筋コントゥア
    if (beautyParams.nose > 0 && face && face.noseBridge) {
      applyNoseContour(w, h, face);
    }

    // あご（あご先端を上に詰める）
    if (beautyParams.chin > 0 && face && face.chin) {
      applyChinSlim(w, h, face);
    }

    // エラ（下顎を狭める）
    if (beautyParams.jaw > 0 && face && face.jawLeft) {
      applyJawSlim(w, h, face);
    }

    // 口（口周辺を強調）
    if (beautyParams.mouth > 0 && face && face.mouthCenter) {
      applyMouthEnhance(w, h, face);
    }

    // 面長（顔の縦比率を縮める）
    if (beautyParams.facelen > 0 && face && face.forehead) {
      applyFaceLenShorten(w, h, face);
    }

    // カラーフィルター
    if (currentColorFilter !== 'none') {
      applyColorFilter(w, h);
    }

    // 色温度
    if (beautyParams.temp !== 0) {
      applyTemperature(w, h);
    }

    // 質感（コントラスト強調）
    if (beautyParams.sharp > 0) {
      applyContrast(w, h);
    }

    // ビネット
    if (beautyParams.vignette > 0) {
      applyVignette(w, h);
    }
  }
  render();
  requestWakeLock();
}

// ============================================================
//  顔座標変換（3エンジン対応）
// ============================================================
function getFaceCoords(w, h) {
  // MediaPipe: 468点ランドマークから高精度に取得
  if (faceEngine === 'mediapipe' && mediapipeReady && mediapipeLandmarks) {
    const lm = mediapipeLandmarks;
    // 鼻先(1)を顔中心に
    const noseTip = lm[1];
    const cx = noseTip.x * w;
    const cy = noseTip.y * h;
    // 顔幅: 左端(234) ↔ 右端(454)
    const faceW = Math.abs(lm[454].x - lm[234].x) * w;
    const radius = faceW / 2;
    // 左目中心(159), 右目中心(386)
    const le = lm[159];
    const re = lm[386];
    // 目のサイズ: 上下幅
    const leSize = Math.abs(lm[145].y - lm[159].y) * h * 1.5;
    const reSize = Math.abs(lm[374].y - lm[386].y) * h * 1.5;
    // チーク位置 (123=左頬, 352=右頬)
    const leftCheek  = { x: lm[123].x * w, y: lm[123].y * h };
    const rightCheek = { x: lm[352].x * w, y: lm[352].y * h };
    // リップ輪郭 (外側ループ)
    const lipIndices = [61,146,91,181,84,17,314,405,321,375,291,409,270,269,267,0,37,39,40,185];
    const lips = lipIndices.map(i => ({ x: lm[i].x * w, y: lm[i].y * h }));
    // 鼻: ブリッジ中心(6), 幅(48↔278), 長さ(6↔1)
    const noseBridge = { x: lm[6].x * w, y: lm[6].y * h };
    const noseWidth  = Math.abs(lm[48].x - lm[278].x) * w;
    const noseLength = Math.abs(lm[6].y - lm[1].y) * h;

    // あご (152=あご先端)
    const chin = { x: lm[152].x * w, y: lm[152].y * h };
    // エラ (132=左エラ, 361=右エラ)
    const jawLeft  = { x: lm[132].x * w, y: lm[132].y * h };
    const jawRight = { x: lm[361].x * w, y: lm[361].y * h };
    // 口 (13=上唇中央, 14=下唇中央, 78=左端, 308=右端)
    const mouthCenter = { x: (lm[13].x + lm[14].x) / 2 * w, y: (lm[13].y + lm[14].y) / 2 * h };
    const mouthW = Math.abs(lm[308].x - lm[78].x) * w;
    const mouthH = Math.abs(lm[14].y - lm[13].y) * h;
    // おでこ (10=おでこ上端)
    const forehead = { x: lm[10].x * w, y: lm[10].y * h };

    return {
      cx, cy, radius,
      leftEye:  { x: le.x * w, y: le.y * h },
      rightEye: { x: re.x * w, y: re.y * h },
      eyeSize: Math.max(leSize, reSize),
      leftCheek, rightCheek, lips, noseBridge, noseWidth, noseLength,
      chin, jawLeft, jawRight, mouthCenter, mouthW, mouthH, forehead
    };
  }

  // jeeliz: AI検出位置から推定
  if (faceEngine === 'jeeliz' && jeelizReady && faceData.detected) {
    const cx = (1 - faceData.x) / 2 * w;
    const cy = (1 - faceData.y) / 2 * h;
    const radius = faceData.s * w * 0.6;
    return {
      cx, cy, radius,
      leftEye:  { x: cx - radius * 0.3, y: cy - radius * 0.1 },
      rightEye: { x: cx + radius * 0.3, y: cy - radius * 0.1 },
      eyeSize: radius * 0.2
    };
  }

  // 基本モード: 画面中央付近に顔があると仮定
  const cx = w * 0.5;
  const cy = h * 0.38;
  const radius = w * 0.25;
  return {
    cx, cy, radius,
    leftEye:  { x: cx - radius * 0.3, y: cy - radius * 0.1 },
    rightEye: { x: cx + radius * 0.3, y: cy - radius * 0.1 },
    eyeSize: radius * 0.2
  };
}

// ============================================================
//  美肌フィルター - シングルパス最適化 (3.1)
// ============================================================
function applySkinSmoothing(w, h, face) {
  const intensity = beautyParams.smooth / 100;
  const scale = Math.max(0.06, 0.25 - intensity * 0.22);
  const sw = Math.max(1, Math.floor(w * scale));
  const sh = Math.max(1, Math.floor(h * scale));

  smallCanvas.width = sw;
  smallCanvas.height = sh;

  // シングルパス: 縮小→拡大（ダブルダウンスケール廃止 3.1）
  smallCtx.drawImage(beautyCanvas, 0, 0, sw, sh);
  tempCtx.drawImage(smallCanvas, 0, 0, w, h);

  const hasAI = (faceEngine === 'jeeliz' && jeelizReady && faceData.detected) ||
                (faceEngine === 'mediapipe' && mediapipeReady && mediapipeLandmarks);
  if (face && hasAI) {
    ctx.save();
    ctx.beginPath();
    ctx.ellipse(face.cx, face.cy, face.radius * 1.1, face.radius * 1.4, 0, 0, Math.PI * 2);
    ctx.clip();
    ctx.globalAlpha = intensity * 0.75;
    ctx.drawImage(tempCanvas, 0, 0, w, h);
    ctx.restore();
    ctx.globalAlpha = 1.0;
  } else {
    ctx.globalAlpha = intensity * 0.65;
    ctx.drawImage(tempCanvas, 0, 0, w, h);
    ctx.globalAlpha = 1.0;
  }
}

// ============================================================
//  美白フィルター - 顔領域のみ明るく
// ============================================================
function applyBrightening(w, h, face) {
  const intensity = beautyParams.bright / 100;

  const hasAI2 = (faceEngine === 'jeeliz' && jeelizReady && faceData.detected) ||
                 (faceEngine === 'mediapipe' && mediapipeReady && mediapipeLandmarks);
  if (face && hasAI2) {
    ctx.save();
    ctx.beginPath();
    ctx.ellipse(face.cx, face.cy, face.radius * 1.1, face.radius * 1.4, 0, 0, Math.PI * 2);
    ctx.clip();
    ctx.globalCompositeOperation = 'screen';
    ctx.fillStyle = `rgba(255, 240, 235, ${intensity * 0.18})`;
    ctx.fillRect(0, 0, w, h);
    ctx.globalCompositeOperation = 'overlay';
    ctx.fillStyle = `rgba(255, 220, 200, ${intensity * 0.06})`;
    ctx.fillRect(0, 0, w, h);
    ctx.restore();
    ctx.globalCompositeOperation = 'source-over';
  } else {
    ctx.globalCompositeOperation = 'screen';
    ctx.fillStyle = `rgba(255, 240, 235, ${intensity * 0.15})`;
    ctx.fillRect(0, 0, w, h);
    ctx.globalCompositeOperation = 'overlay';
    ctx.fillStyle = `rgba(255, 220, 200, ${intensity * 0.05})`;
    ctx.fillRect(0, 0, w, h);
    ctx.globalCompositeOperation = 'source-over';
  }
}

// ============================================================
//  グロー効果 - ソフトな光
// ============================================================
function applyGlow(w, h) {
  const intensity = beautyParams.glow / 100;
  const gw = Math.max(1, Math.floor(w * 0.04));
  const gh = Math.max(1, Math.floor(h * 0.04));

  smallCanvas.width = gw;
  smallCanvas.height = gh;
  smallCtx.drawImage(beautyCanvas, 0, 0, gw, gh);
  tempCtx.drawImage(smallCanvas, 0, 0, w, h);

  ctx.globalCompositeOperation = 'lighten';
  ctx.globalAlpha = intensity * 0.35;
  ctx.drawImage(tempCanvas, 0, 0, w, h);

  ctx.globalCompositeOperation = 'screen';
  ctx.globalAlpha = intensity * 0.12;
  ctx.drawImage(tempCanvas, 0, 0, w, h);

  ctx.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 1.0;
}

// ============================================================
//  目の拡大 - 検出位置で正確に
// ============================================================
function applyEyeEnlarge(w, h, face) {
  const intensity = beautyParams.eye / 100;
  const expand = 1 + intensity * 0.18;
  const eyeR = face.eyeSize;

  tempCtx.clearRect(0, 0, w, h);
  tempCtx.drawImage(beautyCanvas, 0, 0);

  // 左目
  enlargeRegion(face.leftEye.x, face.leftEye.y, eyeR, expand, w, h);
  // 右目
  enlargeRegion(face.rightEye.x, face.rightEye.y, eyeR, expand, w, h);
}

function enlargeRegion(cx, cy, radius, expand, w, h) {
  const srcR = radius;
  const dstR = radius * expand;
  const sx = Math.max(0, cx - srcR);
  const sy = Math.max(0, cy - srcR);
  const dx = cx - dstR;
  const dy = cy - dstR;

  ctx.save();
  ctx.beginPath();
  ctx.arc(cx, cy, dstR, 0, Math.PI * 2);
  ctx.clip();
  ctx.drawImage(tempCanvas, sx, sy, srcR * 2, srcR * 2, dx, dy, dstR * 2, dstR * 2);
  ctx.restore();
}

// ============================================================
//  小顔 - 顔輪郭を内側に縮小
// ============================================================
function applyFaceSlim(w, h, face) {
  const intensity = beautyParams.face / 100;
  const shrink = 1 - intensity * 0.08;

  const faceW = face.radius * 2;
  const faceH = face.radius * 2.5;
  const sx = face.cx - faceW / 2;
  const sy = face.cy - faceH / 2;

  const destW = faceW * shrink;
  const destH = faceH;
  const destX = face.cx - destW / 2;
  const destY = sy;

  tempCtx.clearRect(0, 0, w, h);
  tempCtx.drawImage(beautyCanvas, 0, 0);

  ctx.drawImage(tempCanvas, sx, sy, faceW, faceH, destX, destY, destW, destH);
}

// ============================================================
//  チーク - 頬にピンクの血色感 (グラデーションキャッシュ 3.2)
// ============================================================
function applyBlush(w, h, face) {
  const intensity = beautyParams.blush / 100;
  const r = face.radius * 0.35;

  // キャッシュキー: 顔位置が閾値以上変化したら再生成
  const cacheKey = `${Math.round(face.leftCheek.x / 5)},${Math.round(face.leftCheek.y / 5)},${Math.round(r / 3)}`;
  if (gradientCache.blush.key !== cacheKey) {
    const lGrad = ctx.createRadialGradient(face.leftCheek.x, face.leftCheek.y, 0, face.leftCheek.x, face.leftCheek.y, r);
    lGrad.addColorStop(0, `rgba(255, 120, 110, ${intensity * 0.3})`);
    lGrad.addColorStop(0.6, `rgba(255, 140, 130, ${intensity * 0.15})`);
    lGrad.addColorStop(1, 'rgba(255, 130, 120, 0)');
    const rGrad = ctx.createRadialGradient(face.rightCheek.x, face.rightCheek.y, 0, face.rightCheek.x, face.rightCheek.y, r);
    rGrad.addColorStop(0, `rgba(255, 120, 110, ${intensity * 0.3})`);
    rGrad.addColorStop(0.6, `rgba(255, 140, 130, ${intensity * 0.15})`);
    rGrad.addColorStop(1, 'rgba(255, 130, 120, 0)');
    gradientCache.blush = { key: cacheKey, left: lGrad, right: rGrad, lc: face.leftCheek, rc: face.rightCheek, r };
  }

  const cache = gradientCache.blush;
  ctx.save();
  ctx.fillStyle = cache.left;
  ctx.fillRect(cache.lc.x - cache.r, cache.lc.y - cache.r, cache.r * 2, cache.r * 2);
  ctx.fillStyle = cache.right;
  ctx.fillRect(cache.rc.x - cache.r, cache.rc.y - cache.r, cache.r * 2, cache.r * 2);
  ctx.restore();
}

// ============================================================
//  リップカラー - 唇に色付け
// ============================================================
function applyLipColor(w, h, face) {
  const intensity = beautyParams.lip / 100;

  ctx.save();
  ctx.globalCompositeOperation = 'overlay';
  ctx.globalAlpha = intensity * 0.55;
  ctx.fillStyle = 'rgba(200, 50, 60, 1)';

  ctx.beginPath();
  face.lips.forEach((pt, i) => {
    if (i === 0) ctx.moveTo(pt.x, pt.y);
    else ctx.lineTo(pt.x, pt.y);
  });
  ctx.closePath();
  ctx.fill();

  // 光沢感を追加
  ctx.globalCompositeOperation = 'screen';
  ctx.globalAlpha = intensity * 0.12;
  ctx.fillStyle = 'rgba(255, 200, 200, 1)';
  ctx.fill();

  ctx.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 1.0;
  ctx.restore();
}

// ============================================================
//  鼻筋コントゥア (グラデーションキャッシュ 3.2)
// ============================================================
function applyNoseContour(w, h, face) {
  const intensity = beautyParams.nose / 100;
  const nb = face.noseBridge;
  const nw = face.noseWidth * 0.5;
  const nh = face.noseLength * 1.8;

  const cacheKey = `${Math.round(nb.x / 5)},${Math.round(nb.y / 5)},${Math.round(nw / 3)}`;
  if (gradientCache.nose.key !== cacheKey) {
    const leftGrad = ctx.createLinearGradient(nb.x - nw, nb.y, nb.x - nw * 0.2, nb.y);
    leftGrad.addColorStop(0, 'rgba(0,0,0,0)');
    leftGrad.addColorStop(0.5, `rgba(80,60,50,${intensity * 0.15})`);
    leftGrad.addColorStop(1, 'rgba(0,0,0,0)');
    const rightGrad = ctx.createLinearGradient(nb.x + nw * 0.2, nb.y, nb.x + nw, nb.y);
    rightGrad.addColorStop(0, 'rgba(0,0,0,0)');
    rightGrad.addColorStop(0.5, `rgba(80,60,50,${intensity * 0.15})`);
    rightGrad.addColorStop(1, 'rgba(0,0,0,0)');
    const centerGrad = ctx.createLinearGradient(nb.x - nw * 0.12, nb.y, nb.x + nw * 0.12, nb.y);
    centerGrad.addColorStop(0, 'rgba(255,255,255,0)');
    centerGrad.addColorStop(0.5, `rgba(255,255,255,${intensity * 0.1})`);
    centerGrad.addColorStop(1, 'rgba(255,255,255,0)');
    gradientCache.nose = { key: cacheKey, left: leftGrad, right: rightGrad, center: centerGrad, nb, nw, nh };
  }

  const cache = gradientCache.nose;
  ctx.save();
  ctx.fillStyle = cache.left;
  ctx.fillRect(cache.nb.x - cache.nw, cache.nb.y - cache.nh / 2, cache.nw * 0.8, cache.nh);
  ctx.fillStyle = cache.right;
  ctx.fillRect(cache.nb.x + cache.nw * 0.2, cache.nb.y - cache.nh / 2, cache.nw * 0.8, cache.nh);
  ctx.fillStyle = cache.center;
  ctx.fillRect(cache.nb.x - cache.nw * 0.12, cache.nb.y - cache.nh / 2, cache.nw * 0.24, cache.nh);
  ctx.restore();
}

// ============================================================
//  あご - あご先端を上に詰めて短く
// ============================================================
function applyChinSlim(w, h, face) {
  const intensity = beautyParams.chin / 100;
  const chin = face.chin;
  const rw = face.radius * 0.8;
  const rh = face.radius * 0.6;
  const shift = rh * intensity * 0.18;

  tempCtx.clearRect(0, 0, w, h);
  tempCtx.drawImage(beautyCanvas, 0, 0);

  ctx.save();
  ctx.beginPath();
  ctx.ellipse(chin.x, chin.y, rw, rh, 0, 0, Math.PI * 2);
  ctx.clip();
  // あご領域を上にシフト（短縮効果）
  ctx.drawImage(tempCanvas,
    chin.x - rw, chin.y - rh, rw * 2, rh * 2,
    chin.x - rw, chin.y - rh - shift, rw * 2, rh * 2
  );
  ctx.restore();
}

// ============================================================
//  エラ - 下顎の幅を狭める
// ============================================================
function applyJawSlim(w, h, face) {
  const intensity = beautyParams.jaw / 100;
  const shrink = intensity * 0.10;

  tempCtx.clearRect(0, 0, w, h);
  tempCtx.drawImage(beautyCanvas, 0, 0);

  // 左エラ: 右に押し込む
  const ljx = face.jawLeft.x;
  const ljy = face.jawLeft.y;
  const jr = face.radius * 0.5;
  const offset = face.radius * shrink;

  ctx.save();
  ctx.beginPath();
  ctx.ellipse(ljx, ljy, jr, jr * 1.3, 0, 0, Math.PI * 2);
  ctx.clip();
  ctx.drawImage(tempCanvas,
    ljx - jr, ljy - jr * 1.3, jr * 2, jr * 2.6,
    ljx - jr + offset, ljy - jr * 1.3, jr * 2, jr * 2.6
  );
  ctx.restore();

  // 右エラ: 左に押し込む
  const rjx = face.jawRight.x;
  const rjy = face.jawRight.y;

  ctx.save();
  ctx.beginPath();
  ctx.ellipse(rjx, rjy, jr, jr * 1.3, 0, 0, Math.PI * 2);
  ctx.clip();
  ctx.drawImage(tempCanvas,
    rjx - jr, rjy - jr * 1.3, jr * 2, jr * 2.6,
    rjx - jr - offset, rjy - jr * 1.3, jr * 2, jr * 2.6
  );
  ctx.restore();
}

// ============================================================
//  口 - 口周辺を拡大（ぷっくり唇）
// ============================================================
function applyMouthEnhance(w, h, face) {
  const intensity = beautyParams.mouth / 100;
  const expand = 1 + intensity * 0.12;
  const mc = face.mouthCenter;
  const mr = Math.max(face.mouthW, face.mouthH) * 0.8;

  tempCtx.clearRect(0, 0, w, h);
  tempCtx.drawImage(beautyCanvas, 0, 0);

  enlargeRegion(mc.x, mc.y, mr, expand, w, h);
}

// ============================================================
//  面長 - 顔の縦を短縮
// ============================================================
function applyFaceLenShorten(w, h, face) {
  const intensity = beautyParams.facelen / 100;
  const fh = face.forehead;
  const chin = face.chin;

  // 顔の上半分と下半分をそれぞれ中央に向かって圧縮
  const faceCy = (fh.y + chin.y) / 2;
  const compress = intensity * 0.06;

  tempCtx.clearRect(0, 0, w, h);
  tempCtx.drawImage(beautyCanvas, 0, 0);

  // 上半分（おでこ→中央）を下にずらす
  const topH = faceCy - fh.y;
  const topShift = topH * compress;
  ctx.save();
  ctx.beginPath();
  ctx.rect(face.cx - face.radius * 1.2, fh.y, face.radius * 2.4, topH);
  ctx.clip();
  ctx.drawImage(tempCanvas,
    face.cx - face.radius * 1.2, fh.y, face.radius * 2.4, topH,
    face.cx - face.radius * 1.2, fh.y + topShift, face.radius * 2.4, topH
  );
  ctx.restore();

  // 下半分（中央→あご）を上にずらす
  const botH = chin.y - faceCy;
  const botShift = botH * compress;
  ctx.save();
  ctx.beginPath();
  ctx.rect(face.cx - face.radius * 1.2, faceCy, face.radius * 2.4, botH);
  ctx.clip();
  ctx.drawImage(tempCanvas,
    face.cx - face.radius * 1.2, faceCy, face.radius * 2.4, botH,
    face.cx - face.radius * 1.2, faceCy - botShift, face.radius * 2.4, botH
  );
  ctx.restore();
}

// ============================================================
//  カラーフィルター - TikTok Live風の色彩フィルター
// ============================================================
function applyColorFilter(w, h) {
  const filter = colorFilters[currentColorFilter];
  if (!filter || !filter.steps || filter.steps.length === 0) return;
  const intensityMul = colorFilterIntensity / 100;
  if (intensityMul <= 0) return;

  ctx.save();
  filter.steps.forEach(step => {
    ctx.globalCompositeOperation = step.op;
    if (step.alpha !== undefined) {
      ctx.globalAlpha = step.alpha * intensityMul;
    } else {
      // rgba色からアルファを抽出してintensityを適用
      ctx.globalAlpha = intensityMul;
    }
    ctx.fillStyle = step.color;
    ctx.fillRect(0, 0, w, h);
  });
  ctx.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 1.0;
  ctx.restore();
}

// ============================================================
//  色温度 - ウォーム/クール色調
// ============================================================
function applyTemperature(w, h) {
  const val = beautyParams.temp; // -50 to 50
  ctx.save();
  ctx.globalCompositeOperation = 'overlay';
  if (val > 0) {
    ctx.fillStyle = `rgba(255, 180, 80, ${(val / 50) * 0.08})`;
  } else {
    ctx.fillStyle = `rgba(100, 150, 255, ${(-val / 50) * 0.08})`;
  }
  ctx.fillRect(0, 0, w, h);
  ctx.globalCompositeOperation = 'source-over';
  ctx.restore();
}

// ============================================================
//  質感強調 - コントラスト＋ディテール
// ============================================================
function applyContrast(w, h) {
  const intensity = beautyParams.sharp / 100;
  ctx.save();
  ctx.globalCompositeOperation = 'overlay';
  ctx.globalAlpha = intensity * 0.18;
  ctx.drawImage(beautyCanvas, 0, 0, w, h);
  ctx.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 1.0;
  ctx.restore();
}

// ============================================================
//  ビネット (グラデーションキャッシュ 3.2)
// ============================================================
function applyVignette(w, h) {
  const intensity = beautyParams.vignette / 100;
  const cx = w / 2;
  const cy = h / 2;
  const r = Math.max(w, h) * 0.7;

  const cacheKey = `${w},${h},${Math.round(intensity * 10)}`;
  if (gradientCache.vignette.key !== cacheKey) {
    const grad = ctx.createRadialGradient(cx, cy, r * 0.3, cx, cy, r);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(1, `rgba(0,0,0,${intensity * 0.6})`);
    gradientCache.vignette = { key: cacheKey, grad };
  }

  ctx.save();
  ctx.fillStyle = gradientCache.vignette.grad;
  ctx.fillRect(0, 0, w, h);
  ctx.restore();
}

// ============================================================
//  メディア取得・プリロード
// ============================================================
async function fetchMedia() {
  try {
    const res = await fetch('/api/media');
    mediaConfig = await res.json();
    preloadAllMedia();
  } catch (err) {
    console.error('メディア取得エラー:', err);
  }
}

function preloadAllMedia() {
  mediaConfig.videos.forEach(v => {
    preloadedVideos[v.id] = v.url;
    const link = document.createElement('link');
    link.rel = 'prefetch';
    link.href = v.url;
    document.head.appendChild(link);
  });
  mediaConfig.audio.forEach(a => {
    if (!audioPlayers[a.id]) {
      const audio = new Audio();
      audio.preload = 'auto';
      audio.src = a.url;
      audio.load();
      audioPlayers[a.id] = audio;
    }
  });
}

// ============================================================
//  トランジション効果 (2.5)
// ============================================================
function showOverlayWithTransition(container, transition) {
  // 既存のトランジションクラスを除去
  container.className = container.className.replace(/transition-\S+/g, '').trim();
  container.classList.add('active');
  if (transition && transition !== 'none') {
    container.classList.add(`transition-${transition}`);
  }
}

function hideOverlayWithTransition(container, transition) {
  if (transition && transition !== 'none') {
    const outClass = transition.replace('In', 'Out');
    container.className = container.className.replace(/transition-\S+/g, '').trim();
    container.classList.add(`transition-${outClass}`);
    setTimeout(() => {
      container.classList.remove('active', `transition-${outClass}`);
    }, 350);
  } else {
    container.className = container.className.replace(/transition-\S+/g, '').trim();
    container.classList.remove('active');
  }
}

// ============================================================
//  現在の状態を報告 (1.4)
// ============================================================
function reportCurrentState() {
  const layers = overlayLayers.map((layer, i) => ({
    playing: layer.playing,
    videoId: layer.videoId,
    src: layer.video.src,
    paused: layer.video.paused
  }));

  const playingAudioIds = [];
  Object.keys(audioPlayers).forEach(id => {
    if (audioPlayers[id] && !audioPlayers[id].paused) {
      playingAudioIds.push(id);
    }
  });

  return {
    layers,
    playingAudioIds,
    beautyParams: { ...beautyParams },
    colorFilter: currentColorFilter,
    colorFilterIntensity
  };
}

// ============================================================
//  Socket.IO イベント
// ============================================================
socket.on('connect', () => {
  connectionStatus.className = 'conn-dot connected';
  connectionStatus.textContent = '●';
  reconnectBanner.classList.add('hidden');
  reconnectBanner.classList.remove('failed');
  if (currentRoomId) {
    socket.emit('join-room', { roomId: currentRoomId, role: 'display' });
  }
});

socket.on('disconnect', () => {
  connectionStatus.className = 'conn-dot disconnected';
  connectionStatus.textContent = '●';
});

// 再接続イベント (1.2)
socket.io.on('reconnect_attempt', (attempt) => {
  reconnectBanner.textContent = `再接続中... (${attempt}回目)`;
  reconnectBanner.classList.remove('hidden', 'failed');
});

socket.io.on('reconnect', () => {
  reconnectBanner.classList.add('hidden');
});

socket.io.on('reconnect_failed', () => {
  reconnectBanner.textContent = '再接続に失敗しました。ページを再読み込みしてください。';
  reconnectBanner.classList.add('failed');
  reconnectBanner.classList.remove('hidden');
});

socket.on('room-status', (data) => {
  console.log('ルーム状態:', data);
});

socket.on('media-updated', (config) => {
  mediaConfig = config;
  preloadAllMedia();
});

// 状態報告要求 (1.4)
socket.on('request-state', (data, ack) => {
  if (ack) ack(reportCurrentState());
});

// 動画再生 (ACK対応 1.3, レイヤー対応 2.2, ループ対応 2.4, トランジション対応 2.5)
socket.on('play-video', (data, ack) => {
  try {
    const video = mediaConfig.videos.find(v => v.id === data.id);
    if (!video) {
      if (ack) ack({ ok: false, error: 'video not found' });
      return;
    }

    const layerIdx = data.layer || 0;
    const layer = overlayLayers[layerIdx];
    if (!layer) {
      if (ack) ack({ ok: false, error: 'invalid layer' });
      return;
    }

    layer.video.src = video.url;
    layer.video.volume = (data.volume !== undefined) ? data.volume / 100 : 1;
    layer.video.currentTime = 0;
    layer.video.loop = !!data.loop;

    // 透明度 (2.3)
    if (data.opacity !== undefined) {
      layer.video.style.opacity = data.opacity / 100;
    }

    if (data.overlay) {
      layer.container.style.top = data.overlay.top || '15%';
      layer.container.style.left = data.overlay.left || '15%';
      layer.container.style.width = data.overlay.width || '70%';
      layer.container.style.height = data.overlay.height || '70%';
    }

    showOverlayWithTransition(layer.container, data.transition);
    layer.video.play().catch(err => console.error('動画再生エラー:', err));
    layer.playing = true;
    layer.videoId = data.id;

    layer.video.onended = () => {
      if (!layer.video.loop) {
        hideOverlayWithTransition(layer.container, data.transition);
        layer.playing = false;
        layer.videoId = null;
      }
    };

    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

socket.on('stop-video', (data, ack) => {
  try {
    const layerIdx = (data && data.layer) || 0;
    const transition = (data && data.transition) || 'none';
    const layer = overlayLayers[layerIdx];
    if (layer) {
      layer.video.pause();
      layer.video.currentTime = 0;
      hideOverlayWithTransition(layer.container, transition);
      layer.playing = false;
      layer.videoId = null;
    }
    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

socket.on('play-audio', (data, ack) => {
  try {
    const audioInfo = mediaConfig.audio.find(a => a.id === data.id);
    if (!audioInfo) {
      if (ack) ack({ ok: false, error: 'audio not found' });
      return;
    }
    let audio = audioPlayers[data.id];
    if (!audio) {
      audio = new Audio(audioInfo.url);
      audioPlayers[data.id] = audio;
    }
    audio.volume = (data.volume !== undefined) ? data.volume / 100 : 1;
    audio.loop = !!data.loop;
    audio.currentTime = 0;
    audio.play().catch(err => console.error('音楽再生エラー:', err));
    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

socket.on('stop-audio', (data, ack) => {
  try {
    if (data && data.id && audioPlayers[data.id]) {
      audioPlayers[data.id].pause();
      audioPlayers[data.id].currentTime = 0;
    }
    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

socket.on('stop-all', (data, ack) => {
  try {
    overlayLayers.forEach(layer => {
      layer.video.pause();
      layer.video.currentTime = 0;
      layer.container.classList.remove('active');
      layer.container.className = layer.container.className.replace(/transition-\S+/g, '').trim();
      layer.playing = false;
      layer.videoId = null;
    });
    Object.values(audioPlayers).forEach(audio => {
      audio.pause();
      audio.currentTime = 0;
    });
    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

socket.on('set-volume', (data, ack) => {
  try {
    const vol = (data.volume !== undefined) ? data.volume / 100 : 1;
    if (data.type === 'video') {
      const layerIdx = data.layer || 0;
      overlayLayers[layerIdx].video.volume = vol;
    } else if (data.type === 'audio' && data.id && audioPlayers[data.id]) {
      audioPlayers[data.id].volume = vol;
    } else if (data.type === 'master') {
      overlayLayers.forEach(layer => { layer.video.volume = vol; });
      Object.values(audioPlayers).forEach(a => { a.volume = vol; });
    }
    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

socket.on('set-overlay', (data, ack) => {
  try {
    const layerIdx = data.layer || 0;
    const container = overlayLayers[layerIdx].container;
    if (data.top !== undefined) container.style.top = data.top;
    if (data.left !== undefined) container.style.left = data.left;
    if (data.width !== undefined) container.style.width = data.width;
    if (data.height !== undefined) container.style.height = data.height;
    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

// テスト表示
socket.on('preview-video-position', (data, ack) => {
  try {
    const video = mediaConfig.videos.find(v => v.id === data.id);
    if (!video) {
      if (ack) ack({ ok: false, error: 'video not found' });
      return;
    }
    const layerIdx = data.layer || 0;
    const layer = overlayLayers[layerIdx];
    layer.video.src = video.url;
    layer.video.currentTime = 0.1;
    layer.video.pause();
    if (data.overlay) {
      layer.container.style.top = data.overlay.top || '15%';
      layer.container.style.left = data.overlay.left || '15%';
      layer.container.style.width = data.overlay.width || '70%';
      layer.container.style.height = data.overlay.height || '70%';
    }
    layer.container.classList.add('active');
    layer.video.addEventListener('loadeddata', () => {
      layer.video.currentTime = 0.1;
      layer.video.pause();
    }, { once: true });
    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

socket.on('hide-overlay-preview', (data, ack) => {
  try {
    const layerIdx = (data && data.layer) || 0;
    const layer = overlayLayers[layerIdx];
    layer.video.pause();
    layer.video.removeAttribute('src');
    layer.video.load();
    layer.container.classList.remove('active');
    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

// 美顔フィルター設定を受信
socket.on('set-beauty', (data, ack) => {
  try {
    Object.keys(data).forEach(key => {
      if (beautyParams[key] !== undefined && sliders[key]) {
        beautyParams[key] = data[key];
        sliders[key].value = data[key];
        valLabels[key].textContent = data[key] + '%';
      }
    });
    if (ack) ack({ ok: true });
  } catch (e) {
    if (ack) ack({ ok: false, error: e.message });
  }
});

// ============================================================
//  プレビュー画像をコントローラーに送信 (3.3最適化: toBlob, 160px, 500ms)
// ============================================================
setInterval(() => {
  if (!currentRoomId || !beautyCanvas.width) return;
  try {
    const preview = document.createElement('canvas');
    preview.width = 160;
    preview.height = Math.round(160 * beautyCanvas.height / beautyCanvas.width);
    const pCtx = preview.getContext('2d');
    pCtx.translate(preview.width, 0);
    pCtx.scale(-1, 1);
    pCtx.drawImage(beautyCanvas, 0, 0, preview.width, preview.height);

    // toBlob非同期変換 (3.3)
    preview.toBlob((blob) => {
      if (!blob) return;
      const reader = new FileReader();
      reader.onloadend = () => {
        socket.emit('preview-frame', reader.result);
      };
      reader.readAsDataURL(blob);
    }, 'image/jpeg', 0.4);
  } catch (e) { /* ignore */ }
}, 500);

// ============================================================
//  Wake Lock（画面スリープ防止）
// ============================================================
async function requestWakeLock() {
  try {
    if ('wakeLock' in navigator) {
      await navigator.wakeLock.request('screen');
    }
  } catch (err) { /* ignore */ }
}

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && currentRoomId) {
    requestWakeLock();
  }
});
