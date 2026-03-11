import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_claw/utils/logger.dart';
import 'package:flutter_claw/bridge/bridge_registry.dart';

/// UI 交互插件 (GetX 专属版本)
class UIPlugin extends ClawBridgePlugin {
  // 无需传入任何 GlobalKey 或 Context！
  UIPlugin();

  @override
  String get namespace => 'ui';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'showToast': _showToast,
    'showDialog': _showDialog, // 顺手加个弹窗能力
  };

  /// JS 端调用: Claw.ui_showToast('我是一条提示')
  dynamic _showToast(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing message parameter"}';
    final message = args[0].toString();

    // 🌟 直接调用 Get.snackbar，不需要 context！
    Get.snackbar(
      '🤖 Agent 提示',
      message,
      snackPosition: SnackPosition.bottom,
      backgroundColor: Colors.deepPurpleAccent.withOpacity(0.9),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );

    Log.i('📱 [UIPlugin] Agent 触发了 Snackbar: $message');
    return '{"status": "success"}';
  }

  /// JS 端调用: Claw.ui_showDialog('警告', '电量不足')
  dynamic _showDialog(List<dynamic> args) {
    if (args.length < 2) return '{"error": "Missing parameters"}';
    final title = args[0].toString();
    final message = args[1].toString();

    // 🌟 直接调用 Get.defaultDialog 弹窗
    Get.defaultDialog(
      title: title,
      middleText: message,
      confirmTextColor: Colors.white,
      textConfirm: '知道了',
      onConfirm: () => Get.back(), // 关闭弹窗
    );

    return '{"status": "success"}';
  }
}