import 'package:flutter/material.dart';
import 'package:flutter_claw/utils/logger.dart';
import 'package:flutter_claw/bridge/bridge_registry.dart';

class ClawUI {
  static GlobalKey<NavigatorState>? navigatorKey;
  static GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
}

/// UI 交互插件 (原生 Flutter 纯净版)
class UIPlugin extends ClawBridgePlugin {
  UIPlugin();

  @override
  String get namespace => 'ui';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'showToast': _showToast,
    'showDialog': _showDialog,
  };

  @override
  List<String> get jsSignatures => [
    'Claw.ui_showToast(message: String) -> Returns JSON string {"status": "success"} // 在屏幕底部弹出一个轻量级的短暂提示框 (Snackbar)。适用于非阻塞的轻微通知。',
    'Claw.ui_showDialog(title: String, message: String) -> Returns JSON string {"status": "success"} // 在屏幕中央强制弹出一个模态对话框。仅在发生极其重要、必须打断用户操作的严重警告时使用。不要滥用！'
  ];

  /// JS 端调用: Claw.ui_showToast('我是一条提示')
  dynamic _showToast(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing message parameter"}';
    final message = args[0].toString();

    final messenger = ClawUI.scaffoldMessengerKey?.currentState;
    if (messenger == null) {
      Log.e('❌ [UIPlugin] 无法显示 Toast：宿主 App 未注入 scaffoldMessengerKey');
      return '{"error": "UI keys not configured"}';
    }

    // 🌟 使用原生 ScaffoldMessenger
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.deepPurpleAccent.withOpacity(0.9),
        duration: const Duration(seconds: 2),
      ),
    );

    Log.i('📱 [UIPlugin] Agent 触发了原生 Snackbar: $message');
    return '{"status": "success"}';
  }

  /// JS 端调用: Claw.ui_showDialog('警告', '电量不足')
  dynamic _showDialog(List<dynamic> args) {
    if (args.length < 2) return '{"error": "Missing parameters"}';
    final title = args[0].toString();
    final message = args[1].toString();

    final context = ClawUI.navigatorKey?.currentContext;
    if (context == null) {
      Log.e('❌ [UIPlugin] 无法显示 Dialog：宿主 App 未注入 navigatorKey 或界面尚未渲染');
      return '{"error": "UI keys not configured"}';
    }

    // 🌟 使用原生 showDialog
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.deepPurpleAccent),
              onPressed: () => Navigator.of(ctx).pop(), // 关闭弹窗
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );

    Log.i('📱 [UIPlugin] Agent 强制弹出了原生 Dialog: $title');
    return '{"status": "success"}';
  }
}