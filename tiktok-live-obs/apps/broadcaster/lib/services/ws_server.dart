import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

class WsServerState {
  final bool isRunning;
  final String? localIp;
  final int port;
  final String token;
  final int connectedClients;
  final String? error;

  const WsServerState({
    this.isRunning = false,
    this.localIp,
    this.port = AppConstants.wsPort,
    this.token = '',
    this.connectedClients = 0,
    this.error,
  });

  WsServerState copyWith({
    bool? isRunning,
    String? localIp,
    int? port,
    String? token,
    int? connectedClients,
    String? error,
    bool clearError = false,
  }) =>
      WsServerState(
        isRunning: isRunning ?? this.isRunning,
        localIp: localIp ?? this.localIp,
        port: port ?? this.port,
        token: token ?? this.token,
        connectedClients: connectedClients ?? this.connectedClients,
        error: clearError ? null : (error ?? this.error),
      );

  String get wsUrl => 'ws://$localIp:$port';
  String get qrData => jsonEncode({
        'wsUrl': wsUrl,
        'token': token,
        'name': 'Broadcaster',
      });
}

class WsServerNotifier extends StateNotifier<WsServerState> {
  WsServerNotifier(this._onMessage) : super(const WsServerState());

  HttpServer? _httpServer;
  final List<WebSocket> _clients = [];
  final void Function(WsMessage message, WebSocket sender) _onMessage;
  Timer? _pingTimer;
  final Map<WebSocket, DateTime> _lastPong = {};

  Future<void> start() async {
    if (state.isRunning) return;

    final ip = await _getLocalIp();
    if (ip == null) {
      state = state.copyWith(error: 'WiFiネットワークが見つかりません');
      return;
    }
    final token = generateToken();

    try {
      _httpServer =
          await HttpServer.bind(InternetAddress.anyIPv4, state.port);
    } catch (e) {
      debugPrint('WS server bind error: $e');
      state = state.copyWith(error: 'ポート${state.port}のバインドに失敗: $e');
      return;
    }

    state = state.copyWith(
      isRunning: true,
      localIp: ip,
      token: token,
      clearError: true,
    );

    _startPingTimer();

    _httpServer!.transform(WebSocketTransformer()).listen(
      (WebSocket ws) {
        _clients.add(ws);
        _lastPong[ws] = DateTime.now();
        state = state.copyWith(connectedClients: _clients.length);
        debugPrint('WS: client connected. Total: ${_clients.length}');

        ws.listen(
          (data) {
            try {
              if (data is! String) {
                debugPrint('WS: ignoring non-string data');
                return;
              }
              final msg = WsMessage.decode(data);

              // Handle PONG
              if (msg.type == WsCmd.pong) {
                _lastPong[ws] = DateTime.now();
                return;
              }

              // Validate token on PAIR
              if (msg.type == WsCmd.pair) {
                if (msg.payload['token'] != state.token) {
                  ws.add(WsMessage.ack(msg.reqId,
                          ok: false, error: WsError.invalidToken)
                      .encode());
                  return;
                }
                debugPrint('WS: PAIR accepted. Clients: ${_clients.length}');
              }
              _onMessage(msg, ws);
            } catch (e) {
              debugPrint('WS message parse error: $e');
            }
          },
          onDone: () {
            _removeClient(ws);
          },
          onError: (e) {
            debugPrint('WS client error: $e');
            _removeClient(ws);
          },
        );
      },
    );
  }

  void _removeClient(WebSocket ws) {
    _clients.remove(ws);
    _lastPong.remove(ws);
    state = state.copyWith(connectedClients: _clients.length);
    debugPrint('WS: client disconnected. Total: ${_clients.length}');
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      Duration(seconds: AppConstants.wsPingIntervalSec),
      (_) {
        final now = DateTime.now();
        final staleClients = <WebSocket>[];

        for (final client in _clients) {
          final lastSeen = _lastPong[client];
          if (lastSeen != null &&
              now.difference(lastSeen).inSeconds > AppConstants.wsTimeoutSec) {
            staleClients.add(client);
          }
        }

        // Disconnect stale clients
        for (final ws in staleClients) {
          debugPrint('WS: closing stale client');
          try {
            ws.close();
          } catch (_) {}
          _removeClient(ws);
        }

        // Send PING to remaining
        final pingMsg =
            WsMessage(type: WsCmd.ping, reqId: '').encode();
        for (final client in _clients) {
          try {
            client.add(pingMsg);
          } catch (e) {
            debugPrint('WS ping send error: $e');
          }
        }
      },
    );
  }

  void broadcast(WsMessage msg) {
    final encoded = msg.encode();
    for (final client in List.of(_clients)) {
      try {
        client.add(encoded);
      } catch (e) {
        debugPrint('WS broadcast error: $e');
      }
    }
  }

  void sendTo(WebSocket ws, WsMessage msg) {
    try {
      ws.add(msg.encode());
    } catch (e) {
      debugPrint('WS sendTo error: $e');
    }
  }

  Future<void> stop() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    for (final ws in List.of(_clients)) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _clients.clear();
    _lastPong.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
    state = state.copyWith(isRunning: false, connectedClients: 0);
  }

  static bool _isPrivateIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]) ?? 0;
    final b = int.tryParse(parts[1]) ?? 0;
    // 10.x.x.x, 172.16-31.x.x, 192.168.x.x
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  Future<String?> _getLocalIp() async {
    try {
      // Method 1: NetworkInterface
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && _isPrivateIp(addr.address)) {
            return addr.address;
          }
        }
      }
      // Fallback: first non-loopback
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      debugPrint('Get local IP (interface) error: $e');
    }

    // Method 2: UDP socket trick
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.close();
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      debugPrint('Get local IP (socket) error: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    // Fire-and-forget stop; we can't await in dispose
    for (final ws in _clients) {
      try {
        ws.close();
      } catch (_) {}
    }
    _clients.clear();
    _lastPong.clear();
    _httpServer?.close(force: true);
    _httpServer = null;
    super.dispose();
  }
}
