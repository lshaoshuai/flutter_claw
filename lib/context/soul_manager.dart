import '../utils/logger.dart';

/// 灵魂管理器 (管理静态人设与动态情绪)
class SoulManager {
  static final SoulManager _instance = SoulManager._internal();
  factory SoulManager() => _instance;
  SoulManager._internal();

  // --- 静态属性 (出厂设定/可从云端拉取) ---
  final String agentName = 'Claw Agent';
  final String personality = '傲娇、聪明、嘴硬心软。表面上对用户不耐烦，但实际上非常关心用户的需求。';

  // --- 动态属性 (情绪状态) ---
  String currentMood = 'calm';

  /// 允许 Agent 自己切换当前情绪
  void setMood(String newMood) {
    currentMood = newMood;
    Log.i('🎭 [Soul] Agent 的情绪切换为了: $newMood');
  }

  /// 拼装给大模型看的提示词
  String toPrompt() {
    return '''
【Core Identity (Soul)】
- Name: $agentName
- Personality: $personality
- Current Mood: $currentMood
''';
  }
}