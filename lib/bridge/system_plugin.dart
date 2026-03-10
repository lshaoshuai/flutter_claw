import 'dart:convert';
import 'package:flutter/services.dart';
import 'bridge_registry.dart';

/// 系统能力插件
/// 允许 JS 沙盒调用原生的系统级交互，如震动、剪贴板等。
class SystemPlugin extends ClawBridgePlugin {
  @override
  String get namespace => 'sys';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'vibrate': _vibrate,
    'copyToClipboard': _copyToClipboard,
    'getDeviceInfo': _getDeviceInfo,
  };

  /// JS 端调用: Claw.sys_vibrate()
  /// 触发设备短暂震动
  dynamic _vibrate(List<dynamic> args) {
    try {
      HapticFeedback.vibrate();
      return '{"status": "success"}';
    } catch (e) {
      return '{"status": "error", "message": "Vibration not supported or failed: $e"}';
    }
  }

  /// JS 端调用: Claw.sys_copyToClipboard('Hello World')
  dynamic _copyToClipboard(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing text parameter"}';
    final text = args[0].toString();

    // 注意：剪贴板操作在 Flutter 中是异步的，但通常非常快。
    // 为了简单起见，这里采用即发即忘(Fire-and-forget)模式，不等待结果。
    Clipboard.setData(ClipboardData(text: text));
    print('📋 [SystemPlugin] JS 已将内容复制到剪贴板');
    return '{"status": "success"}';
  }

  /// JS 端调用: const info = Claw.sys_getDeviceInfo()
  /// 返回简单的设备标识，可用于运营打点
  dynamic _getDeviceInfo(List<dynamic> args) {
    // 真实应用中，可以使用 device_info_plus 插件获取真实的手机型号
    // 这里做个简单的占位模拟
    final info = {
      'os': 'Android/iOS (Simulated)',
      'version': '1.0.0',
      'agent_os_version': '0.1.0-alpha',
    };
    return jsonEncode(info);
  }
}