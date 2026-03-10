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