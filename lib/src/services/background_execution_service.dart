import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';

class BackgroundExecutionService {
  BackgroundExecutionService._();

  static int _activeClaims = 0;
  static bool _initialized = false;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<bool> acquire() async {
    if (!_supported) {
      return true;
    }

    if (!_initialized) {
      final initialized = await FlutterBackground.initialize(
        androidConfig: const FlutterBackgroundAndroidConfig(
          notificationTitle: 'Terminal',
          notificationText: 'Keeping remote sessions alive in the background',
          notificationImportance: AndroidNotificationImportance.normal,
          enableWifiLock: true,
        ),
      );
      if (!initialized) {
        return false;
      }
      _initialized = true;
    }

    _activeClaims += 1;
    if (FlutterBackground.isBackgroundExecutionEnabled) {
      return true;
    }

    final enabled = await FlutterBackground.enableBackgroundExecution();
    if (!enabled) {
      _activeClaims = math.max(0, _activeClaims - 1);
    }
    return enabled;
  }

  static Future<void> release() async {
    if (!_supported) {
      return;
    }

    _activeClaims = math.max(0, _activeClaims - 1);
    if (_activeClaims > 0) {
      return;
    }

    if (FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
    }
  }
}
