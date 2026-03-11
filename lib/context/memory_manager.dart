import '../utils/logger.dart';

/// 记忆管理器 (管理长期事实与关系羁绊)
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  // --- 动态交互数据 (需持久化到本地数据库) ---
  int intimacyLevel = 0; // 亲密度
  final List<String> _facts = []; // 长期事实记忆

  void rememberFact(String fact) {
    if (!_facts.contains(fact)) {
      _facts.add(fact);
      Log.i('🧠 [Memory] 写入新记忆: $fact');
    }
  }

  void forgetFact(String factKeyword) {
    _facts.removeWhere((e) => e.contains(factKeyword));
    Log.i('🗑️ [Memory] 抹除相关记忆: $factKeyword');
  }

  void changeIntimacy(int delta) {
    intimacyLevel = (intimacyLevel + delta).clamp(0, 100);
    Log.i('💖 [Memory] 亲密度变化: $delta, 当前: $intimacyLevel');
  }

  /// 拼装给大模型看的提示词
  String toPrompt() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('【Long-Term Memory】');
    buffer.writeln('- Intimacy Level with User: $intimacyLevel/100');

    if (_facts.isEmpty) {
      buffer.writeln('- Facts: No specific memories yet.');
    } else {
      for (var fact in _facts) {
        buffer.writeln('- Fact: $fact');
      }
    }
    return buffer.toString();
  }
}