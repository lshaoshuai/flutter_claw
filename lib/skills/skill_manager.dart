import '../bridge/bridge_registry.dart';
import '../utils/logger.dart';
import 'claw_skill.dart';

class SkillManager {
  final List<ClawSkill> _skills = [];

  /// 注册技能
  void registerSkill(ClawSkill skill) {
    _skills.add(skill);
  }

  /// 将所有注册的技能挂载到 JS 沙盒中
  void mountToRegistry(BridgeRegistry registry) {
    for (var skill in _skills) {
      registry.registerPlugin(skill);
      Log.i('🛠️ [SkillManager] 已将技能 "${skill.skillName}" 挂载到沙盒中');
    }
  }

  /// 动态生成喂给大模型的“技能清单” Prompt
  String generateSkillPrompt() {
    if (_skills.isEmpty) return 'No external skills available.';

    StringBuffer buffer = StringBuffer();
    buffer.writeln('【Available Skills (Tools)】');
    buffer.writeln('You have access to the following skills. If a user request requires these capabilities, you MUST use the provided JS methods:');

    for (var skill in _skills) {
      buffer.write(skill.toPromptInstruction());
    }

    return buffer.toString();
  }
}