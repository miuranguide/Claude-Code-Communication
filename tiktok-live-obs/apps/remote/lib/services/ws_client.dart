import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared/shared.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class WsClientState {
  final ConnectionStatus connectionStatus;
  final String? wsUrl;
  final String? token;
  final String? broadcasterName;
  final List<Map<String, dynamic>> clips;
  final List<Map<String, dynamic>> tracks;
  final String? lastError;
  final String? lastAckStatus; // "ok" / "error:..."
  final int reconnectAttempt;

  const WsClientState({
    this.connectionStatus = ConnectionStatus.disconnected,
    this.wsUrl,
    this.token,
    this.broadcasterName,
    this.clips = const [],
    this.tracks = const [],
    this.lastError,
    this.lastAckStatus,
    this.reconnectAttempt = 0,
  });

  bool get connected => connectionStatus == ConnectionStatus.connected;

  WsClientState copyWith({
    ConnectionStatus? connectionStatus,
    String? wsUrl,
    String? token,
    String? broadcasterName,
    List<Map<String, dynamic>>? clips,
    List<Map<String, dynamic>>? tracks,
    String? lastError,
    String? lastAckStatus,
    int? reconnectAttempt,
    bool clearError = false,
    bool clearAck = false,
  }) =>
      WsClientState(
        connectionStatus: connectionStatus ?? this.connectionStatus,
        wsUrl: wsUrl ?? this.wsUrl,
        token: token ?? this.token,
        broadcasterName: broadcasterName ?? this.broadcasterName,
        clips: clips ?? this.clips,
        tracks: tracks ?? this.tracks,
        lastError: clearError ? null : (lastError ?? this.lastError),
        lastAckStatus:
            clearAck ? null : (lastAckStatus ?? this.lastAckStatus),
        reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      );
}

class WsClientNotifier extends StateNotifier<WsClientState> {
  WsClientNotifier() : super(const WsClientState());

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  int _reqCounter = 0;
  bool _disposed = false;
  final Map<String, Completer<WsMessage>> _pending = {};
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  DateTime? _lastServerMessage;

  static const _boxName = 'ws_connection';
  Box<dynamic>? _box;

  Future<Box<dynamic>> _getBox() async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// Save connection info to Hive for auto-reconnect
  Future<void> _saveConnection(String wsUrl, String token, String? name) async {
    try {
      final box = await _getBox();
      await box.put('wsUrl', wsUrl);
      await box.put('token', token);
      await box.put('broadcasterName', name);
    } catch (e) {
      debugPrint('Save connection error: $e');
    }
  }

  /// Clear saved connection info
  Future<void> clearSavedConnection() async {
    try {
      final box = await _getBox();
      await box.clear();
    } catch (e) {
      debugPrint('Clear connection error: $e');
    }
  }

  /// Check if saved connection info exists
  Future<bool> get hasSavedConnection async {
    try {
      final box = await _getBox();
      return box.get('wsUrl') != null && box.get('token') != null;
    } catch (_) {
      return false;
    }
  }

  /// Try to auto-reconnect using saved connection info
  Future<bool> tryAutoReconnect() async {
    try {
      final box = await _getBox();
      final wsUrl = box.get('wsUrl') as String?;
      final token = box.get('token') as String?;
      final name = box.get('broadcasterName') as String?;
      if (wsUrl == null || token == null) return false;
      return connect(wsUrl, token, name: name);
    } catch (e) {
      debugPrint('Auto-reconnect error: $e');
      return false;
    }
  }

  String _nextReqId() => '${++_reqCounter}';

  Future<bool> connect(String wsUrl, String token,
      {String? name}) async {
    try {
      disconnect();
      state = state.copyWith(
        connectionStatus: ConnectionStatus.connecting,
        wsUrl: wsUrl,
        token: token,
        broadcasterName: name,
        clearError: true,
        reconnectAttempt: 0,
      );

      final uri = Uri.parse('$wsUrl?token=$token');
      _channel = WebSocketChannel.connect(uri);

      // Wait for WebSocket handshake to complete
      try {
        await _channel!.ready;
      } catch (e) {
        debugPrint('WS client: handshake failed: $e');
        state = state.copyWith(
          connectionStatus: ConnectionStatus.error,
          lastError: '接続ハンドシェイク失敗',
        );
        _channel = null;
        return false;
      }

      _sub = _channel!.stream.listen(
        (data) {
          if (data is! String) {
            debugPrint('WS client: ignoring non-string data');
            return;
          }
          _onMessage(data);
        },
        onDone: () {
          state = state.copyWith(
              connectionStatus: ConnectionStatus.disconnected);
          _scheduleReconnect();
        },
        onError: (e) {
          debugPrint('WS client error: $e');
          state = state.copyWith(
            connectionStatus: ConnectionStatus.error,
            lastError: '接続エラー',
          );
          _scheduleReconnect();
        },
      );

      state = state.copyWith(
        connectionStatus: ConnectionStatus.connected,
        clearError: true,
      );

      _startPingWatchdog();

      // Send PAIR
      await send(WsCmd.pair, {'token': token, 'deviceName': 'Remote'});

      // Save connection info for auto-reconnect
      _saveConnection(wsUrl, token, name);

      return true;
    } catch (e) {
      debugPrint('WS client connect error: $e');
      state = state.copyWith(
        connectionStatus: ConnectionStatus.error,
        lastError: e.toString(),
      );
      return false;
    }
  }

  void _startPingWatchdog() {
    _pingTimer?.cancel();
    _lastServerMessage = DateTime.now();
    _pingTimer = Timer.periodic(
      const Duration(seconds: AppConstants.wsPingIntervalSec),
      (_) {
        if (_lastServerMessage != null &&
            DateTime.now().difference(_lastServerMessage!).inSeconds >
                AppConstants.wsTimeoutSec) {
          debugPrint('WS client: server timeout, reconnecting');
          _sub?.cancel();
          _channel?.sink.close();
          _channel = null;
          state = state.copyWith(
              connectionStatus: ConnectionStatus.disconnected);
          _scheduleReconnect();
        }
      },
    );
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_disposed) return;
    if (state.wsUrl == null || state.token == null) return;

    final attempt = state.reconnectAttempt;
    if (attempt >= AppConstants.maxReconnectAttempts) {
      state = state.copyWith(
        connectionStatus: ConnectionStatus.error,
        lastError: '再接続の上限に達しました',
      );
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped)
    final delaySec = min(1 << attempt, 16);
    state = state.copyWith(
      connectionStatus: ConnectionStatus.reconnecting,
      reconnectAttempt: attempt + 1,
    );

    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_disposed && state.wsUrl != null && state.token != null) {
        connect(state.wsUrl!, state.token!,
            name: state.broadcasterName);
      }
    });
  }

  void manualReconnect() {
    _reconnectTimer?.cancel();
    state = state.copyWith(reconnectAttempt: 0);
    if (state.wsUrl != null && state.token != null) {
      connect(state.wsUrl!, state.token!,
          name: state.broadcasterName);
    }
  }

  void _onMessage(String raw) {
    try {
      _lastServerMessage = DateTime.now();
      final msg = WsMessage.decode(raw);

      // Handle PING -> send PONG
      if (msg.type == WsCmd.ping) {
        _channel?.sink
            .add(WsMessage(type: WsCmd.pong, reqId: '').encode());
        return;
      }

      // Handle ACK
      if (msg.type == WsCmd.ack) {
        final ok = msg.payload['ok'] == true;
        final error = msg.payload['error'] as String?;
        state = state.copyWith(
          lastAckStatus: ok ? 'ok' : 'error:${error ?? "unknown"}',
        );
        // Complete pending future
        final completer = _pending.remove(msg.reqId);
        completer?.complete(msg);
        // Clear status after 3s
        Future.delayed(const Duration(seconds: 3), () {
          if (!_disposed) state = state.copyWith(clearAck: true);
        });
        return;
      }

      // Handle ASSET_LIST
      if (msg.type == WsCmd.assetList) {
        final clips = (msg.payload['clips'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final tracks = (msg.payload['tracks'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        state = state.copyWith(clips: clips, tracks: tracks);
        return;
      }
    } catch (e) {
      debugPrint('WS client message parse error: $e');
    }
  }

  Future<WsMessage?> send(String type,
      [Map<String, dynamic> payload = const {}]) async {
    if (_channel == null) return null;
    final reqId = _nextReqId();
    final msg =
        WsMessage(type: type, reqId: reqId, payload: payload);
    final completer = Completer<WsMessage>();
    _pending[reqId] = completer;
    _channel!.sink.add(msg.encode());

    // Timeout 5s
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pending.remove(reqId);
        return WsMessage.ack(reqId, ok: false, error: 'TIMEOUT');
      },
    );
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    state = state.copyWith(
      connectionStatus: ConnectionStatus.disconnected,
      reconnectAttempt: 0,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    disconnect();
    super.dispose();
  }
}

final wsClientProvider =
    StateNotifierProvider<WsClientNotifier, WsClientState>((ref) {
  return WsClientNotifier();
});
