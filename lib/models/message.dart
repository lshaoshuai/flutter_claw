/// 标准化对话消息模型
/// 用于在 Agent、用户和 LLM 之间传递上下文。
class Message {
  /// 角色：通常为 'system' (系统设定), 'user' (用户输入), 'assistant' (模型回复)
  final String role;

  /// 消息的具体内容
  final String content;

  Message({
    required this.role,
    required this.content,
  });

  /// 快速创建一个 System 消息 (用于注入人设和规则)
  factory Message.system(String content) {
    return Message(role: 'system', content: content);
  }

  /// 快速创建一个 User 消息 (用户的真实意图或报错反馈)
  factory Message.user(String content) {
    return Message(role: 'user', content: content);
  }

  /// 快速创建一个 Assistant 消息 (大模型的输出结果)
  factory Message.assistant(String content) {
    return Message(role: 'assistant', content: content);
  }

  /// 从 JSON 字典反序列化 (方便从本地缓存读取对话历史)
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
    );
  }

  /// 序列化为 JSON 字典 (方便传给 LLM 的 API 或存入本地数据库)
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }

  @override
  String toString() {
    // 截断过长的内容用于日志打印
    final shortContent = content.length > 50
        ? '${content.substring(0, 50)}...'
        : content;
    return 'Message(role: $role, content: $shortContent)';
  }
}