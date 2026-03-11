import 'package:flutter_claw/bridge/browser_plugin.dart';
import 'package:flutter_claw/bridge/tts_plugin.dart';
import 'package:flutter_claw/bridge/ui_plugin.dart';

import '../sandbox/js_runtime.dart';
import '../models/task_config.dart';
import '../utils/logger.dart';

/// Base abstract class for bridge plugins
/// Any native capability (e.g., Network, Storage, Bluetooth) intended to be
/// exposed to the JS sandbox must extend this class.
abstract class ClawBridgePlugin {
  /// The plugin's namespace, used as a prefix in JS, e.g., 'network' -> Claw.network.xxx
  String get namespace;

  /// A map of all methods provided by this plugin
  /// Key: Method name called from the JS side, Value: The handling logic in the Dart layer
  Map<String, dynamic Function(List<dynamic>)> get methods;

  // ============================================================================
  // 🌟 核心优化点 1：自描述能力
  // ============================================================================
  /// 向 LLM 暴露的 API 签名与功能说明。
  /// 默认返回空数组。如果你希望大模型知道并使用这个插件，请重写它。
  List<String> get jsSignatures => [];
}

/// Core Bridge Registry
/// Responsible for injecting methods from multiple plugins into the QuickJS engine
class BridgeRegistry {
  final ClawJSRuntime jsRuntime;

  // 🌟 核心优化点 2：缓存已注册的插件，用于后续一键生成 Prompt
  final List<ClawBridgePlugin> _registeredPlugins = [];

  BridgeRegistry(this.jsRuntime);

  /// Registers a single plugin
  void registerPlugin(ClawBridgePlugin plugin) {
    // 🌟 将插件加入缓存
    if (!_registeredPlugins.contains(plugin)) {
      _registeredPlugins.add(plugin);
    }

    plugin.methods.forEach((methodName, handler) {
      // Combines namespace and methodName to prevent naming conflicts.
      // Final JS call format: Claw.network_get(...) or directly Claw.network_get(...)
      final fullMethodName = '${plugin.namespace}_$methodName';
      jsRuntime.registerBridgeMethod(fullMethodName, handler);
    });
  }

  /// Registers default system-level plugins based on [TaskConfig] authorization
  void registerDefaultPlugins(TaskConfig config) {
    if (config.requireNetwork) registerPlugin(NetworkPlugin());
    if (config.requireStorage) registerPlugin(StoragePlugin());
    if (config.requireBrowser) registerPlugin(BrowserPlugin());
    if (config.requireTts) registerPlugin(TTSPlugin());
    if (config.requireUi) registerPlugin(UIPlugin());
    // Always register basic system info if needed
    // registerPlugin(SystemPlugin());
  }

  // ============================================================================
  // 🌟 核心优化点 3：自动生成 Native Capabilities 的 Prompt
  // ============================================================================
  /// 遍历所有已注册的插件，将其 jsSignatures 拼装成系统提示词
  String generatePluginPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('【Native Capabilities (Strict APIs)】');

    // 沙盒自带的必备系统级回调（所有任务都必须用它收尾）
    buffer.writeln('1. `Claw.finish(text: String)` // 必须调用此方法来结束执行并向用户返回最终文本');

    int index = 2;
    for (var plugin in _registeredPlugins) {
      // ⚠️ 特殊处理：跳过 namespace 为 'skill' 的插件
      // 因为 Skill 类（虽然继承自 Plugin）有更详细的 JSON Schema 和单独的 Prompt 生成器 (SkillManager)
      if (plugin.namespace == 'skill') continue;

      for (var sig in plugin.jsSignatures) {
        buffer.writeln('$index. `$sig`');
        index++;
      }
    }
    return buffer.toString();
  }
}

// ============================================================================
// Examples of pre-set Core Plugins below (加入了 jsSignatures 示例)
// ============================================================================

/// Network Request Plugin Example
/// Allows the JS sandbox to initiate HTTP GET requests to fetch data
class NetworkPlugin extends ClawBridgePlugin {
  @override
  String get namespace => 'network';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {'get': _httpGet};

  // 🌟 插件自曝能力说明给大模型看
  @override
  List<String> get jsSignatures => [
    'Claw.network_get(url: String) -> Returns JSON string {"status": 200, "data": "..."} // 用于发起网络 HTTP GET 请求'
  ];

  /// JS Side Call: Claw.network_get('https://api.example.com/data')
  dynamic _httpGet(List<dynamic> args) {
    if (args.isEmpty) {
      return '{"error": "Missing URL parameter"}';
    }

    final url = args[0].toString();
    Log.i('🌐 [Bridge] JS initiating HTTP GET request: $url');

    return '{"status": 200, "data": "Mock network response data from $url"}';
  }
}

/// Storage/Read Plugin Example (integrated with VFS)
class StoragePlugin extends ClawBridgePlugin {
  @override
  String get namespace => 'vfs';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'read': _readFile,
  };

  // 🌟 插件自曝能力说明给大模型看
  @override
  List<String> get jsSignatures => [
    'Claw.vfs_read(path: String) -> Returns String // 读取沙盒虚拟文件系统中的文件内容'
  ];

  /// JS Side Call: Claw.vfs_read('data.csv')
  dynamic _readFile(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing file path"}';
    final path = args[0].toString();
    Log.i('📂 [Bridge] JS requesting to read file: $path');

    return 'Mock file content, e.g., id,name\n1,Alice\n2,Bob';
  }
}