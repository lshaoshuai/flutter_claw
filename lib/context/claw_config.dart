class ClawConfig {
  // 单例模式，保证全局统一
  static final ClawConfig _instance = ClawConfig._internal();
  factory ClawConfig() => _instance;
  ClawConfig._internal();

  // 用于存储各类 API Keys 和动态配置
  final Map<String, String> _apiKeys = {};

  /// 宿主 App 调用此方法注入 Key
  void setApiKey(String serviceName, String key) {
    _apiKeys[serviceName] = key;
  }

  /// Skill 运行时调用此方法获取 Key
  String? getApiKey(String serviceName) {
    return _apiKeys[serviceName];
  }

  /// 清除某项配置 (比如用户在 UI 里点击了“解除绑定”)
  void clearApiKey(String serviceName) {
    _apiKeys.remove(serviceName);
  }
}