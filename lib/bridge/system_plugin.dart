import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/logger.dart';
import 'bridge_registry.dart';

/// System Capabilities Plugin
/// Allows the JS sandbox to invoke native system-level interactions, such as vibration, clipboard access, etc.
class SystemPlugin extends ClawBridgePlugin {
  @override
  String get namespace => 'sys';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'vibrate': _vibrate,
    'copyToClipboard': _copyToClipboard,
    'getDeviceInfo': _getDeviceInfo,
  };

  /// JS Side Call: Claw.sys_vibrate()
  /// Triggers a short device vibration
  dynamic _vibrate(List<dynamic> args) {
    try {
      HapticFeedback.vibrate();
      return '{"status": "success"}';
    } catch (e) {
      return '{"status": "error", "message": "Vibration not supported or failed: $e"}';
    }
  }

  /// JS Side Call: Claw.sys_copyToClipboard('Hello World')
  dynamic _copyToClipboard(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing text parameter"}';
    final text = args[0].toString();

    // Note: Clipboard operations in Flutter are asynchronous, but usually very fast.
    // For simplicity, we use a "fire-and-forget" pattern here without awaiting the result.
    Clipboard.setData(ClipboardData(text: text));
    Log.i('📋 [SystemPlugin] JS has copied content to the clipboard');
    return '{"status": "success"}';
  }

  /// JS Side Call: const info = Claw.sys_getDeviceInfo()
  /// Returns a simple device identifier, useful for operational tracking/analytics.
  dynamic _getDeviceInfo(List<dynamic> args) {
    // In a real-world application, use the 'device_info_plus' plugin to get actual phone models.
    // This is a simple placeholder simulation.
    final info = {
      'os': 'Android/iOS (Simulated)',
      'version': '1.0.0',
      'agent_os_version': '0.1.0-alpha',
    };
    return jsonEncode(info);
  }
}
