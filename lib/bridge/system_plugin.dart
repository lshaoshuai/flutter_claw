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
      int level = 1; // 默认兴奋度
      if (args.isNotEmpty) {
        level = int.tryParse(args[0].toString()) ?? 1;
      }

      // 限制在 1-10 之间，防止大模型乱传数字导致手机无限震动
      level = level.clamp(1, 10);

      print('📳 [SystemPlugin] 触发震动，当前兴奋度: $level');

      // 异步执行震动序列，不阻塞主线程
      _playVibrationPattern(level);

      return '{"status": "success", "level": $level}';
    } catch (e) {
      return '{"status": "error", "message": "Vibration failed: $e"}';
    }
  }

  /// 根据兴奋度动态计算震动频率和次数
  Future<void> _playVibrationPattern(int level) async {
    // 兴奋度越高，震动次数越多 (1~10次)
    int count = level;

    // 兴奋度越高，每次震动的间隔越短，显得越急促 (最高频间隔约 50ms，最低频约 300ms)
    int delayMs = 350 - (level * 30);
    if (delayMs < 50) delayMs = 50;

    for (int i = 0; i < count; i++) {
      // heavyImpact 震感比较明显
      HapticFeedback.heavyImpact();
      await Future.delayed(Duration(milliseconds: delayMs));
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
