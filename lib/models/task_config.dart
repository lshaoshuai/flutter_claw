/// 任务执行的配置模型
/// 用于定义 Agent 执行单次任务时的边界条件、资源配额和权限限制。
class TaskConfig {
  /// 任务的唯一标识符 (可用于日志追踪和分配独立的 VFS 工作区)
  final String taskId;

  /// 沙盒执行 JS 代码的最大超时时间 (防止死循环卡死主线程)
  final Duration timeout;

  /// Agent 遇到执行报错时，允许自动 Debug 重写代码的最大尝试次数
  final int maxRetries;

  /// 该任务是否被授权访问网络
  /// (如果为 false，原生层的 NetworkPlugin 应该直接拦截或不注入)
  final bool requireNetwork;

  /// 该任务是否被授权读写本地的虚拟文件系统 (VFS)
  final bool requireStorage;

  TaskConfig({
    required this.taskId,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.requireNetwork = false,
    this.requireStorage = false,
  });

  /// 从 JSON 反序列化 (例如：从远端云控系统下发任务配置)
  factory TaskConfig.fromJson(Map<String, dynamic> json) {
    return TaskConfig(
      taskId: json['taskId'] as String? ?? 'default_task_${DateTime.now().millisecondsSinceEpoch}',
      timeout: Duration(seconds: json['timeoutSeconds'] as int? ?? 30),
      maxRetries: json['maxRetries'] as int? ?? 3,
      requireNetwork: json['requireNetwork'] as bool? ?? false,
      requireStorage: json['requireStorage'] as bool? ?? false,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'timeoutSeconds': timeout.inSeconds,
      'maxRetries': maxRetries,
      'requireNetwork': requireNetwork,
      'requireStorage': requireStorage,
    };
  }

  @override
  String toString() {
    return 'TaskConfig(taskId: $taskId, timeout: ${timeout.inSeconds}s, retries: $maxRetries, network: $requireNetwork, storage: $requireStorage)';
  }
}