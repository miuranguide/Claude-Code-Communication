// ============================================================
//  TikTok Comment Dashboard - 5画面+個別コメント欄
// ============================================================

const socket = io();

// ============ 状態 ============
let comments = [];
let templates = [];
let slotData = Array.from({ length: 5 }, () => ({
  connected: false, username: '', viewers: 0, commentCount: 0,
}));
let currentCategory = 'all';
let uniqueUsers = new Set();
let sendMode = 'auto'; // 'auto' or 'manual'
const pendingSend = Array.from({ length: 5 }, () => null);

// ============ DOM ============
const $ = id => document.getElementById(id);
const suggestionsList = $('suggestions-list');
const templateList = $('template-list');

// ============ Socket.IO ============

socket.on('connect', () => console.log('[WS] 接続完了'));

socket.on('init-data', (data) => {
  comments = data.comments || [];
  templates = data.templates || [];
  uniqueUsers = new Set(comments.map(c => c.userId));

  if (data.slots) {
    data.slots.forEach(s => updateSlotUI(s));
  }

  // 各スロットにコメントを振り分けて描画
  comments.forEach(c => {
    if (c.slotId !== undefined) {
      slotData[c.slotId].commentCount++;
      appendCommentToSlot(c, c.suggestions, false);
    }
  });

  renderTemplates();
  updateStats();
  updateAllCommentCounts();
});

socket.on('slot-status', (data) => {
  updateSlotUI(data);
  if (data.error) showToast(`スロット${data.id + 1}: ${data.error}`, true);
});

socket.on('slot-error', (data) => {
  showToast(`スロット${data.slotId + 1}: ${data.error}`, true);
});

socket.on('device-status', ({ slotId, connected, serial }) => {
  const col = document.querySelector(`.slot-column[data-slot="${slotId}"]`);
  if (!col) return;
  const dot = col.querySelector('.slot-status-dot');
  if (dot) dot.title = connected ? `📱 ${serial}` : '';
  showToast(
    connected
      ? `📱 スロット${slotId + 1}にスマホ接続`
      : `⚠️ スロット${slotId + 1}のスマホ切断`,
    !connected
  );
});

socket.on('system-toast', ({ message }) => showToast(message));

socket.on('comment-ready', ({ text, slotId }) => {
  pendingSend[slotId] = text;
  showSendButton(slotId, text);
});

socket.on('comment-posted', ({ slotId }) => {
  hideSendButton(slotId);
  if (slotId !== undefined) {
    pendingSend[slotId] = null;
    showToast(`✅ スロット${slotId + 1} 送信完了`);
  }
});

socket.on('new-comment', ({ comment, suggestions }) => {
  comments.push({ ...comment, suggestions });
  uniqueUsers.add(comment.userId);
  if (comments.length > 500) comments.splice(0, comments.length - 500);

  if (comment.slotId !== undefined) {
    slotData[comment.slotId].commentCount++;
    appendCommentToSlot(comment, suggestions, true);
    updateCommentCount(comment.slotId);
  }

  // AI提案を下部パネルに追加
  if (suggestions && suggestions.length > 0) {
    appendSuggestions(comment, suggestions);
  }

  updateStats();
});

socket.on('new-gift', (gift) => {
  const slotId = gift.slotId;
  if (slotId !== undefined) {
    appendEventToSlot(slotId, `🎁 ${gift.nickname} → ${gift.giftName} x${gift.repeatCount}`, 'gift');
  }
});

socket.on('new-member', (member) => {
  if (member.slotId !== undefined) {
    appendEventToSlot(member.slotId, `👋 ${member.nickname} が入室`, 'member');
  }
});

socket.on('new-like', (data) => {
  // いいねは頻度が高いので表示しない
});

socket.on('hype-update', ({ slotId, score, level }) => {
  const col = document.querySelector(`.slot-column[data-slot="${slotId}"]`);
  if (!col) return;
  const el = col.querySelector('.slot-hype');
  if (!el) return;
  const icons = { high: '🔥', medium: '⚡', low: '💤' };
  el.textContent = icons[level] || '--';
  el.title = `盛り上がりスコア: ${score}`;
  el.setAttribute('data-level', level);
});

socket.on('auto-suggestions', ({ slotId, suggestions, hype }) => {
  if (suggestions && suggestions.length > 0) {
    const dummyComment = { slotId };
    appendSuggestions(dummyComment, suggestions);
    showToast(`スロット${slotId + 1}: 自動提案が届きました`);
  }
});

// OllamaからのAI提案（遅延配信）
socket.on('ai-suggestions', (data) => {
  appendSuggestions({ slotId: data.slotId }, data.suggestions, 'ai');
});

// Whisper音声認識結果
socket.on('transcription', (data) => {
  if (data.slotId !== undefined && data.text) {
    appendTranscriptionToSlot(data.slotId, data.text);
  }
});

socket.on('comments-cleared', () => {
  comments = [];
  uniqueUsers.clear();
  slotData.forEach(s => s.commentCount = 0);
  document.querySelectorAll('.slot-comment-list').forEach(el => {
    el.innerHTML = '<p class="empty-msg">クリアしました</p>';
  });
  suggestionsList.innerHTML = '<p class="empty-msg" style="font-size:0.8rem">コメントが届くとAI提案が表示されます</p>';
  updateStats();
  updateAllCommentCounts();
});

socket.on('templates-updated', (t) => {
  templates = t;
  renderTemplates();
});

// ============ スロットUI ============

function updateSlotUI(data) {
  const col = document.querySelector(`.slot-column[data-slot="${data.id}"]`);
  if (!col) return;

  const dot = col.querySelector('.slot-status-dot');
  const username = col.querySelector('.slot-username');
  const viewers = col.querySelector('.slot-viewers');
  const input = col.querySelector('.slot-input');
  const connectBtn = col.querySelector('.btn-slot-connect');
  const disconnectBtn = col.querySelector('.btn-slot-disconnect');

  slotData[data.id].connected = data.connected;
  slotData[data.id].username = data.username;
  slotData[data.id].viewers = data.viewers;

  if (data.connected) {
    col.classList.add('connected');
    dot.className = 'slot-status-dot connected';
    username.textContent = `@${data.username}`;
    username.classList.remove('inactive');
    viewers.textContent = `👁 ${data.viewers}`;
    input.classList.add('hidden');
    connectBtn.classList.add('hidden');
    disconnectBtn.classList.remove('hidden');
  } else {
    col.classList.remove('connected');
    dot.className = 'slot-status-dot disconnected';
    username.textContent = '未接続';
    username.classList.add('inactive');
    viewers.textContent = '';
    input.classList.remove('hidden');
    connectBtn.classList.remove('hidden');
    disconnectBtn.classList.add('hidden');
  }
}

function updateCommentCount(slotId) {
  const col = document.querySelector(`.slot-column[data-slot="${slotId}"]`);
  if (!col) return;
  const countEl = col.querySelector('.slot-comment-count');
  if (countEl) countEl.textContent = slotData[slotId].commentCount;
}

function updateAllCommentCounts() {
  for (let i = 0; i < 5; i++) updateCommentCount(i);
}

function showSendButton(slotId, text) {
  hideSendButton(slotId);
  const col = document.querySelector(`.slot-column[data-slot="${slotId}"]`);
  if (!col) return;
  const btn = document.createElement('button');
  btn.className = 'btn btn-send-now';
  btn.dataset.slot = slotId;
  const short = (text || '').slice(0, 15);
  const suffix = (text && text.length > 15) ? '...' : '';
  btn.innerHTML = `📤 送信: ${escapeHtml(short)}${suffix}`;
  btn.addEventListener('click', () => {
    socket.emit('send-comment', { slotId: parseInt(slotId) });
    btn.disabled = true;
    btn.textContent = '送信中...';
  });
  col.querySelector('.slot-card').appendChild(btn);
}

function hideSendButton(slotId) {
  const col = document.querySelector(`.slot-column[data-slot="${slotId}"]`);
  if (col) col.querySelector('.btn-send-now')?.remove();
}

function updateStats() {
  $('stat-total').textContent = comments.length;
  $('stat-users').textContent = uniqueUsers.size;
  const now = Date.now();
  $('stat-cpm').textContent = comments.filter(c => c.timestamp > now - 60000).length;
}

// ============ 各スロットのコメント描画 ============

function appendCommentToSlot(comment, suggestions, scroll) {
  const list = document.querySelector(`.slot-comment-list[data-slot="${comment.slotId}"]`);
  if (!list) return;

  // プレースホルダー除去
  const placeholder = list.querySelector('.empty-msg');
  if (placeholder) placeholder.remove();

  const div = document.createElement('div');
  div.className = 'comment-item';

  const timeStr = new Date(comment.timestamp).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit', second: '2-digit' });

  let badges = '';
  if (comment.isModerator) badges += '<span class="comment-badge badge-mod">M</span>';
  if (comment.isSubscriber) badges += '<span class="comment-badge badge-sub">S</span>';

  let suggestionsHtml = '';
  if (suggestions && suggestions.length > 0) {
    suggestionsHtml = '<div class="comment-suggestions">' +
      suggestions.slice(0, 2).map(s =>
        `<button class="suggestion-chip" data-text="${escapeAttr(s.text)}" data-created="${Date.now()}">${truncate(s.text, 20)} <span class="chip-timer">0秒</span></button>`
      ).join('') +
      '</div>';
  }

  const avatarSrc = comment.profilePic || '';
  const avatarHtml = avatarSrc
    ? `<img class="comment-avatar" src="${escapeAttr(avatarSrc)}" alt="" onerror="this.style.display='none'">`
    : '<div class="comment-avatar"></div>';

  div.innerHTML = `
    ${avatarHtml}
    <div class="comment-body">
      <div class="comment-meta">
        <span class="comment-nickname">${escapeHtml(comment.nickname)}</span>
        ${badges}
        <span class="comment-time">${timeStr}</span>
      </div>
      <div class="comment-text">${escapeHtml(comment.text)}</div>
      ${suggestionsHtml}
    </div>
  `;

  div.querySelectorAll('.suggestion-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      if (sendMode === 'auto') {
        socket.emit('post-comment-auto', {
          text: chip.dataset.text,
          slotId: comment.slotId
        });
      } else {
        socket.emit('input-comment', {
          text: chip.dataset.text,
          slotId: comment.slotId
        });
      }
      chip.classList.add('copied');
      setTimeout(() => chip.remove(), 500);
    });
  });

  list.appendChild(div);

  // 最大100件に制限
  while (list.children.length > 100) list.removeChild(list.firstChild);

  if (scroll && list.dataset.paused !== 'true') list.scrollTop = list.scrollHeight;
}

function appendTranscriptionToSlot(slotId, text) {
  const list = document.querySelector(`.slot-comment-list[data-slot="${slotId}"]`);
  if (!list) return;

  const placeholder = list.querySelector('.empty-msg');
  if (placeholder) placeholder.remove();

  const div = document.createElement('div');
  div.className = 'comment-item transcription-item';
  const time = new Date().toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
  div.innerHTML = `<div class="comment-body"><div class="comment-meta"><span class="comment-nickname" style="color:#f39c12">🎤 配信者</span><span class="comment-time">${time}</span></div><div class="comment-text" style="color:#f39c12cc;font-style:italic">${escapeHtml(text)}</div></div>`;
  list.appendChild(div);
  while (list.children.length > 100) list.removeChild(list.firstChild);
  list.scrollTop = list.scrollHeight;
}

function appendEventToSlot(slotId, text, type) {
  const list = document.querySelector(`.slot-comment-list[data-slot="${slotId}"]`);
  if (!list) return;

  const placeholder = list.querySelector('.empty-msg');
  if (placeholder) placeholder.remove();

  const div = document.createElement('div');
  div.className = 'comment-item';
  div.style.opacity = '0.7';
  const time = new Date().toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
  div.innerHTML = `<div class="comment-body"><div class="comment-text" style="font-size:0.7rem;color:#888">[${time}] ${escapeHtml(text)}</div></div>`;
  list.appendChild(div);
  list.scrollTop = list.scrollHeight;
}

// ============ AI提案パネル ============

function appendSuggestions(comment, suggestions) {
  const placeholder = suggestionsList.querySelector('.empty-msg');
  if (placeholder) placeholder.remove();

  const createdAt = Date.now();

  suggestions.forEach(s => {
    const div = document.createElement('div');
    div.className = 'suggestion-item';
    const timerSpan = document.createElement('span');
    timerSpan.className = 'suggestion-timer';
    timerSpan.textContent = '0秒';

    div.innerHTML = `
      <span class="suggestion-source" data-slot="${comment.slotId}">${(comment.slotId !== undefined ? comment.slotId + 1 : '?')}</span>
      <span class="suggestion-text">${escapeHtml(s.text)}</span>
    `;
    div.appendChild(timerSpan);

    // クリックで送信/入力（モードに応じて振り分け）
    div.addEventListener('click', () => {
      if (sendMode === 'auto') {
        socket.emit('post-comment-auto', { text: s.text, slotId: comment.slotId });
      } else {
        socket.emit('input-comment', { text: s.text, slotId: comment.slotId });
      }
      div.classList.add('copied');
      setTimeout(() => div.remove(), 600);
    });

    suggestionsList.appendChild(div);

    // 経過秒数の更新タイマー
    const timer = setInterval(() => {
      if (!document.body.contains(div)) { clearInterval(timer); return; }
      const elapsed = Math.floor((Date.now() - createdAt) / 1000);
      if (elapsed < 60) {
        timerSpan.textContent = `${elapsed}秒`;
      } else {
        timerSpan.textContent = `${Math.floor(elapsed / 60)}分`;
      }
      // 古い提案は薄くする
      if (elapsed > 30) div.style.opacity = '0.5';
    }, 1000);
  });

  // 最新50件に制限
  while (suggestionsList.children.length > 50) suggestionsList.removeChild(suggestionsList.firstChild);
  suggestionsList.scrollTop = suggestionsList.scrollHeight;
}

// ============ テンプレート描画 ============

function renderTemplates() {
  templateList.innerHTML = '';
  const filtered = currentCategory === 'all'
    ? templates
    : templates.filter(t => t.category === currentCategory);

  filtered.forEach(t => {
    const div = document.createElement('div');
    div.className = 'template-item';

    const textSpan = document.createElement('span');
    textSpan.textContent = t.text;
    textSpan.addEventListener('click', () => copyToClipboard(t.text));
    div.appendChild(textSpan);

    const delBtn = document.createElement('button');
    delBtn.className = 'template-delete';
    delBtn.textContent = '\u2715';
    delBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      fetch(`/api/templates/${t.id}`, { method: 'DELETE' }).then(r => {
        if (r.ok) {
          templates = templates.filter(x => x.id !== t.id);
          renderTemplates();
          showToast('削除しました');
        }
      });
    });
    div.appendChild(delBtn);

    templateList.appendChild(div);
  });
}

// ============ イベントリスナー ============

// スロット接続
document.querySelectorAll('.btn-slot-connect').forEach(btn => {
  btn.addEventListener('click', () => {
    const slotId = parseInt(btn.dataset.slot);
    const input = document.querySelector(`.slot-input[data-slot="${slotId}"]`);
    const username = input.value.trim();
    if (!username) return;
    socket.emit('slot-connect', { slotId, username });
  });
});

// スロット切断
document.querySelectorAll('.btn-slot-disconnect').forEach(btn => {
  btn.addEventListener('click', () => {
    socket.emit('slot-disconnect', { slotId: parseInt(btn.dataset.slot) });
  });
});

// Enter で接続
document.querySelectorAll('.slot-input').forEach(input => {
  input.addEventListener('keydown', e => {
    if (e.key === 'Enter') {
      document.querySelector(`.btn-slot-connect[data-slot="${input.dataset.slot}"]`).click();
    }
  });
});

// コメント欄の自動スクロール一時停止
document.querySelectorAll('.slot-comment-list').forEach(list => {
  list.addEventListener('scroll', () => {
    const atBottom = list.scrollHeight - list.scrollTop - list.clientHeight < 30;
    list.dataset.paused = atBottom ? 'false' : 'true';
  });
});

// 全履歴クリア
$('clear-btn').addEventListener('click', () => socket.emit('clear-comments'));

// カテゴリ
document.querySelectorAll('.cat-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.cat-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentCategory = btn.dataset.cat;
    renderTemplates();
  });
});

// 送信モード切り替え
{
  const modeAuto = $('mode-auto');
  const modeManual = $('mode-manual');
  if (modeAuto && modeManual) {
    modeAuto.addEventListener('click', () => {
      sendMode = 'auto';
      modeAuto.classList.add('active');
      modeManual.classList.remove('active');
      showToast('1クリック自動送信モード');
    });
    modeManual.addEventListener('click', () => {
      sendMode = 'manual';
      modeManual.classList.add('active');
      modeAuto.classList.remove('active');
      showToast('2クリック確認送信モード');
    });
  }
}

// テンプレート追加
$('template-add-btn').addEventListener('click', () => {
  const input = $('template-input');
  const text = input.value.trim();
  if (!text) return;
  fetch('/api/templates', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, category: currentCategory === 'all' ? 'カスタム' : currentCategory })
  }).then(r => r.json()).then(t => {
    templates.push(t);
    renderTemplates();
    input.value = '';
    showToast('追加しました');
  });
});

$('template-input').addEventListener('keydown', e => {
  if (e.key === 'Enter') $('template-add-btn').click();
});

// ============ ユーティリティ ============

function escapeHtml(str) {
  const d = document.createElement('div');
  d.textContent = str;
  return d.innerHTML;
}

function escapeAttr(str) {
  return str.replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function truncate(str, len) {
  return str.length > len ? str.slice(0, len) + '...' : str;
}

function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(() => {
    showToast('コピー: ' + truncate(text, 30));
  }).catch(() => {
    const ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
    showToast('コピーしました');
  });
}

function showToast(message, isError = false) {
  const toast = document.createElement('div');
  toast.className = 'toast';
  if (isError) toast.style.background = '#ff4d6a';
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}

setInterval(updateStats, 10000);

// コメント内の提案チップの経過秒数を更新
setInterval(() => {
  document.querySelectorAll('.suggestion-chip[data-created]').forEach(chip => {
    const created = parseInt(chip.dataset.created);
    if (!created) return;
    const elapsed = Math.floor((Date.now() - created) / 1000);
    const timerEl = chip.querySelector('.chip-timer');
    if (timerEl) {
      timerEl.textContent = elapsed < 60 ? `${elapsed}秒` : `${Math.floor(elapsed / 60)}分`;
    }
    if (elapsed > 30) chip.style.opacity = '0.5';
  });
}, 1000);
