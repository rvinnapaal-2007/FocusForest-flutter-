import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'fullscreen_stub.dart' if (dart.library.js_interop) 'fullscreen_web.dart';

/// Keeps the user inside the app during a focus session.
/// - Web: browser goes fullscreen (tab strip / address bar hidden).
/// - Android: screen pinning (Home / Recents disabled).
class FocusLockService {
  static const _channel = MethodChannel('focus_forest/lock');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call from a user gesture. [onFullscreenExit] fires if the user leaves
  /// browser fullscreen (web only).
  static Future<void> lock({VoidCallback? onFullscreenExit}) async {
    if (kIsWeb) {
      if (onFullscreenExit != null) listenFullscreenExit(onFullscreenExit);
      enterBrowserFullscreen();
      return;
    }
    if (!_android) return;
    try {
      await _channel.invokeMethod('lock');
    } catch (_) {}
  }

  static Future<void> unlock() async {
    if (kIsWeb) {
      exitBrowserFullscreen();
      return;
    }
    if (!_android) return;
    try {
      await _channel.invokeMethod('unlock');
    } catch (_) {}
  }
}
