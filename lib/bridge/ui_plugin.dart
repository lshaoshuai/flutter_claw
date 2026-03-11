import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_claw/utils/logger.dart';
import 'package:flutter_claw/bridge/bridge_registry.dart';

/// UI 交互插件 (GetX 专属版本)
/// 允许 Agent 直接操控手机屏幕上的 UI 元素，实现“突破对话框”的交互体验。
class UIPlugin extends ClawBridgePlugin {
  // 无需传入任何 GlobalKey 或 Context！
  UIPlugin();

  @override
  String get namespace => 'ui';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'showToast': _showToast,
    'showDialog': _showDialog,
  };

  // ============================================================================
  // 🌟 核心优化：向大模型精确描述 UI 组件的使用场景，防止滥用
  // ============================================================================
  @override
  List<String> get jsSignatures => [
    'Claw.ui_showToast(message: String) -> Returns JSON string {"status": "success"} // 在屏幕底部弹出一个轻量级的短暂提示框 (Snackbar)。适用于非阻塞的轻微通知（如：“后台任务已完成”、“已复制到剪贴板”）。',
    'Claw.ui_showDialog(title: String, message: String) -> Returns JSON string {"status": "success"} // 在屏幕中央强制弹出一个模态对话框。仅在发生极其重要、必须打断用户操作的严重警告时使用（如：“系统即将崩溃”、“检测到非法入侵”）。不要滥用！'
  ];

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
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      confirmTextColor: Colors.white,
      buttonColor: Colors.deepPurpleAccent,
      textConfirm: '知道了',
      onConfirm: () => Get.back(), // 关闭弹窗
    );

    Log.i('📱 [UIPlugin] Agent 强制弹出了 Dialog: $title');
    return '{"status": "success"}';
  }
}