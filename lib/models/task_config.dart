/// Task Execution Configuration Model
/// Defines the boundary conditions, resource quotas, and permission restrictions
/// when an Agent executes a single task.
class TaskConfig {
  /// Unique identifier for the task (useful for log tracing and assigning isolated VFS workspaces)
  final String taskId;

  /// Maximum timeout duration for sandbox JS execution (prevents infinite loops from freezing the main thread)
  final Duration timeout;

  /// Maximum number of automatic Debug/Rewrite attempts allowed when the Agent encounters execution errors
  final int maxRetries;

  /// Whether the task is authorized to access the network
  /// (If false, the native-layer NetworkPlugin should intercept requests or remain un-injected)
  final bool requireNetwork;

  /// Whether the task is authorized to read/write the local Virtual File System (VFS)
  final bool requireStorage;

  TaskConfig({
    required this.taskId,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.requireNetwork = false,
    this.requireStorage = false,
  })  : assert(taskId.isNotEmpty, 'taskId cannot be empty'),
        assert(maxRetries >= 0, 'maxRetries cannot be negative'),
        assert(timeout.inSeconds > 0, 'timeout must be positive');

  /// Creates a copy of this [TaskConfig] but with the given fields replaced with the new values.
  TaskConfig copyWith({
    String? taskId,
    Duration? timeout,
    int? maxRetries,
    bool? requireNetwork,
    bool? requireStorage,
  }) {
    return TaskConfig(
      taskId: taskId ?? this.taskId,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      requireNetwork: requireNetwork ?? this.requireNetwork,
      requireStorage: requireStorage ?? this.requireStorage,
    );
  }

  /// Deserialization from JSON (e.g., receiving task configurations from a remote Cloud Control system)
  factory TaskConfig.fromJson(Map<String, dynamic> json) {
    return TaskConfig(
      taskId: json['taskId'] as String? ?? 'default_task_${DateTime.now().millisecondsSinceEpoch}',
      timeout: Duration(seconds: json['timeoutSeconds'] as int? ?? 30),
      maxRetries: json['maxRetries'] as int? ?? 3,
      requireNetwork: json['requireNetwork'] as bool? ?? false,
      requireStorage: json['requireStorage'] as bool? ?? false,
    );
  }

  /// Serialization to JSON
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