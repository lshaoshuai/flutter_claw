import '../bridge/bridge_registry.dart';

/// 技能基类 (Skill Base)
/// 继承自基础插件，不仅向 JS 沙盒暴露方法，还负责向 LLM 提供自身的说明书。
abstract class ClawSkill extends ClawBridgePlugin {
  @override
  String get namespace => 'skill'; // 统一使用 skill 作为命名空间，方便大模型记忆

  /// 技能的唯一名称 (例如: WeatherSkill)
  String get skillName;

  /// 技能的详细描述，告诉大模型这个技能是干什么用的
  String get description;

  /// JS 方法的签名及其返回值的说明 (极度重要，大模型靠这个写代码)
  /// 例如: `Claw.skill_getWeather(city: String) -> Returns JSON string {"temp": 25, "cond": "Sunny"}`
  String get jsSignature;

  /// 将技能转换为可以直接拼接进 System Prompt 的文本
  String toPromptInstruction() {
    return '''
- **Skill**: $skillName
  **Description**: $description
  **Usage**: `$jsSignature`
''';
  }
}
