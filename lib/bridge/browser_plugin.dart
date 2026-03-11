import 'bridge_registry.dart';
import '../utils/logger.dart';

/// 浏览器与外部意图插件
/// 允许 Agent 唤起系统浏览器或其他 App
class BrowserPlugin extends ClawBridgePlugin {
  @override
  String get namespace => 'browser';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'openUrl': _openUrl,
  };

  // ============================================================================
  // 🌟 核心优化：插件自曝能力说明给大模型看
  // ============================================================================
  @override
  List<String> get jsSignatures => [
    'Claw.browser_openUrl(url: String) -> Returns JSON string {"status": "success"} // 用于在系统默认外部浏览器中打开指定的 URL 链接'
  ];

  /// JS 端调用: Claw.browser_openUrl('https://flutter.dev')
  dynamic _openUrl(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing URL parameter"}';
    final url = args[0].toString();

    Log.i('🌍 [BrowserPlugin] Agent 请求打开外部链接: $url');

    // 真实项目中建议引入 `url_launcher` 库:
    // final uri = Uri.parse(url);
    // if (await canLaunchUrl(uri)) {
    //   await launchUrl(uri, mode: LaunchMode.externalApplication);
    // }

    return '{"status": "success"}';
  }
}