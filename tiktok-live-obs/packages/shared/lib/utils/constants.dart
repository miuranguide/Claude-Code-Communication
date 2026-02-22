/// Queue behavior when a clip command arrives during playback
enum QueueMode { ignore, queue }

/// Fit mode for video overlay
enum FitMode { contain, cover }

class AppConstants {
  static const String appVersion = '1.3.0';
  static const int buildNumber = 20260223;
  static const String versionDisplay = 'v$appVersion (build $buildNumber)';

  static const int maxClips = 10;
  static const int maxTracks = 20;
  static const int defaultCooldownMs = 3000;
  static const int wsPort = 9876;

  // 9:16 virtual canvas
  static const double canvasAspect = 9.0 / 16.0;
  static const double canvasWidth = 900.0;
  static const double canvasHeight = 1600.0;

  // Layout defaults
  static const double defaultScale = 0.7;
  static const double minScale = 0.1;
  static const double maxScale = 2.0;

  // Safe area (avoid TikTok UI)
  static const double safeTop = 0.08;
  static const double safeBottom = 0.12;
  static const double safeLeft = 0.03;
  static const double safeRight = 0.03;

  // WebSocket heartbeat
  static const int wsPingIntervalSec = 15;
  static const int wsTimeoutSec = 30;

  // Reconnection
  static const int maxReconnectAttempts = 10;

  // Device limits per user
  static const int maxControllerDevices = 1;
  static const int maxDisplayDevices = 1;

  // Button sizes
  static const double buttonSizeLarge = 1.0;
  static const double buttonSizeMedium = 0.7;
  static const double buttonSizeSmall = 0.5;
}

/// Button size mode for music controls
enum ButtonSizeMode { large, medium, small }

String buttonSizeModeLabel(ButtonSizeMode mode) {
  switch (mode) {
    case ButtonSizeMode.large:
      return '大';
    case ButtonSizeMode.medium:
      return '中';
    case ButtonSizeMode.small:
      return '小';
  }
}
