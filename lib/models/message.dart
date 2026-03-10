/// Standardized Conversation Message Model
/// Used for passing context between the Agent, User, and LLM.
class Message {
  /// Role: Typically 'system' (persona/rule setting), 'user' (user input), or 'assistant' (model response).
  final String role;

  /// The actual content of the message.
  final String content;

  Message({
    required this.role,
    required this.content,
  });

  /// Quickly creates a System message (used for injecting personas and rules).
  factory Message.system(String content) {
    return Message(role: 'system', content: content);
  }

  /// Quickly creates a User message (represents true user intent or error feedback).
  factory Message.user(String content) {
    return Message(role: 'user', content: content);
  }

  /// Quickly creates an Assistant message (the output result from the LLM).
  factory Message.assistant(String content) {
    return Message(role: 'assistant', content: content);
  }

  /// Deserializes from a JSON map (useful for reading conversation history from local cache).
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
    );
  }

  /// Serializes to a JSON map (useful for LLM API calls or saving to a local database).
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }

  @override
  String toString() {
    // Truncate long content for cleaner log printing
    final shortContent = content.length > 50
        ? '${content.substring(0, 50)}...'
        : content;
    return 'Message(role: $role, content: $shortContent)';
  }
}