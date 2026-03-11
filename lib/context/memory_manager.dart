import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// 记忆管理器 (具备本地磁盘持久化能力)
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  // 定义存储的 Keys
  static const String _keyIntimacy = 'agent_intimacy_level';
  static const String _keyFacts = 'agent_long_term_facts';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // --- 动态交互数据 ---
  int intimacyLevel = 0;
  List<String> _facts = [];

  /// 🌟 新增：初始化并从磁盘加载记忆 (必须在系统启动时调用)
  Future<void> init() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();

    // 从磁盘读取亲密度，如果没有存过则默认为 0
    intimacyLevel = _prefs.getInt(_keyIntimacy) ?? 0;

    // 从磁盘读取长期事实，如果没有存过则默认为空列表
    _facts = _prefs.getStringList(_keyFacts) ?? [];

    _isInitialized = true;
    Log.i('💾 [Memory] 磁盘记忆加载完成! 当前亲密度: $intimacyLevel, 记忆数量: ${_facts.length}');
  }

  /// 写入新记忆并固化到磁盘
  Future<void> rememberFact(String fact) async {
    if (!_facts.contains(fact)) {
      _facts.add(fact);
      await _prefs.setStringList(_keyFacts, _facts); // 🌟 存入硬盘
      Log.i('🧠 [Memory] 写入并持久化新记忆: $fact');
    }
  }

  /// 抹除相关记忆并同步硬盘
  Future<void> forgetFact(String factKeyword) async {
    final initialLength = _facts.length;
    _facts.removeWhere((e) => e.contains(factKeyword));

    if (_facts.length < initialLength) {
      await _prefs.setStringList(_keyFacts, _facts); // 🌟 存入硬盘
      Log.i('🗑️ [Memory] 抹除并持久化相关记忆: $factKeyword');
    }
  }

  /// 改变亲密度并固化到磁盘
  Future<void> changeIntimacy(int delta) async {
    intimacyLevel = (intimacyLevel + delta).clamp(0, 100);
    await _prefs.setInt(_keyIntimacy, intimacyLevel); // 🌟 存入硬盘
    Log.i('💖 [Memory] 亲密度变化: $delta, 当前: $intimacyLevel (已保存)');
  }

  /// 拼装给大模型看的提示词 (保持不变)
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