import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Publishes the small, display-only snapshot used by Android launcher widgets.
class LauncherWidgetService {
  static const _channel = MethodChannel('debt_manager/launcher_widgets');
  static const _isFlutterTest = bool.fromEnvironment('FLUTTER_TEST');

  static bool get _usesTestBinding => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  static Future<void> update(Map<String, Object?> snapshot) async {
    if (_isFlutterTest ||
        _usesTestBinding ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel
          .invokeMethod<void>('updateWidgets', snapshot)
          .timeout(const Duration(seconds: 1));
    } on MissingPluginException {
      // Widget support is unavailable in unit tests and older app installs.
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to update launcher widgets: $error');
      }
    } on TimeoutException {
      // A test host or partially upgraded install may not register the channel.
    }
  }
}
