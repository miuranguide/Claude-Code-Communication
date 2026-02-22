import 'dart:convert';
import 'package:test/test.dart';
import 'package:shared/shared.dart';

void main() {
  group('WsMessage', () {
    test('encode/decode roundtrip', () {
      final msg = WsMessage(
        type: WsCmd.playClip,
        reqId: '42',
        payload: {'clipId': 'clip_abc'},
      );

      final encoded = msg.encode();
      final decoded = WsMessage.decode(encoded);

      expect(decoded.type, WsCmd.playClip);
      expect(decoded.reqId, '42');
      expect(decoded.payload['clipId'], 'clip_abc');
    });

    test('toJson spreads payload', () {
      final msg = WsMessage(
        type: 'TEST',
        reqId: '1',
        payload: {'key': 'value'},
      );

      final json = msg.toJson();
      expect(json['type'], 'TEST');
      expect(json['reqId'], '1');
      expect(json['key'], 'value');
    });

    test('fromJson extracts payload', () {
      final json = {
        'type': 'TEST',
        'reqId': '1',
        'foo': 'bar',
        'num': 42,
      };
      final msg = WsMessage.fromJson(json);

      expect(msg.type, 'TEST');
      expect(msg.reqId, '1');
      expect(msg.payload['foo'], 'bar');
      expect(msg.payload['num'], 42);
      expect(msg.payload.containsKey('type'), false);
      expect(msg.payload.containsKey('reqId'), false);
    });

    test('missing reqId defaults to empty string', () {
      final json = {'type': 'TEST'};
      final msg = WsMessage.fromJson(json);
      expect(msg.reqId, '');
    });

    test('ack factory creates correct message', () {
      final ack = WsMessage.ack('req123', ok: true);
      expect(ack.type, 'ACK');
      expect(ack.reqId, 'req123');
      expect(ack.payload['ok'], true);
      expect(ack.payload.containsKey('error'), false);
    });

    test('ack with error', () {
      final ack = WsMessage.ack('req456',
          ok: false, error: WsError.clipNotFound);
      expect(ack.payload['ok'], false);
      expect(ack.payload['error'], 'CLIP_NOT_FOUND');
    });

    test('decode from raw JSON string', () {
      final raw = jsonEncode({
        'type': WsCmd.pair,
        'reqId': '10',
        'token': 'abc123',
        'deviceName': 'Remote',
      });

      final msg = WsMessage.decode(raw);
      expect(msg.type, WsCmd.pair);
      expect(msg.payload['token'], 'abc123');
      expect(msg.payload['deviceName'], 'Remote');
    });

    test('empty payload', () {
      final msg = WsMessage(type: WsCmd.stopClip, reqId: '5');
      final encoded = msg.encode();
      final decoded = WsMessage.decode(encoded);

      expect(decoded.type, WsCmd.stopClip);
      expect(decoded.payload, isEmpty);
    });
  });

  group('WsCmd', () {
    test('all command constants are defined', () {
      expect(WsCmd.pair, 'PAIR');
      expect(WsCmd.playClip, 'PLAY_CLIP');
      expect(WsCmd.stopClip, 'STOP_CLIP');
      expect(WsCmd.playBgm, 'PLAY_BGM');
      expect(WsCmd.stopBgm, 'STOP_BGM');
      expect(WsCmd.setMix, 'SET_MIX');
      expect(WsCmd.ack, 'ACK');
      expect(WsCmd.ping, 'PING');
      expect(WsCmd.pong, 'PONG');
      expect(WsCmd.syncState, 'SYNC_STATE');
      expect(WsCmd.clipStarted, 'CLIP_STARTED');
      expect(WsCmd.clipEnded, 'CLIP_ENDED');
      expect(WsCmd.bgmStarted, 'BGM_STARTED');
      expect(WsCmd.bgmStopped, 'BGM_STOPPED');
      expect(WsCmd.assetList, 'ASSET_LIST');
    });
  });

  group('WsError', () {
    test('all error constants are defined', () {
      expect(WsError.clipNotFound, 'CLIP_NOT_FOUND');
      expect(WsError.trackNotFound, 'TRACK_NOT_FOUND');
      expect(WsError.presetNotFound, 'PRESET_NOT_FOUND');
      expect(WsError.cooldownActive, 'COOLDOWN_ACTIVE');
      expect(WsError.invalidToken, 'INVALID_TOKEN');
    });
  });

  group('IdGen', () {
    test('generateId produces correct format', () {
      final id = generateId('clip');
      expect(id.startsWith('clip_'), true);
      expect(id.length, 13); // "clip_" + 8 chars
    });

    test('generateId without prefix', () {
      final id = generateId();
      expect(id.length, 8);
    });

    test('generateToken produces 24 chars', () {
      final token = generateToken();
      expect(token.length, 24);
    });

    test('generated ids are unique', () {
      final ids = List.generate(100, (_) => generateId());
      expect(ids.toSet().length, ids.length);
    });
  });
}
