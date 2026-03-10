import '../sandbox/js_runtime.dart';

/// 桥接插件的基础抽象类
/// 任何想要暴露给 JS 沙盒的原生能力（如网络、存储、蓝牙），都必须继承此方法。
abstract class ClawBridgePlugin {
  /// 插件的命名空间，在 JS 中会作为前缀，例如 'network' -> Claw.network.xxx
  String get namespace;

  /// 该插件提供的所有方法映射
  /// Key: JS 端调用的方法名，Value: Dart 层的处理逻辑
  Map<String, dynamic Function(List<dynamic>)> get methods;
}

/// 核心的桥接注册表
/// 负责将多个 Plugin 中的方法统一注入到 QuickJS 引擎中
class BridgeRegistry {
  final ClawJSRuntime jsRuntime;

  BridgeRegistry(this.jsRuntime);

  /// 注册单个插件
  void registerPlugin(ClawBridgePlugin plugin) {
    plugin.methods.forEach((methodName, handler) {
      // 为了防止命名冲突，将 namespace 和 methodName 结合
      // 最终在 JS 里调用的形式如：Claw_network_get(...) 或直接 Claw.network_get(...)
      final fullMethodName = '${plugin.namespace}_$methodName';

      jsRuntime.registerBridgeMethod(fullMethodName, handler);
      print('🔗 注册桥接方法: Claw.$fullMethodName');
    });
  }

  /// 注册默认的系统级插件（如果在 TaskConfig 中被授权的话）
  void registerDefaultPlugins() {
    registerPlugin(NetworkPlugin());
    // TODO: 可以在这里继续注册 StoragePlugin, SystemPlugin 等
  }
}

// ============================================================================
// 下面是几个预置的核心 Plugin 示例
// ============================================================================

/// 网络请求插件示例
/// 允许 JS 沙盒发起 HTTP GET 请求抓取数据
class NetworkPlugin extends ClawBridgePlugin {
  @override
  String get namespace => 'network';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'get': _httpGet,
  };

  /// JS 端调用: Claw.network_get('https://api.example.com/data')
  dynamic _httpGet(List<dynamic> args) {
    if (args.isEmpty) {
      return '{"error": "Missing URL parameter"}';
    }

    final url = args[0].toString();
    print('🌐 [Bridge] JS 请求发起 HTTP GET: $url');

    // 注意：这里为了示例极简，没有使用 Dio 或 http 库发起真实的异步请求。
    // 在真实的 flutter_claw 实现中，您需要在这里发起真实的 HTTP 请求。
    // 由于 Dart 调用 JS 返回结果需要是同步的字符串 (或者通过另一条消息通道异步返回)，
    // 通常我们推荐这里仅仅是发起请求，并返回一个任务 ID，让 JS 去轮询或者等待回调。
    //
    // 对于简单的同步桥接演示，我们可以模拟返回一些死数据：
    return '{"status": 200, "data": "模拟的网络返回数据 from $url"}';
  }
}

/// 存储读取插件示例 (结合 VFS)
class StoragePlugin extends ClawBridgePlugin {
  // 假设注入了 vfsManager 实例
  // final VFSManager vfsManager;
  // StoragePlugin(this.vfsManager);

  @override
  String get namespace => 'vfs';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'read': _readFile,
  };

  /// JS 端调用: Claw.vfs_read('data.csv')
  dynamic _readFile(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing file path"}';
    final path = args[0].toString();
    print('📂 [Bridge] JS 请求读取文件: $path');

    // 真实实现中调用 vfsManager.readFile(path)
    return '模拟的文件内容，如 id,name\n1,Alice\n2,Bob';
  }
}