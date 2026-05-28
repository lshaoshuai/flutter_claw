import 'dart:convert';

import '../bridge/bridge_registry.dart';
import '../utils/logger.dart';
import 'claw_skill.dart';

/// Output format for [SkillManager.toNativeTools].
///
/// OpenAI / DeepSeek / Moonshot / Anthropic-OpenAI-compat all eat the
/// `{"type":"function","function":{...}}` envelope.  Anthropic's native API
/// uses a flatter shape.  Gemini uses `{"functionDeclarations":[...]}` which
/// is also derivable from the same schema.
enum NativeToolFormat { openai, anthropic }

class SkillManager {
  final List<ClawSkill> _skills = [];

  List<ClawSkill> get skills => List.unmodifiable(_skills);

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

  /// 动态生成喂给大模型的"技能清单" Prompt
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

  // ────────────────────── Native tool_calls channel ──────────────────────

  /// Collect every skill method that declares a [ClawSkill.nativeToolSchemas]
  /// entry and emit them as a `tools` array ready to send alongside the
  /// chat completion request.
  ///
  /// Naming convention is `skill_<skillName>_<methodName>` — lowercased,
  /// non-alphanumeric collapsed to `_`.  Stable + deterministic so the
  /// caller can round-trip tool_call names back to (skill, method) without
  /// extra state.
  List<Map<String, dynamic>> toNativeTools({
    NativeToolFormat format = NativeToolFormat.openai,
  }) {
    final out = <Map<String, dynamic>>[];
    for (final skill in _skills) {
      final schemas = skill.nativeToolSchemas;
      if (schemas == null || schemas.isEmpty) continue;
      schemas.forEach((method, schema) {
        final name = nativeToolName(skill, method);
        final description = skill.nativeMethodDescriptions[method] ??
            '${skill.description} (method: $method)';
        switch (format) {
          case NativeToolFormat.openai:
            out.add({
              'type': 'function',
              'function': {
                'name': name,
                'description': description,
                'parameters': schema,
              },
            });
            break;
          case NativeToolFormat.anthropic:
            out.add({
              'name': name,
              'description': description,
              'input_schema': schema,
            });
            break;
        }
      });
    }
    return out;
  }

  /// Resolve a tool name (as emitted by [toNativeTools]) back to (skill,
  /// method) and invoke it with the given arguments map.  Returns the JSON
  /// string result the skill produced — caller hands this to the LLM as
  /// the `tool` role response.
  ///
  /// Throws [StateError] when the tool name doesn't resolve.  Skill-level
  /// failures (validation, network, etc.) propagate as the JSON the skill
  /// chose to return (typically `{"error":"…"}`); we don't wrap them.
  Future<String> invokeTool(String toolName, Map<String, dynamic> args) async {
    for (final skill in _skills) {
      final schemas = skill.nativeToolSchemas;
      if (schemas == null) continue;
      for (final method in schemas.keys) {
        if (nativeToolName(skill, method) != toolName) continue;
        final handler = skill.methods[method];
        if (handler == null) {
          throw StateError(
            'Tool $toolName found, but skill "${skill.skillName}" has no '
            'method "$method" in its methods map',
          );
        }
        // ClawSkill methods take a positional List<dynamic>.  We pass the
        // args map JSON-encoded as a single positional — matches the
        // existing convention of `Claw.skill_xxx(JSON.stringify({...}))`.
        final result = await Future.sync(() => handler([jsonEncode(args)]));
        return result == null ? '{}' : result.toString();
      }
    }
    throw StateError('Unknown tool: $toolName');
  }

  /// Sanitize a (skill, method) pair into the OpenAI-allowed tool-name
  /// charset (`[a-zA-Z0-9_-]{1,64}`).  Lowercased so the model sees a
  /// consistent style.
  static String nativeToolName(ClawSkill skill, String method) {
    final raw = 'skill_${skill.skillName}_$method';
    final sanitized = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    return sanitized.length > 64 ? sanitized.substring(0, 64) : sanitized;
  }
}