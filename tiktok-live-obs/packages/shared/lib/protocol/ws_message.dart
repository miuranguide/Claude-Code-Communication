import 'dart:convert';

class WsMessage {
  final String type;
  final String reqId;
  final Map<String, dynamic> payload;

  WsMessage({
    required this.type,
    required this.reqId,
    this.payload = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'reqId': reqId,
        ...payload,
      };

  String encode() => jsonEncode(toJson());

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final reqId = json['reqId'] as String? ?? '';
    final payload = Map<String, dynamic>.from(json)
      ..remove('type')
      ..remove('reqId');
    return WsMessage(type: type, reqId: reqId, payload: payload);
  }

  factory WsMessage.decode(String raw) =>
      WsMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// Create ACK response
  static WsMessage ack(String reqId, {bool ok = true, String? error}) =>
      WsMessage(
        type: 'ACK',
        reqId: reqId,
        payload: {
          'ok': ok,
          if (error != null) 'error': error,
        },
      );
}
