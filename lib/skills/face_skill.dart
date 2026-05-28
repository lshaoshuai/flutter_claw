import 'dart:convert';

import 'package:flutter_claw/events/event_bus.dart';
import 'package:flutter_claw/models/emotion_params.dart';

import 'claw_skill.dart';

/// Face / mood control skill.
///
/// Two APIs exposed to the LLM:
///
/// * `Claw.skill_setEmotion(json)` — **preferred**.  Continuous parameter
///   protocol; supports both semantic (`emotion`+`intensity`+`secondary`)
///   and raw-params (`params`) modes.  Renderer tweens between calls so
///   the face animates organically.
///
/// * `Claw.skill_setFace(json)` — legacy direct-geometry call.  Kept for
///   back-compat with older system prompts; routes to the deprecated
///   [FaceExpressionEvent] path.
class FaceSkill extends ClawSkill {
  FaceSkill({this.agentId});

  /// 哪个 agent 的脸。null = 全局/默认。
  final String? agentId;

  @override
  String get skillName => 'FaceControl';

  @override
  String get namespace => 'skill';

  @override
  String get description =>
      '用一组连续的情绪参数精细控制你自己的表情。可以选 happy/sad/angry/'
      'surprised/shy/thinking/sleeping/love/wink/bored/excited/confused/'
      'fear/calm 中任意一个语义标签 + 强度，也可以直接给底层参数（眼睛开合、'
      '眉毛角度、嘴弧、脸颊红晕、身体色相、颤抖等）。可以叠加 secondary 实现'
      '"有点开心但又有些困惑" 之类的复合情绪。';

  @override
  String get jsSignature =>
      'Claw.skill_setEmotion(jsonString)  // 推荐\n'
      '// 语义模式 (大多数情况用这个):\n'
      '//   { "emotion": "angry", "intensity": 0.85, "secondary": "sad", "secondaryWeight": 0.2 }\n'
      '// 可用 emotion: happy / sad / angry / surprised / shy / thinking /\n'
      '//                sleeping / love / wink / bored / excited / confused / fear / calm\n'
      '// 直接参数模式 (高级):\n'
      '//   { "params": { "eyeOpen": 0.3, "browAngle": -0.8, "mouthCurve": -0.6,\n'
      '//                  "mouthOpen": 0.4, "cheekFlush": 0.5, "bodyHueShift": 0.9,\n'
      '//                  "tremor": 0.4, "pupilX": 0.3, "pupilY": -0.2 } }\n'
      '// 参数全部 -1..+1（少数 0..1+）。\n'
      'Claw.skill_setFace(jsonString)  // 旧 API，向后兼容';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
        'setEmotion': _setEmotion,
        'setFace': _setFace,
      };

  // ————— new continuous emotion path —————

  dynamic _setEmotion(List<dynamic> args) {
    if (args.isEmpty) return '{"error":"Missing JSON"}';
    try {
      // AI sometimes passes a JSON string ('{"emotion":"happy"}'), other
      // times a JS object literal — accept both.
      final raw = args[0];
      dynamic json;
      if (raw is String) {
        json = jsonDecode(raw);
      } else if (raw is Map) {
        json = raw;
      } else {
        json = jsonDecode(raw.toString());
      }
      final params = EmotionParams.fromJson(json);
      final label = (json is Map) ? json['emotion']?.toString() : null;
      EventBus().fire(EmotionStateEvent(
        params,
        semanticLabel: label,
        agentId: agentId,
      ));
      return '{"status":"success"}';
    } catch (e) {
      return '{"error":"Invalid JSON: $e"}';
    }
  }

  // ————— legacy geometry path (FaceExpressionEvent) —————

  dynamic _setFace(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing JSON"}';
    try {
      final config = jsonDecode(args[0].toString());

      EventBus().fire(
        FaceExpressionEvent(
          eyeWidth: (config['width'] ?? 30).toDouble(),
          eyeHeight: (config['height'] ?? 40).toDouble(),
          eyeRadius: (config['radius'] ?? 15).toDouble(),
          tiltAngle: (config['tilt'] ?? 0.0).toDouble(),
          spacing: (config['spacing'] ?? 40).toDouble(),
          colorHex: config['color']?.toString() ?? '#00FFFF',
          mouthSmile: (config['smile'] ?? 0.0).toDouble(),
          agentId: agentId,
        ),
      );
      return '{"status": "success"}';
    } catch (e) {
      return '{"error": "Invalid JSON format: $e"}';
    }
  }
}
