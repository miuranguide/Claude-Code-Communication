import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import '../services/ws_server.dart';
import 'asset_provider.dart';
import 'playback_provider.dart';

WsMessage _buildAssetListMessage(List<Clip> clips, List<Track> tracks) {
  return WsMessage(
    type: WsCmd.assetList,
    reqId: '',
    payload: {
      'clips': clips
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'category': c.category.name,
                'durationMs': c.durationMs,
              })
          .toList(),
      'tracks': tracks
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'durationMs': t.durationMs,
              })
          .toList(),
    },
  );
}

final wsServerProvider =
    StateNotifierProvider<WsServerNotifier, WsServerState>((ref) {
  late final WsServerNotifier notifier;
  notifier = WsServerNotifier((WsMessage msg, WebSocket sender) {
    final playback = ref.read(playbackProvider.notifier);
    final clips = ref.read(clipListProvider);
    final tracks = ref.read(trackListProvider);

    switch (msg.type) {
      case WsCmd.pair:
        // Send ACK + asset list
        notifier.sendTo(sender, WsMessage.ack(msg.reqId));
        // Send current assets to remote
        notifier.sendTo(sender, _buildAssetListMessage(clips, tracks));
        break;

      case WsCmd.playClip:
        final clipId = msg.payload['clipId'] as String?;
        if (clipId == null) {
          notifier.sendTo(sender,
              WsMessage.ack(msg.reqId, ok: false, error: WsError.clipNotFound));
          return;
        }
        final clip = clips.where((c) => c.id == clipId).firstOrNull;
        if (clip == null) {
          notifier.sendTo(sender,
              WsMessage.ack(msg.reqId, ok: false, error: WsError.clipNotFound));
          return;
        }
        if (playback.isCooldownActive) {
          notifier.sendTo(
              sender,
              WsMessage.ack(msg.reqId,
                  ok: false, error: WsError.cooldownActive));
          return;
        }
        playback.playClip(clip);
        notifier.sendTo(sender, WsMessage.ack(msg.reqId));
        notifier.broadcast(WsMessage(
          type: WsCmd.clipStarted,
          reqId: '',
          payload: {'clipId': clipId},
        ));
        break;

      case WsCmd.stopClip:
        playback.stopClip();
        notifier.sendTo(sender, WsMessage.ack(msg.reqId));
        notifier.broadcast(WsMessage(
          type: WsCmd.clipEnded,
          reqId: '',
        ));
        break;

      case WsCmd.playBgm:
        final trackId = msg.payload['trackId'] as String?;
        final track = tracks.where((t) => t.id == trackId).firstOrNull;
        if (track == null) {
          notifier.sendTo(
              sender,
              WsMessage.ack(msg.reqId,
                  ok: false, error: WsError.trackNotFound));
          return;
        }
        playback.playBgm(track);
        notifier.sendTo(sender, WsMessage.ack(msg.reqId));
        notifier.broadcast(WsMessage(
          type: WsCmd.bgmStarted,
          reqId: '',
          payload: {'trackId': trackId},
        ));
        break;

      case WsCmd.stopBgm:
        playback.stopBgm();
        notifier.sendTo(sender, WsMessage.ack(msg.reqId));
        notifier.broadcast(WsMessage(
          type: WsCmd.bgmStopped,
          reqId: '',
        ));
        break;

      case WsCmd.setMix:
        final presetName = msg.payload['name'] as String? ?? 'カスタム';
        final clipGain = (msg.payload['clipGain'] as num?)?.toDouble() ?? 1.0;
        final bgmGain = (msg.payload['bgmGain'] as num?)?.toDouble() ?? 0.3;
        playback.applyPreset(presetName, clipGain, bgmGain);
        notifier.sendTo(sender, WsMessage.ack(msg.reqId));
        break;

      default:
        notifier.sendTo(sender, WsMessage.ack(msg.reqId));
    }
  });

  // Live-sync: broadcast updated asset list whenever clips or tracks change
  ref.listen<List<Clip>>(clipListProvider, (previous, next) {
    if (notifier.state.connectedClients > 0) {
      debugPrint('Asset sync: clips changed, broadcasting to ${notifier.state.connectedClients} client(s)');
      final tracks = ref.read(trackListProvider);
      notifier.broadcast(_buildAssetListMessage(next, tracks));
    }
  });
  ref.listen<List<Track>>(trackListProvider, (previous, next) {
    if (notifier.state.connectedClients > 0) {
      debugPrint('Asset sync: tracks changed, broadcasting to ${notifier.state.connectedClients} client(s)');
      final clips = ref.read(clipListProvider);
      notifier.broadcast(_buildAssetListMessage(clips, next));
    }
  });

  return notifier;
});
