// ============================================================
//  TikTok Live Controller - Controller (Device B)
//  スタッフのスマホで操作するページ
//  動画・音楽の再生/停止ボタンパッド + メディア管理
// ============================================================

// Socket.IO（自動再接続設定 1.2）
const socket = io({
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 5000,
  reconnectionAttempts: 20
});

// DOM要素
const joinScreen = document.getElementById('join-screen');
const controllerScreen = document.getElementById('controller-screen');
// controllerScreen is also used for overlay-editing class toggle
const roomInput = document.getElementById('room-input');
const joinBtn = document.getElementById('join-btn');
const joinError = document.getElementById('join-error');
const roomLabel = document.getElementById('room-label');
const connectionStatus = document.getElementById('connection-status');
const stopAllBtn = document.getElementById('stop-all-btn');
const reconnectBanner = document.getElementById('reconnect-banner');
const toastContainer = document.getElementById('toast-container');

// タブ
const tabs = document.querySelectorAll('.tab');
const tabContents = document.querySelectorAll('.tab-content');

// 動画タブ
const videoGrid = document.getElementById('video-grid');
const videoEmpty = document.getElementById('video-empty');

// 音楽タブ
const audioGrid = document.getElementById('audio-grid');
const audioEmpty = document.getElementById('audio-empty');
const masterVolumeSlider = document.getElementById('master-volume');
const masterVolVal = document.getElementById('master-vol-val');

// 管理タブ
const uploadBtn = document.getElementById('upload-btn');
const fileInput = document.getElementById('file-input');
const uploadProgress = document.getElementById('upload-progress');
const progressFill = document.getElementById('progress-fill');
const uploadStatus = document.getElementById('upload-status');
const videoList = document.getElementById('video-list');
const audioList = document.getElementById('audio-list');

// モーダル
const renameModal = document.getElementById('rename-modal');
const renameInput = document.getElementById('rename-input');
const renameSave = document.getElementById('rename-save');
const renameCancel = document.getElementById('rename-cancel');

// 接続情報
const infoRoom = document.getElementById('info-room');
const infoDisplays = document.getElementById('info-displays');
const infoControllers = document.getElementById('info-controllers');

// プレビュー
const previewOverlay = document.getElementById('preview-overlay');
const previewArea = document.getElementById('preview-area');
const previewImg = document.getElementById('preview-img');

// 状態
let currentRoomId = null;
let mediaConfig = { videos: [], audio: [] };
let playingVideos = new Set();
let playingAudio = new Set();
let renameTargetId = null;
let masterVolume = 80;

// オーバーレイ設定（グローバル）
let overlayPosition = 'center';
let overlaySize = 70;
let videoEditMode = false; // 動画グリッドの編集モード

// レイヤー選択 (2.2)
let currentLayer = 0;

// ループモード (2.4)
let loopMode = false;

// トランジション (2.5)
let currentTransition = 'none';

// レイヤー透明度 (2.3)
let layerOpacity = 100;

// 動画ごとのオーバーレイ設定（localStorage保存）
let videoOverlaySettings = {};
function loadOverlaySettings() {
  try {
    videoOverlaySettings = JSON.parse(localStorage.getItem('videoOverlaySettings') || '{}');
  } catch (e) { videoOverlaySettings = {}; }
}
function saveOverlaySettings() {
  localStorage.setItem('videoOverlaySettings', JSON.stringify(videoOverlaySettings));
}
loadOverlaySettings();

// 動画アスペクト比とディスプレイ画面比率
let overlayVideoRatio = 0;
let previewScreenRatio = 9 / 16;

// サムネイルキャッシュ
const thumbnailCache = {};

// オーバーレイUndo履歴 (1.7)
let ovRectHistory = [];
const MAX_UNDO_HISTORY = 20;

function pushOvRectHistory() {
  ovRectHistory.push({ ...ovRect });
  if (ovRectHistory.length > MAX_UNDO_HISTORY) ovRectHistory.shift();
}

function undoOvRect() {
  if (ovRectHistory.length === 0) {
    showToast('Undo履歴がありません', 'info');
    return;
  }
  const prev = ovRectHistory.pop();
  ovRect.x = prev.x;
  ovRect.y = prev.y;
  ovRect.w = prev.w;
  ovRect.h = prev.h;
  drawOverlayRect();
  sendOverlayFromRect();
  showToast('Undo実行', 'info');
}

// オーバーレイプリセット (1.6)
let overlayPresets = [];
function loadOverlayPresets() {
  try {
    overlayPresets = JSON.parse(localStorage.getItem('overlayPresets') || '[]');
  } catch (e) { overlayPresets = []; }
}
function saveOverlayPresets() {
  localStorage.setItem('overlayPresets', JSON.stringify(overlayPresets));
}
loadOverlayPresets();

// タイマー/スケジューラ (2.6)
let scheduledTimers = [];
let timerIdCounter = 0;

// ============================================================
//  Toast通知システム (1.1)
// ============================================================
function showToast(msg, type = 'info', duration = 2500) {
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = msg;
  toastContainer.appendChild(toast);

  setTimeout(() => {
    toast.classList.add('removing');
    setTimeout(() => {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 250);
  }, duration);
}

// ============================================================
//  動画のアスペクト比を取得
// ============================================================
function loadVideoAspectRatio(url) {
  return new Promise((resolve) => {
    const vid = document.createElement('video');
    vid.preload = 'metadata';
    vid.muted = true;
    const timeout = setTimeout(() => resolve(16 / 9), 5000);
    vid.onloadedmetadata = () => {
      clearTimeout(timeout);
      const ratio = vid.videoWidth / vid.videoHeight;
      resolve(ratio || 16 / 9);
    };
    vid.onerror = () => {
      clearTimeout(timeout);
      resolve(16 / 9);
    };
    vid.src = url;
  });
}

// ============================================================
//  サムネイル生成 (3.5 IntersectionObserver遅延読込)
// ============================================================
let thumbObserver = null;

function initThumbObserver() {
  if (thumbObserver) return;
  thumbObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const el = entry.target;
        const videoId = el.dataset.thumbId;
        const url = el.dataset.thumbUrl;
        if (videoId && url && !thumbnailCache[videoId]) {
          generateThumbnail(videoId, url);
        }
        thumbObserver.unobserve(el);
      }
    });
  }, { rootMargin: '100px' });
}

function generateThumbnail(videoId, url) {
  if (thumbnailCache[videoId]) return;
  thumbnailCache[videoId] = 'pending';

  // サーバーサムネイルがあれば優先 (3.4)
  const videoItem = mediaConfig.videos.find(v => v.id === videoId);
  if (videoItem && videoItem.thumbUrl) {
    thumbnailCache[videoId] = videoItem.thumbUrl;
    const el = document.querySelector(`[data-thumb-id="${videoId}"]`);
    if (el) {
      el.style.backgroundImage = `url(${videoItem.thumbUrl})`;
      el.classList.add('has-thumb');
    }
    return;
  }

  const vid = document.createElement('video');
  vid.preload = 'auto';
  vid.muted = true;
  vid.playsInline = true;
  vid.src = url;

  vid.addEventListener('loadeddata', () => {
    vid.currentTime = Math.min(0.5, (vid.duration || 1) / 2);
  }, { once: true });

  vid.addEventListener('seeked', () => {
    try {
      const c = document.createElement('canvas');
      c.width = 240;
      c.height = Math.round(240 * vid.videoHeight / vid.videoWidth) || 135;
      const ctx = c.getContext('2d');
      ctx.drawImage(vid, 0, 0, c.width, c.height);
      thumbnailCache[videoId] = c.toDataURL('image/jpeg', 0.7);
      const el = document.querySelector(`[data-thumb-id="${videoId}"]`);
      if (el) {
        el.style.backgroundImage = `url(${thumbnailCache[videoId]})`;
        el.classList.add('has-thumb');
      }
    } catch (e) {
      console.warn('サムネイル生成失敗:', videoId, e);
      delete thumbnailCache[videoId];
    }
    vid.src = '';
    vid.load();
  }, { once: true });

  vid.addEventListener('error', () => {
    console.warn('サムネイル動画読込失敗:', videoId);
    delete thumbnailCache[videoId];
  }, { once: true });

  vid.load();
}

// ============================================================
//  入室
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

  socket.emit('join-room', { roomId, role: 'controller' });

  joinScreen.classList.remove('active');
  controllerScreen.classList.add('active');
  roomLabel.textContent = `Room: ${roomId}`;
  infoRoom.textContent = roomId;

  fetchMedia();
  initThumbObserver();

  // 状態同期を要求 (1.4)
  setTimeout(() => {
    socket.emit('request-state');
  }, 500);
}

// ============================================================
//  タブ切替
// ============================================================
tabs.forEach(tab => {
  tab.addEventListener('click', () => {
    tabs.forEach(t => t.classList.remove('active'));
    tabContents.forEach(tc => tc.classList.remove('active'));
    tab.classList.add('active');
    document.getElementById(`tab-${tab.dataset.tab}`).classList.add('active');
  });
});

// ============================================================
//  レイヤー選択 (2.2)
// ============================================================
document.querySelectorAll('.layer-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    currentLayer = parseInt(btn.dataset.layer);
    document.querySelectorAll('.layer-btn').forEach(b => b.classList.toggle('selected', parseInt(b.dataset.layer) === currentLayer));
  });
});

// ============================================================
//  ループモード (2.4)
// ============================================================
const loopToggleBtn = document.getElementById('loop-toggle-btn');
loopToggleBtn.addEventListener('click', () => {
  loopMode = !loopMode;
  loopToggleBtn.classList.toggle('active', loopMode);
  showToast(loopMode ? 'ループON' : 'ループOFF', 'info', 1500);
});

// ============================================================
//  トランジション選択 (2.5)
// ============================================================
const transitionSelect = document.getElementById('transition-select');
transitionSelect.addEventListener('change', () => {
  currentTransition = transitionSelect.value;
});

// ============================================================
//  透明度 (2.3)
// ============================================================
const opacitySlider = document.getElementById('layer-opacity');
const opacityVal = document.getElementById('opacity-val');
opacitySlider.addEventListener('input', () => {
  layerOpacity = parseInt(opacitySlider.value);
  opacityVal.textContent = layerOpacity + '%';
});

// ============================================================
//  メディア取得
// ============================================================
async function fetchMedia() {
  try {
    const res = await fetch('/api/media');
    mediaConfig = await res.json();
    renderAll();
    updateTimerVideoSelect();
  } catch (err) {
    console.error('メディア取得エラー:', err);
  }
}

function renderAll() {
  renderVideoGrid();
  renderAudioGrid();
  renderVideoList();
  renderAudioList();
  renderPresetChips();
}

// ============================================================
//  動画グリッド編集モード
// ============================================================
const editModeBtn = document.getElementById('edit-mode-btn');
editModeBtn.addEventListener('click', () => {
  videoEditMode = !videoEditMode;
  editModeBtn.classList.toggle('active', videoEditMode);
  editModeBtn.textContent = videoEditMode ? '✓ 配置設定モード' : '📐 配置設定';
  videoGrid.classList.toggle('edit-mode', videoEditMode);
});

// ============================================================
//  動画グリッド (3.5 IntersectionObserver対応)
// ============================================================
function renderVideoGrid() {
  videoGrid.innerHTML = '';
  if (mediaConfig.videos.length === 0) {
    videoEmpty.classList.remove('hidden');
    return;
  }
  videoEmpty.classList.add('hidden');

  mediaConfig.videos.forEach(v => {
    const isPlaying = playingVideos.has(v.id);
    const hasSaved = !!videoOverlaySettings[v.id];
    const thumb = thumbnailCache[v.id];
    const hasThumb = thumb && thumb !== 'pending';

    const card = document.createElement('div');
    card.className = `video-card${isPlaying ? ' playing' : ''}${hasThumb ? ' has-thumb' : ''}`;
    card.dataset.thumbId = v.id;
    card.dataset.thumbUrl = v.url;
    if (hasThumb) card.style.backgroundImage = `url(${thumb})`;

    card.innerHTML = `
      ${!hasThumb ? '<div class="video-card-placeholder">🎬</div>' : ''}
      <div class="video-card-overlay">
        ${isPlaying ? '<span class="video-playing-badge">再生中</span>' : ''}
        ${hasSaved ? '<span class="video-saved-dot"></span>' : ''}
        <span class="video-card-name">${escapeHtml(v.name)}</span>
      </div>
      <button class="media-settings-btn">📐</button>
    `;

    card.addEventListener('click', (e) => {
      if (e.target.closest('.media-settings-btn')) return;
      if (videoEditMode) {
        openOverlayModal(v.id, v.name);
      } else {
        toggleVideo(v.id);
      }
    });

    card.querySelector('.media-settings-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      openOverlayModal(v.id, v.name);
    });

    videoGrid.appendChild(card);

    // IntersectionObserver遅延サムネ (3.5)
    if (!hasThumb && thumbObserver) {
      thumbObserver.observe(card);
    }
  });
}

function toggleVideo(id) {
  if (playingVideos.has(id)) {
    socket.emit('stop-video', { layer: currentLayer, transition: currentTransition }, (resp) => {
      if (resp && resp.ok) {
        showToast('動画停止', 'info', 1500);
      } else {
        showToast('停止失敗: ' + (resp && resp.error || ''), 'error');
      }
    });
    playingVideos.clear();
  } else {
    playingVideos.clear();
    playingVideos.add(id);

    const saved = videoOverlaySettings[id];
    let overlay;
    if (saved && saved.custom) {
      overlay = {
        top: (saved.custom.y * 100) + '%',
        left: (saved.custom.x * 100) + '%',
        width: (saved.custom.w * 100) + '%',
        height: (saved.custom.h * 100) + '%'
      };
    } else if (saved) {
      overlay = calcOverlayFromSettings(saved.position, saved.size, saved.videoRatio);
    } else {
      const pos = getOverlayPosition();
      overlay = { ...pos, width: overlaySize + '%', height: overlaySize + '%' };
    }

    socket.emit('play-video', {
      id,
      volume: masterVolume,
      overlay,
      layer: currentLayer,
      loop: loopMode,
      transition: currentTransition,
      opacity: layerOpacity
    }, (resp) => {
      if (resp && resp.ok) {
        showToast('動画再生中', 'success', 1500);
      } else {
        showToast('再生失敗: ' + (resp && resp.error || ''), 'error');
      }
    });
  }
  renderVideoGrid();
}

// ============================================================
//  音楽グリッド
// ============================================================
function renderAudioGrid() {
  audioGrid.innerHTML = '';
  if (mediaConfig.audio.length === 0) {
    audioEmpty.classList.remove('hidden');
    return;
  }
  audioEmpty.classList.add('hidden');

  mediaConfig.audio.forEach(a => {
    const isPlaying = playingAudio.has(a.id);
    const row = document.createElement('button');
    row.className = `audio-row${isPlaying ? ' playing' : ''}`;
    row.innerHTML = `
      <span class="audio-row-icon">${isPlaying ? '⏹' : '▶'}</span>
      <span class="audio-row-name">${escapeHtml(a.name)}</span>
      ${isPlaying ? '<span class="audio-row-status">再生中</span>' : ''}
    `;
    row.addEventListener('click', () => toggleAudio(a.id));
    audioGrid.appendChild(row);
  });
}

function toggleAudio(id) {
  if (playingAudio.has(id)) {
    socket.emit('stop-audio', { id }, (resp) => {
      if (resp && resp.ok) {
        showToast('音楽停止', 'info', 1500);
      } else {
        showToast('停止失敗', 'error');
      }
    });
    playingAudio.delete(id);
  } else {
    playingAudio.add(id);
    socket.emit('play-audio', { id, volume: masterVolume, loop: loopMode }, (resp) => {
      if (resp && resp.ok) {
        showToast('音楽再生中', 'success', 1500);
      } else {
        showToast('再生失敗', 'error');
      }
    });
  }
  renderAudioGrid();
}

// ============================================================
//  オーバーレイ位置計算（アスペクト比対応 + PiPコーナー 2.1）
// ============================================================
function getOverlayPosition() {
  const s = overlaySize;
  const margin = (100 - s) / 2;
  switch (overlayPosition) {
    case 'top':    return { top: '2%', left: margin + '%' };
    case 'bottom': return { top: (100 - s - 2) + '%', left: margin + '%' };
    case 'full':   return { top: '0', left: '0', width: '100%', height: '100%' };
    case 'center':
    default:       return { top: margin + '%', left: margin + '%' };
  }
}

// アスペクト比を考慮したオーバーレイ計算 (2.1 PiPコーナー対応)
function calcOverlayFromSettings(position, size, videoRatio) {
  if (position === 'full') {
    return { top: '0', left: '0', width: '100%', height: '100%' };
  }
  const w = size; // 幅（画面幅の%）
  let h;
  if (videoRatio && previewScreenRatio) {
    h = Math.min(100, w * previewScreenRatio / videoRatio);
  } else {
    h = w;
  }

  let left, top;
  const pad = 2; // 端からのパディング%

  switch (position) {
    case 'top-left':
      left = pad; top = pad; break;
    case 'top-right':
      left = 100 - w - pad; top = pad; break;
    case 'bottom-left':
      left = pad; top = 100 - h - pad; break;
    case 'bottom-right':
      left = 100 - w - pad; top = 100 - h - pad; break;
    case 'center':
    default:
      left = (100 - w) / 2; top = (100 - h) / 2; break;
  }

  return { top: top + '%', left: left + '%', width: w + '%', height: h + '%' };
}

// ovRectをオーバーレイ設定から計算
function setOvRectFromSettings(position, size, videoRatio) {
  const ov = calcOverlayFromSettings(position, size, videoRatio);
  ovRect.x = parseFloat(ov.left) / 100;
  ovRect.y = parseFloat(ov.top) / 100;
  ovRect.w = parseFloat(ov.width) / 100;
  ovRect.h = parseFloat(ov.height) / 100;
}


// ============================================================
//  マスター音量
// ============================================================
masterVolumeSlider.addEventListener('input', () => {
  masterVolume = parseInt(masterVolumeSlider.value);
  masterVolVal.textContent = masterVolume + '%';
  socket.emit('set-volume', { type: 'master', volume: masterVolume }, (resp) => {
    // silent ACK
  });
});

// ============================================================
//  全停止
// ============================================================
stopAllBtn.addEventListener('click', () => {
  socket.emit('stop-all', {}, (resp) => {
    if (resp && resp.ok) {
      showToast('全停止', 'info', 1500);
    } else {
      showToast('全停止失敗', 'error');
    }
  });
  playingVideos.clear();
  playingAudio.clear();
  renderVideoGrid();
  renderAudioGrid();
});

// ============================================================
//  ファイルアップロード
// ============================================================
uploadBtn.addEventListener('click', () => fileInput.click());

fileInput.addEventListener('change', async () => {
  const file = fileInput.files[0];
  if (!file) return;

  const formData = new FormData();
  formData.append('file', file);
  formData.append('name', file.name);

  uploadProgress.classList.remove('hidden');
  progressFill.style.width = '0';
  uploadStatus.textContent = 'アップロード中...';

  try {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', '/api/upload');

    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) {
        const pct = Math.round((e.loaded / e.total) * 100);
        progressFill.style.width = pct + '%';
        uploadStatus.textContent = `アップロード中... ${pct}%`;
      }
    };

    xhr.onload = () => {
      if (xhr.status === 200) {
        uploadStatus.textContent = 'アップロード完了！';
        showToast('アップロード完了', 'success');
        setTimeout(() => uploadProgress.classList.add('hidden'), 2000);
        fetchMedia();
      } else {
        uploadStatus.textContent = 'エラーが発生しました';
        showToast('アップロードエラー', 'error');
      }
      fileInput.value = '';
    };

    xhr.onerror = () => {
      uploadStatus.textContent = 'ネットワークエラー';
      showToast('ネットワークエラー', 'error');
      fileInput.value = '';
    };

    xhr.send(formData);
  } catch (err) {
    uploadStatus.textContent = 'エラー: ' + err.message;
    fileInput.value = '';
  }
});

// ============================================================
//  管理タブ - メディア一覧
// ============================================================
function renderVideoList() {
  videoList.innerHTML = '';
  if (mediaConfig.videos.length === 0) {
    videoList.innerHTML = '<p style="color:#666;font-size:0.8rem;padding:8px">動画なし</p>';
    return;
  }
  mediaConfig.videos.forEach(v => {
    videoList.appendChild(createMediaItem(v, '🎬'));
  });
}

function renderAudioList() {
  audioList.innerHTML = '';
  if (mediaConfig.audio.length === 0) {
    audioList.innerHTML = '<p style="color:#666;font-size:0.8rem;padding:8px">音楽なし</p>';
    return;
  }
  mediaConfig.audio.forEach(a => {
    audioList.appendChild(createMediaItem(a, '🎵'));
  });
}

function createMediaItem(item, icon) {
  const div = document.createElement('div');
  div.className = 'media-item';
  div.innerHTML = `
    <span class="media-item-icon">${icon}</span>
    <div class="media-item-info">
      <div class="media-item-name">${escapeHtml(item.name)}</div>
      <div class="media-item-size">${formatSize(item.size)}</div>
    </div>
    <div class="media-item-actions">
      <button class="btn-icon-sm rename-btn" data-id="${item.id}" data-name="${escapeHtml(item.name)}">✏️</button>
      <button class="btn-icon-sm delete btn-delete" data-id="${item.id}">🗑</button>
    </div>
  `;

  div.querySelector('.rename-btn').addEventListener('click', (e) => {
    renameTargetId = e.currentTarget.dataset.id;
    renameInput.value = e.currentTarget.dataset.name;
    renameModal.classList.remove('hidden');
    renameInput.focus();
  });

  div.querySelector('.btn-delete').addEventListener('click', async (e) => {
    if (!confirm('削除しますか？')) return;
    try {
      await fetch(`/api/media/${e.currentTarget.dataset.id}`, { method: 'DELETE' });
      showToast('削除しました', 'info');
      fetchMedia();
    } catch (err) {
      showToast('削除エラー', 'error');
    }
  });

  return div;
}

// ============================================================
//  名称変更モーダル
// ============================================================
renameSave.addEventListener('click', async () => {
  const newName = renameInput.value.trim();
  if (!newName || !renameTargetId) return;

  try {
    await fetch(`/api/media/${renameTargetId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: newName })
    });
    renameModal.classList.add('hidden');
    renameTargetId = null;
    showToast('名称変更しました', 'success');
    fetchMedia();
  } catch (err) {
    showToast('名称変更エラー', 'error');
  }
});

renameCancel.addEventListener('click', () => {
  renameModal.classList.add('hidden');
  renameTargetId = null;
});

renameModal.addEventListener('click', (e) => {
  if (e.target === renameModal) {
    renameModal.classList.add('hidden');
    renameTargetId = null;
  }
});

// ============================================================
//  オーバーレイプリセット (1.6)
// ============================================================
function renderPresetChips() {
  const container = document.getElementById('preset-chips');
  container.innerHTML = '';
  overlayPresets.forEach((preset, i) => {
    const chip = document.createElement('div');
    chip.className = 'preset-chip';
    chip.innerHTML = `<span>${escapeHtml(preset.name)}</span><span class="preset-delete" data-idx="${i}">×</span>`;
    chip.addEventListener('click', (e) => {
      if (e.target.classList.contains('preset-delete')) {
        overlayPresets.splice(parseInt(e.target.dataset.idx), 1);
        saveOverlayPresets();
        renderPresetChips();
        showToast('プリセット削除', 'info', 1500);
        return;
      }
      // プリセット適用
      videoOverlaySettings = JSON.parse(JSON.stringify(preset.settings));
      saveOverlaySettings();
      renderVideoGrid();
      showToast(`プリセット "${preset.name}" 適用`, 'success', 1500);
    });
    container.appendChild(chip);
  });
}

document.getElementById('preset-save-btn').addEventListener('click', () => {
  const name = prompt('プリセット名を入力:');
  if (!name) return;
  overlayPresets.push({
    name,
    settings: JSON.parse(JSON.stringify(videoOverlaySettings))
  });
  saveOverlayPresets();
  renderPresetChips();
  showToast(`プリセット "${name}" 保存`, 'success');
});

// ============================================================
//  Socket.IO イベント
// ============================================================
socket.on('connect', () => {
  connectionStatus.className = 'status-dot connected';
  connectionStatus.textContent = '● 接続中';
  reconnectBanner.classList.add('hidden');
  reconnectBanner.classList.remove('failed');
  if (currentRoomId) {
    socket.emit('join-room', { roomId: currentRoomId, role: 'controller' });
    // 再接続時に状態同期 (1.4)
    setTimeout(() => socket.emit('request-state'), 500);
  }
});

socket.on('disconnect', () => {
  connectionStatus.className = 'status-dot disconnected';
  connectionStatus.textContent = '● 切断';
});

// 再接続イベント (1.2)
socket.io.on('reconnect_attempt', (attempt) => {
  reconnectBanner.textContent = `再接続中... (${attempt}回目)`;
  reconnectBanner.classList.remove('hidden', 'failed');
});

socket.io.on('reconnect', () => {
  reconnectBanner.classList.add('hidden');
  showToast('再接続しました', 'success');
});

socket.io.on('reconnect_failed', () => {
  reconnectBanner.textContent = '再接続に失敗しました。ページを再読み込みしてください。';
  reconnectBanner.classList.add('failed');
  reconnectBanner.classList.remove('hidden');
});

socket.on('room-status', (data) => {
  infoDisplays.textContent = data.displays + '台';
  infoControllers.textContent = data.controllers + '台';
});

// 状態同期受信 (1.4)
socket.on('sync-state', (state) => {
  if (!state) return;

  // レイヤー状態を復元
  if (state.layers) {
    playingVideos.clear();
    state.layers.forEach((layer, i) => {
      if (layer.playing && layer.videoId) {
        playingVideos.add(layer.videoId);
      }
    });
    renderVideoGrid();
  }

  // 再生中音声を復元
  if (state.playingAudioIds) {
    playingAudio.clear();
    state.playingAudioIds.forEach(id => playingAudio.add(id));
    renderAudioGrid();
  }

  showToast('状態同期完了', 'info', 1500);
});

// プレビュー受信（画面比率も取得）
socket.on('preview-frame', (dataUrl) => {
  previewImg.src = dataUrl;
  previewImg.classList.add('active');
  // プレビュー画像からディスプレイ画面の縦横比を取得
  previewImg.onload = () => {
    if (previewImg.naturalWidth && previewImg.naturalHeight) {
      previewScreenRatio = previewImg.naturalWidth / previewImg.naturalHeight;
    }
  };
  if (overlayEditMode) {
    drawOverlayRect();
  }
});

socket.on('media-updated', (config) => {
  mediaConfig = config;
  renderAll();
  updateTimerVideoSelect();
});

// ============================================================
//  オーバーレイ設定モーダル（プレビュー＆テスト表示連動）
// ============================================================
let overlayTargetId = null;
let overlayModalPos = 'center';
let overlayModalSize = 70;
let overlayEditMode = false;

const overlayModal = document.getElementById('overlay-modal');
const overlayTargetName = document.getElementById('overlay-target-name');
const overlaySizeInput = document.getElementById('overlay-size-input');
const overlaySizePreview = document.getElementById('overlay-size-preview');

// ディスプレイにテスト表示を送信
function sendTestPreview() {
  if (!overlayTargetId) return;
  const overlay = {
    top: (ovRect.y * 100) + '%',
    left: (ovRect.x * 100) + '%',
    width: (ovRect.w * 100) + '%',
    height: (ovRect.h * 100) + '%'
  };
  socket.emit('preview-video-position', {
    id: overlayTargetId,
    overlay,
    layer: currentLayer
  });
}

// ディスプレイのテスト表示を非表示
function hideTestPreview() {
  socket.emit('hide-overlay-preview', { layer: currentLayer });
}

async function openOverlayModal(id, name) {
  overlayTargetId = id;
  overlayTargetName.textContent = name;
  overlayEditMode = true;

  // Undo履歴にpush (1.7)
  pushOvRectHistory();

  // 動画のアスペクト比を取得
  const video = mediaConfig.videos.find(v => v.id === id);
  if (video) {
    overlayVideoRatio = await loadVideoAspectRatio(video.url);
  } else {
    overlayVideoRatio = 16 / 9;
  }

  const saved = videoOverlaySettings[id] || { position: 'center', size: 70 };
  overlayModalPos = saved.position;
  overlayModalSize = saved.size;

  overlaySizeInput.value = overlayModalSize;
  overlaySizePreview.textContent = overlayModalSize + '%';

  document.querySelectorAll('.opos-btn').forEach(b => {
    b.classList.toggle('selected', b.dataset.pos === overlayModalPos);
  });

  // カスタム位置があればそれを使う、なければ設定から計算
  if (saved.custom) {
    ovRect.x = saved.custom.x;
    ovRect.y = saved.custom.y;
    ovRect.w = saved.custom.w;
    ovRect.h = saved.custom.h;
  } else {
    setOvRectFromSettings(overlayModalPos, overlayModalSize, overlayVideoRatio);
  }

  // プレビューエリアを編集モードに
  previewArea.classList.add('edit-mode');
  controllerScreen.classList.add('overlay-editing');
  drawOverlayRect();

  // ディスプレイ側にテスト表示
  sendTestPreview();

  // ボトムシートとして表示
  overlayModal.classList.add('bottom-sheet');
  overlayModal.classList.remove('hidden');
}

function closeOverlayModal() {
  overlayModal.classList.add('hidden');
  overlayModal.classList.remove('bottom-sheet');
  overlayEditMode = false;
  previewArea.classList.remove('edit-mode');
  controllerScreen.classList.remove('overlay-editing');
  overlayVideoRatio = 0;
  // 枠をクリア
  const canvas = previewOverlay;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  // ディスプレイのテスト表示を非表示
  hideTestPreview();
}

// ovRectから最も近いポジション名を逆算
function guessPositionFromRect() {
  const cx = ovRect.x + ovRect.w / 2;
  const cy = ovRect.y + ovRect.h / 2;

  if (ovRect.w >= 0.98 && ovRect.h >= 0.98) return 'full';

  let col, row;
  if (cx < 0.33) col = 'left';
  else if (cx > 0.67) col = 'right';
  else col = 'center';

  if (cy < 0.33) row = 'top';
  else if (cy > 0.67) row = 'bottom';
  else row = 'center';

  if (row === 'center' && col === 'center') return 'center';
  if (row === 'top' && col === 'left') return 'top-left';
  if (row === 'top' && col === 'right') return 'top-right';
  if (row === 'bottom' && col === 'left') return 'bottom-left';
  if (row === 'bottom' && col === 'right') return 'bottom-right';
  if (row === 'center') return col;
  if (col === 'center') return row;
  return row + '-' + col;
}

// モーダルのポジションボタン更新（UIのみ）
function updateModalPosUI(pos) {
  overlayModalPos = pos;
  document.querySelectorAll('.opos-btn').forEach(b => {
    b.classList.toggle('selected', b.dataset.pos === pos);
  });
}

// ポジションボタン
document.querySelectorAll('.opos-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    pushOvRectHistory();
    overlayModalPos = btn.dataset.pos;
    document.querySelectorAll('.opos-btn').forEach(b => b.classList.remove('selected'));
    btn.classList.add('selected');
    // プレビュー枠を更新（アスペクト比対応）
    setOvRectFromSettings(overlayModalPos, overlayModalSize, overlayVideoRatio);
    drawOverlayRect();
    // ディスプレイにテスト表示を更新
    sendTestPreview();
  });
});

// サイズスライダー（現在の中心位置を維持してリサイズ）
overlaySizeInput.addEventListener('input', () => {
  pushOvRectHistory();
  overlayModalSize = parseInt(overlaySizeInput.value);
  overlaySizePreview.textContent = overlayModalSize + '%';

  // 現在の中心を記憶
  const cx = ovRect.x + ovRect.w / 2;
  const cy = ovRect.y + ovRect.h / 2;

  // 新しいサイズ計算（アスペクト比維持）
  const newW = overlayModalSize / 100;
  let newH;
  if (overlayVideoRatio && previewScreenRatio) {
    newH = Math.min(1, newW * previewScreenRatio / overlayVideoRatio);
  } else {
    newH = newW;
  }

  // 中心を維持して配置（はみ出し防止）
  ovRect.w = newW;
  ovRect.h = newH;
  ovRect.x = Math.max(0, Math.min(1 - newW, cx - newW / 2));
  ovRect.y = Math.max(0, Math.min(1 - newH, cy - newH / 2));

  drawOverlayRect();
  sendTestPreview();
});

// 保存ボタン
document.getElementById('overlay-save').addEventListener('click', () => {
  if (overlayTargetId) {
    videoOverlaySettings[overlayTargetId] = {
      position: overlayModalPos,
      size: overlayModalSize,
      videoRatio: overlayVideoRatio,
      custom: {
        x: ovRect.x,
        y: ovRect.y,
        w: ovRect.w,
        h: ovRect.h
      }
    };
    saveOverlaySettings();
    showToast('配置設定を保存しました', 'success');
  }
  closeOverlayModal();
  // 保存後は編集モードを解除
  videoEditMode = false;
  editModeBtn.classList.remove('active');
  editModeBtn.textContent = '📐 配置設定';
  videoGrid.classList.remove('edit-mode');
  renderVideoGrid();
});

// キャンセルボタン
document.getElementById('overlay-cancel').addEventListener('click', () => {
  closeOverlayModal();
});

// ボトムシートモードでは背景クリックなし（pointer-events: none）
// モーダルモード時のみ背景クリックで閉じる
overlayModal.addEventListener('click', (e) => {
  if (e.target === overlayModal && !overlayModal.classList.contains('bottom-sheet')) {
    closeOverlayModal();
  }
});

// ============================================================
//  プレビュー画像の表示領域を取得
// ============================================================
function getPreviewImgBounds() {
  const areaRect = previewArea.getBoundingClientRect();

  if (!previewImg.naturalWidth || !previewImg.naturalHeight ||
      !previewImg.classList.contains('active')) {
    return { x: 0, y: 0, w: areaRect.width, h: areaRect.height };
  }

  const imgRatio = previewImg.naturalWidth / previewImg.naturalHeight;
  const imgH = areaRect.height;
  const imgW = imgH * imgRatio;
  const imgX = (areaRect.width - imgW) / 2;
  const imgY = 0;

  return { x: imgX, y: imgY, w: imgW, h: imgH };
}

// ============================================================
//  プレビュー タッチ操作（ドラッグ＆ピンチ）
// ============================================================

// オーバーレイ枠の現在位置（0〜1の比率：ディスプレイ画面の%に対応）
let ovRect = { x: 0.15, y: 0.15, w: 0.7, h: 0.7 };
let touchState = null;

function drawOverlayRect() {
  const canvas = previewOverlay;
  const areaRect = previewArea.getBoundingClientRect();
  canvas.width = areaRect.width;
  canvas.height = areaRect.height;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  if (!overlayEditMode) return;

  const imgB = getPreviewImgBounds();

  // 画像表示領域内でのオーバーレイ位置
  const x = imgB.x + ovRect.x * imgB.w;
  const y = imgB.y + ovRect.y * imgB.h;
  const w = ovRect.w * imgB.w;
  const h = ovRect.h * imgB.h;

  // 画像エリアの外を暗く
  ctx.fillStyle = 'rgba(0,0,0,0.5)';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  // 画像エリア内は少し明るく
  ctx.fillStyle = 'rgba(0,0,0,0.2)';
  ctx.clearRect(imgB.x, imgB.y, imgB.w, imgB.h);
  ctx.fillRect(imgB.x, imgB.y, imgB.w, imgB.h);
  // オーバーレイ枠の中をクリア
  ctx.clearRect(x, y, w, h);

  // 枠線
  ctx.strokeStyle = '#fe2c55';
  ctx.lineWidth = 2;
  ctx.strokeRect(x, y, w, h);

  // 角マーク
  const corner = Math.min(12, w / 4, h / 4);
  ctx.lineWidth = 3;
  ctx.strokeStyle = '#fff';
  // 左上
  ctx.beginPath(); ctx.moveTo(x, y + corner); ctx.lineTo(x, y); ctx.lineTo(x + corner, y); ctx.stroke();
  // 右上
  ctx.beginPath(); ctx.moveTo(x + w - corner, y); ctx.lineTo(x + w, y); ctx.lineTo(x + w, y + corner); ctx.stroke();
  // 左下
  ctx.beginPath(); ctx.moveTo(x, y + h - corner); ctx.lineTo(x, y + h); ctx.lineTo(x + corner, y + h); ctx.stroke();
  // 右下
  ctx.beginPath(); ctx.moveTo(x + w - corner, y + h); ctx.lineTo(x + w, y + h); ctx.lineTo(x + w, y + h - corner); ctx.stroke();

  // サイズ表示
  ctx.fillStyle = 'rgba(254,44,85,0.85)';
  const labelW = 60;
  const labelH = 18;
  ctx.fillRect(x + w / 2 - labelW / 2, y + h / 2 - labelH / 2, labelW, labelH);
  ctx.fillStyle = '#fff';
  ctx.font = '11px sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(Math.round(ovRect.w * 100) + '%', x + w / 2, y + h / 2);
}

function sendOverlayFromRect() {
  const data = {
    top: (ovRect.y * 100) + '%',
    left: (ovRect.x * 100) + '%',
    width: (ovRect.w * 100) + '%',
    height: (ovRect.h * 100) + '%',
    layer: currentLayer
  };
  socket.emit('set-overlay', data);
  // 編集モード中はテスト表示も更新
  if (overlayEditMode) {
    sendTestPreview();
  }
}

// タッチイベント
previewOverlay.addEventListener('touchstart', (e) => {
  if (!overlayEditMode) return;
  e.preventDefault();
  if (e.touches.length === 1) {
    pushOvRectHistory();
    touchState = {
      type: 'drag',
      startX: e.touches[0].clientX,
      startY: e.touches[0].clientY,
      origX: ovRect.x,
      origY: ovRect.y
    };
  } else if (e.touches.length === 2) {
    pushOvRectHistory();
    const dist = Math.hypot(
      e.touches[0].clientX - e.touches[1].clientX,
      e.touches[0].clientY - e.touches[1].clientY
    );
    touchState = {
      type: 'pinch',
      startDist: dist,
      origW: ovRect.w,
      origH: ovRect.h,
      aspect: ovRect.h / ovRect.w // アスペクト比を維持
    };
  }
});

previewOverlay.addEventListener('touchmove', (e) => {
  if (!overlayEditMode || !touchState) return;
  e.preventDefault();
  const imgB = getPreviewImgBounds();

  if (touchState.type === 'drag' && e.touches.length === 1) {
    const dx = (e.touches[0].clientX - touchState.startX) / imgB.w;
    const dy = (e.touches[0].clientY - touchState.startY) / imgB.h;
    ovRect.x = Math.max(0, Math.min(1 - ovRect.w, touchState.origX + dx));
    ovRect.y = Math.max(0, Math.min(1 - ovRect.h, touchState.origY + dy));
    drawOverlayRect();
    sendOverlayFromRect();
  }

  if (touchState.type === 'pinch' && e.touches.length === 2) {
    const dist = Math.hypot(
      e.touches[0].clientX - e.touches[1].clientX,
      e.touches[0].clientY - e.touches[1].clientY
    );
    const scale = dist / touchState.startDist;
    const newW = Math.max(0.1, Math.min(1, touchState.origW * scale));
    // アスペクト比を維持してリサイズ
    const newH = Math.max(0.05, Math.min(1, newW * touchState.aspect));
    // 中心を維持
    const cx = ovRect.x + ovRect.w / 2;
    const cy = ovRect.y + ovRect.h / 2;
    ovRect.w = newW;
    ovRect.h = newH;
    ovRect.x = Math.max(0, Math.min(1 - newW, cx - newW / 2));
    ovRect.y = Math.max(0, Math.min(1 - newH, cy - newH / 2));
    drawOverlayRect();
    sendOverlayFromRect();
  }
});

previewOverlay.addEventListener('touchend', () => {
  touchState = null;
  // モーダル表示中 → タッチ操作の結果をモーダルUIに反映
  if (overlayEditMode) {
    const pos = guessPositionFromRect();
    updateModalPosUI(pos);
    overlayModalSize = Math.round(ovRect.w * 100);
    overlaySizeInput.value = overlayModalSize;
    overlaySizePreview.textContent = overlayModalSize + '%';
  }
});

// ============================================================
//  キーボードショートカット (1.5)
// ============================================================
document.addEventListener('keydown', (e) => {
  // 入力フィールドにフォーカス中は無視
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') return;
  if (!currentRoomId) return;

  // Space = 全停止
  if (e.code === 'Space') {
    e.preventDefault();
    stopAllBtn.click();
    return;
  }

  // M = ミュート
  if (e.key === 'm' || e.key === 'M') {
    e.preventDefault();
    masterVolume = masterVolume > 0 ? 0 : 80;
    masterVolumeSlider.value = masterVolume;
    masterVolVal.textContent = masterVolume + '%';
    socket.emit('set-volume', { type: 'master', volume: masterVolume });
    showToast(masterVolume === 0 ? 'ミュート' : 'ミュート解除', 'info', 1500);
    return;
  }

  // Ctrl+Z = Undo
  if ((e.ctrlKey || e.metaKey) && e.key === 'z') {
    e.preventDefault();
    undoOvRect();
    return;
  }

  // 1-9 = 動画再生
  if (e.key >= '1' && e.key <= '9') {
    const idx = parseInt(e.key) - 1;
    if (mediaConfig.videos[idx]) {
      toggleVideo(mediaConfig.videos[idx].id);
    }
    return;
  }
});

// ============================================================
//  タイマー/スケジューラ (2.6)
// ============================================================
function updateTimerVideoSelect() {
  const select = document.getElementById('timer-video-select');
  select.innerHTML = '<option value="">動画を選択...</option>';
  mediaConfig.videos.forEach(v => {
    const opt = document.createElement('option');
    opt.value = v.id;
    opt.textContent = v.name;
    select.appendChild(opt);
  });
}

function renderTimerList() {
  const list = document.getElementById('timer-list');
  list.innerHTML = '';
  scheduledTimers.forEach(t => {
    const item = document.createElement('div');
    item.className = 'timer-item';
    const video = mediaConfig.videos.find(v => v.id === t.videoId);
    const name = video ? video.name : '不明';
    item.innerHTML = `
      <span>${escapeHtml(name)} - ${t.delay}秒後${t.repeat ? ' (繰返し)' : ''}</span>
      <button class="timer-item-cancel" data-timer-id="${t.id}">取消</button>
    `;
    item.querySelector('.timer-item-cancel').addEventListener('click', () => {
      cancelTimer(t.id);
    });
    list.appendChild(item);
  });
}

document.getElementById('timer-add-btn').addEventListener('click', () => {
  const videoId = document.getElementById('timer-video-select').value;
  const delay = parseInt(document.getElementById('timer-delay').value) || 5;
  const repeat = document.getElementById('timer-repeat').checked;

  if (!videoId) {
    showToast('動画を選択してください', 'error');
    return;
  }

  scheduleVideoPlay(videoId, delay, repeat);
  showToast(`タイマー追加: ${delay}秒後`, 'success');
});

function scheduleVideoPlay(videoId, delaySec, repeat) {
  const id = ++timerIdCounter;

  function execute() {
    toggleVideo(videoId);
    if (repeat) {
      const timerId = setTimeout(execute, delaySec * 1000);
      const timer = scheduledTimers.find(t => t.id === id);
      if (timer) timer.timerId = timerId;
    } else {
      scheduledTimers = scheduledTimers.filter(t => t.id !== id);
      renderTimerList();
    }
  }

  const timerId = setTimeout(execute, delaySec * 1000);
  scheduledTimers.push({ id, videoId, delay: delaySec, repeat, timerId });
  renderTimerList();
}

function cancelTimer(id) {
  const timer = scheduledTimers.find(t => t.id === id);
  if (timer) {
    clearTimeout(timer.timerId);
    scheduledTimers = scheduledTimers.filter(t => t.id !== id);
    renderTimerList();
    showToast('タイマー取消', 'info', 1500);
  }
}

// ============================================================
//  ユーティリティ
// ============================================================
function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function formatSize(bytes) {
  if (!bytes) return '';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}
