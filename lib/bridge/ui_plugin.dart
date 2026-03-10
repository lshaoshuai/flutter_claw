import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'bridge_registry.dart';

/// UI 交互插件
/// 允许沙盒环境触发原生的视觉反馈，如 Toast 或 Snackbar
class UIPlugin extends ClawBridgePlugin {
  // 传入全局的 ScaffoldMessengerKey 以便在任何地方弹出提示
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  UIPlugin(this.scaffoldMessengerKey);

  @override
  String get namespace => 'ui';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'showToast': _showToast,
  };

  /// JS 端调用: Claw.ui_showToast('我是一条提示信息')
  dynamic _showToast(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing message parameter"}';
    final message = args[0].toString();

    // 必须在主线程(UI线程)执行
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Log.i('📱 [UIPlugin] Agent 触发了屏幕提示: $message');
    return '{"status": "success"}';
  }
}