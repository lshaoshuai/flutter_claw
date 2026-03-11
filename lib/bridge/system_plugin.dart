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

  // ============================================================================
  // 🌟 核心优化：赋予大模型对物理硬件的精确感知和控制说明
  // ============================================================================
  @override
  List<String> get jsSignatures => [
    'Claw.sys_vibrate(level: Number) -> Returns JSON string {"status": "success", "level": 1} // 触发手机物理震动反馈。level 取值 1 到 10，代表你的情绪激动程度。数字越大，震动越急促且次数越多（例如极度愤怒或极度兴奋时传 10）。',
    'Claw.sys_copyToClipboard(text: String) -> Returns JSON string {"status": "success"} // 默默将重要文本（如代码片段、提纲、链接等）复制到用户的手机剪贴板，方便用户直接粘贴使用。',
    'Claw.sys_getDeviceInfo() -> Returns JSON string // 获取当前系统运行环境的底层软硬件信息。'
  ];

  /// JS Side Call: Claw.sys_vibrate(5)
  /// Triggers a short device vibration
  dynamic _vibrate(List<dynamic> args) {
    try {
      int level = 1; // 默认兴奋度
      if (args.isNotEmpty) {
        level = int.tryParse(args[0].toString()) ?? 1;
      }

      // 限制在 1-10 之间，防止大模型乱传数字导致手机无限震动
      level = level.clamp(1, 10);

      Log.i('📳 [SystemPlugin] 触发震动，当前情绪激动度: $level');

      // 异步执行震动序列，不阻塞主线程
      _playVibrationPattern(level);

      return '{"status": "success", "level": $level}';
    } catch (e) {
      return '{"status": "error", "message": "Vibration failed: $e"}';
    }
  }

  /// 根据兴奋度动态计算震动频率和次数
  Future<void> _playVibrationPattern(int level) async {
    // 情绪越激动，震动次数越多 (1~10次)
    int count = level;

    // 情绪越激动，每次震动的间隔越短，显得越急促 (最高频间隔约 50ms，最低频约 320ms)
    int delayMs = 350 - (level * 30);
    if (delayMs < 50) delayMs = 50;

    for (int i = 0; i < count; i++) {
      // heavyImpact 震感比较明显，仿佛心跳或敲击
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