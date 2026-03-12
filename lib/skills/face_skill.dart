import 'dart:convert';
import 'package:flutter_claw/events/event_bus.dart';
import 'claw_skill.dart';

class FaceSkill extends ClawSkill {
  @override
  String get skillName => 'FaceControl';

  @override
  String get namespace => 'skill'; // 显式声明命名空间，确保生成 Claw.skill_setFace

  @override
  String get description =>
      '用于极其细腻地控制你自己的面部表情参数。通过调整眼睛的宽、高、倾斜角和颜色来表达情绪。'
      '正倾斜角(如 0.3)显得生气犀利，负倾斜角(如 -0.3)显得悲伤无辜。';

  @override
  String get jsSignature =>
      'Claw.skill_setFace(jsonString) \n'
      '// 示例: Claw.skill_setFace(\'{"width":40,"height":10,"radius":5,"tilt":0.3,"color":"#FF3333","spacing":30}\')';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'setFace': _setFace,
  };

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
          // 默认青色
          mouthSmile: (config['smile'] ?? 0.0).toDouble(),
        ),
      );
      return '{"status": "success"}';
    } catch (e) {
      return '{"error": "Invalid JSON format: $e"}';
    }
  }
}
