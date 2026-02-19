// ============================================================
//  tiktok-live-controller 自動テスト
//  全18項目の動作を検証
// ============================================================
const { io } = require('socket.io-client');
const http = require('https');

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const BASE = 'https://localhost:3000';
let passed = 0;
let failed = 0;
const results = [];

function ok(name) { passed++; results.push(`  OK  ${name}`); }
function fail(name, err) { failed++; results.push(`  FAIL ${name}: ${err}`); }

function fetch(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    }).on('error', reject);
  });
}

async function run() {
  console.log('=== tiktok-live-controller テスト開始 ===\n');

  // --- 静的ファイルテスト ---
  try {
    const r = await fetch(`${BASE}/display.html`);
    if (r.status === 200 && r.body.includes('reconnect-banner')) ok('display.html (reconnect-banner含む)');
    else fail('display.html', 'reconnect-bannerが見つからない');
  } catch (e) { fail('display.html', e.message); }

  try {
    const r = await fetch(`${BASE}/controller.html`);
    if (r.status === 200 && r.body.includes('toast-container') && r.body.includes('reconnect-banner'))
      ok('controller.html (toast+reconnect含む)');
    else fail('controller.html', '必要要素なし');
  } catch (e) { fail('controller.html', e.message); }

  // 2.2: 複数レイヤー
  try {
    const r = await fetch(`${BASE}/display.html`);
    if (r.body.includes('video-overlay-0') && r.body.includes('video-overlay-1') && r.body.includes('video-overlay-2'))
      ok('2.2 display.html: 3レイヤー要素');
    else fail('2.2 display.html: 3レイヤー要素', '見つからない');
  } catch (e) { fail('2.2 display: layers', e.message); }

  // 2.1: PiPコーナーボタン
  try {
    const r = await fetch(`${BASE}/controller.html`);
    if (r.body.includes('top-left') && r.body.includes('bottom-right'))
      ok('2.1 controller.html: PiPコーナーボタン');
    else fail('2.1 PiPコーナー', '見つからない');
  } catch (e) { fail('2.1 PiP', e.message); }

  // 2.4: ループボタン
  try {
    const r = await fetch(`${BASE}/controller.html`);
    if (r.body.includes('loop-toggle-btn')) ok('2.4 ループトグルボタン');
    else fail('2.4 ループ', '見つからない');
  } catch (e) { fail('2.4 ループ', e.message); }

  // 2.5: トランジション
  try {
    const r = await fetch(`${BASE}/controller.html`);
    if (r.body.includes('transition-select') && r.body.includes('fadeIn'))
      ok('2.5 トランジション選択');
    else fail('2.5 トランジション', '見つからない');
  } catch (e) { fail('2.5 トランジション', e.message); }

  // 2.3: 透明度スライダー
  try {
    const r = await fetch(`${BASE}/controller.html`);
    if (r.body.includes('layer-opacity')) ok('2.3 透明度スライダー');
    else fail('2.3 透明度', '見つからない');
  } catch (e) { fail('2.3 透明度', e.message); }

  // 2.6: タイマー
  try {
    const r = await fetch(`${BASE}/controller.html`);
    if (r.body.includes('timer-video-select') && r.body.includes('timer-add-btn'))
      ok('2.6 タイマーUI');
    else fail('2.6 タイマー', '見つからない');
  } catch (e) { fail('2.6 タイマー', e.message); }

  // 1.5: キーボードショートカット表示
  try {
    const r = await fetch(`${BASE}/controller.html`);
    if (r.body.includes('Ctrl+Z') && r.body.includes('ショートカット'))
      ok('1.5 ショートカット説明');
    else fail('1.5 ショートカット', '見つからない');
  } catch (e) { fail('1.5 ショートカット', e.message); }

  // 1.6: プリセットUI
  try {
    const r = await fetch(`${BASE}/controller.html`);
    if (r.body.includes('preset-chips') && r.body.includes('preset-save-btn'))
      ok('1.6 プリセットUI');
    else fail('1.6 プリセット', '見つからない');
  } catch (e) { fail('1.6 プリセット', e.message); }

  // 2.5: CSSトランジション
  try {
    const r = await fetch(`${BASE}/display.css`);
    if (r.body.includes('overlayFadeIn') && r.body.includes('overlaySlideIn') && r.body.includes('overlayScaleIn'))
      ok('2.5 CSSトランジションアニメーション');
    else fail('2.5 CSSアニメ', '見つからない');
  } catch (e) { fail('2.5 CSSアニメ', e.message); }

  // 1.1: Toast CSS
  try {
    const r = await fetch(`${BASE}/controller.css`);
    if (r.body.includes('toast-success') && r.body.includes('toast-error') && r.body.includes('toast-info'))
      ok('1.1 Toast CSSスタイル');
    else fail('1.1 Toast CSS', '見つからない');
  } catch (e) { fail('1.1 Toast CSS', e.message); }

  // display.js機能チェック
  try {
    const r = await fetch(`${BASE}/display.js`);
    const b = r.body;
    if (b.includes('reconnectionDelay')) ok('1.2 display.js: 再接続設定');
    else fail('1.2 display.js: 再接続', '見つからない');

    if (b.includes('gradientCache')) ok('3.2 display.js: グラデーションキャッシュ');
    else fail('3.2 グラデキャッシュ', '見つからない');

    if (b.includes('toBlob')) ok('3.3 display.js: toBlob最適化');
    else fail('3.3 toBlob', '見つからない');

    if (b.includes('showOverlayWithTransition') && b.includes('hideOverlayWithTransition'))
      ok('2.5 display.js: トランジション関数');
    else fail('2.5 トランジション関数', '見つからない');

    if (b.includes('reportCurrentState')) ok('1.4 display.js: 状態報告');
    else fail('1.4 状態報告', '見つからない');

    if (b.includes('overlayLayers')) ok('2.2 display.js: マルチレイヤー');
    else fail('2.2 マルチレイヤー', '見つからない');

    // 3.1: シングルパス（ダブルダウンスケール除去確認）
    const smoothMatch = b.match(/applySkinSmoothing[\s\S]{0,500}/);
    if (smoothMatch) {
      const fn = smoothMatch[0];
      // ダブルダウンスケールが無い = smallCtx.drawImage → tempCtx.drawImage のみ
      const drawCalls = (fn.match(/drawImage/g) || []).length;
      if (drawCalls <= 4) ok('3.1 美肌シングルパス最適化');
      else fail('3.1 美肌シングルパス', `drawImage calls: ${drawCalls}`);
    } else fail('3.1 美肌', '関数見つからない');
  } catch (e) { fail('display.js checks', e.message); }

  // controller.js機能チェック
  try {
    const r = await fetch(`${BASE}/controller.js`);
    const b = r.body;
    if (b.includes('showToast')) ok('1.1 controller.js: showToast関数');
    else fail('1.1 showToast', '見つからない');

    if (b.includes('reconnectionDelay')) ok('1.2 controller.js: 再接続設定');
    else fail('1.2 再接続', '見つからない');

    if (b.includes('ovRectHistory') && b.includes('undoOvRect')) ok('1.7 controller.js: Undo');
    else fail('1.7 Undo', '見つからない');

    if (b.includes('keydown') && b.includes("e.code === 'Space'")) ok('1.5 controller.js: キーボードショートカット');
    else fail('1.5 ショートカット', '見つからない');

    if (b.includes('overlayPresets') && b.includes('saveOverlayPresets')) ok('1.6 controller.js: プリセット保存');
    else fail('1.6 プリセット保存', '見つからない');

    if (b.includes('sync-state')) ok('1.4 controller.js: 状態同期受信');
    else fail('1.4 状態同期', '見つからない');

    if (b.includes('currentLayer')) ok('2.2 controller.js: レイヤー管理');
    else fail('2.2 レイヤー管理', '見つからない');

    if (b.includes('loopMode')) ok('2.4 controller.js: ループモード');
    else fail('2.4 ループモード', '見つからない');

    if (b.includes('currentTransition')) ok('2.5 controller.js: トランジション');
    else fail('2.5 トランジション', '見つからない');

    if (b.includes('layerOpacity')) ok('2.3 controller.js: 透明度');
    else fail('2.3 透明度', '見つからない');

    if (b.includes('scheduleVideoPlay') && b.includes('cancelTimer')) ok('2.6 controller.js: タイマー');
    else fail('2.6 タイマー', '見つからない');

    if (b.includes('IntersectionObserver')) ok('3.5 controller.js: 遅延読込');
    else fail('3.5 遅延読込', '見つからない');

    if (b.includes('thumbUrl')) ok('3.4 controller.js: サーバーサムネ優先');
    else fail('3.4 サーバーサムネ', '見つからない');

    // 2.1: PiPコーナー
    if (b.includes("'top-left'") && b.includes("'bottom-right'")) ok('2.1 controller.js: PiPコーナー計算');
    else fail('2.1 PiPコーナー', '見つからない');
  } catch (e) { fail('controller.js checks', e.message); }

  // server.js チェック
  try {
    const r = await fetch(`${BASE}/api/media`);
    if (r.status === 200) ok('API /api/media');
    else fail('API /api/media', `status: ${r.status}`);
  } catch (e) { fail('API', e.message); }

  // --- Socket.IO ACKテスト (1.3) ---
  await new Promise((resolve) => {
    const display = io(BASE, { rejectUnauthorized: false });
    const controller = io(BASE, { rejectUnauthorized: false });

    let done = false;
    const timeout = setTimeout(() => {
      if (!done) { fail('Socket.IO ACKテスト', 'タイムアウト'); done = true; resolve(); }
      display.close(); controller.close();
    }, 5000);

    display.on('connect', () => {
      display.emit('join-room', { roomId: 'test-room-auto', role: 'display' });
    });

    controller.on('connect', () => {
      controller.emit('join-room', { roomId: 'test-room-auto', role: 'controller' });
    });

    // displayがstop-allを受信→ACK返す
    display.on('stop-all', (data, ack) => {
      if (ack) ack({ ok: true });
    });

    // 両方入室したらACKテスト
    let joined = 0;
    function checkJoined() {
      joined++;
      if (joined < 2) return;

      // ACK付きstop-all送信
      controller.emit('stop-all', {}, (resp) => {
        if (resp && resp.ok) {
          ok('1.3 Socket ACKリレー (stop-all)');
        } else {
          fail('1.3 Socket ACK', `応答: ${JSON.stringify(resp)}`);
        }

        // 状態同期テスト: controllerがrequest-state送信
        display.on('request-state', (data, ack) => {
          if (ack) ack({ layers: [], playingAudioIds: [], beautyParams: {} });
        });

        controller.on('sync-state', (state) => {
          if (state && state.layers !== undefined) {
            ok('1.4 状態同期 (request-state → sync-state)');
          } else {
            fail('1.4 状態同期', '状態データなし');
          }
          if (!done) { done = true; clearTimeout(timeout); display.close(); controller.close(); resolve(); }
        });

        controller.emit('request-state');
      });
    }

    controller.on('room-status', checkJoined);
    display.on('room-status', checkJoined);
  });

  // --- 結果表示 ---
  console.log(results.join('\n'));
  console.log(`\n=== テスト結果: ${passed} passed, ${failed} failed ===`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(e => { console.error(e); process.exit(1); });
