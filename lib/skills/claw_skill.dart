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

  /// JSON Schema 描述 — 可选，用于云端 LLM 的"原生 tool calling"通道
  /// (OpenAI tools / Anthropic tool_use / Gemini functions 等都吃 JSON Schema).
  ///
  /// 返回值是 **方法名 → 该方法的 parameters schema** 的 map.  每个 schema
  /// 必须是合法的 JSON Schema object (常见: `{"type":"object","properties":{...},"required":[...]}`).
  ///
  /// 不实现就返回 null → 这个 skill 只在 JS 沙箱通道可用,不会出现在 OpenAI
  /// 的 `tools` 数组里.  适合"仅 LLM 内部协议"的工具 (e.g. live2d 动作控制
  /// 这种太频繁的,不适合走 round-trip 多的 native 协议).
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Map<String, Map<String, dynamic>>? get nativeToolSchemas => {
  ///   'eval': {
  ///     'type': 'object',
  ///     'properties': {
  ///       'expression': {'type': 'string', 'description': 'Math expression e.g. "2+3*4"'},
  ///     },
  ///     'required': ['expression'],
  ///   },
  /// };
  /// ```
  Map<String, Map<String, dynamic>>? get nativeToolSchemas => null;

  /// 方法名 → 给云端 LLM 看的人话描述.  默认 fallback 到 [description] +
  /// 方法名;skill 可以 override 给每个方法一段更精准的解释.
  Map<String, String> get nativeMethodDescriptions => const {};
}
