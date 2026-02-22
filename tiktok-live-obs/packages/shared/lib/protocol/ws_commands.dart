/// WebSocket command type constants
class WsCmd {
  static const pair = 'PAIR';
  static const playClip = 'PLAY_CLIP';
  static const stopClip = 'STOP_CLIP';
  static const playBgm = 'PLAY_BGM';
  static const stopBgm = 'STOP_BGM';
  static const setMix = 'SET_MIX';
  static const ack = 'ACK';

  // Heartbeat
  static const ping = 'PING';
  static const pong = 'PONG';

  // Broadcaster → Remote sync
  static const syncState = 'SYNC_STATE';
  static const clipStarted = 'CLIP_STARTED';
  static const clipEnded = 'CLIP_ENDED';
  static const bgmStarted = 'BGM_STARTED';
  static const bgmStopped = 'BGM_STOPPED';
  static const assetList = 'ASSET_LIST';
}

/// ACK error codes
class WsError {
  static const clipNotFound = 'CLIP_NOT_FOUND';
  static const trackNotFound = 'TRACK_NOT_FOUND';
  static const presetNotFound = 'PRESET_NOT_FOUND';
  static const cooldownActive = 'COOLDOWN_ACTIVE';
  static const invalidToken = 'INVALID_TOKEN';
}
