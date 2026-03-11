import '../context/soul_manager.dart';
import 'claw_skill.dart';

class SoulSkill extends ClawSkill {
  @override
  String get skillName => 'SoulControl';

  @override
  String get description =>
      '用于控制你自身的情绪状态。当对话氛围发生变化时，你可以主动切换你的情绪。';

  @override
  String get jsSignature =>
      'Claw.skill_setMood(moodString) // 参数: "happy", "angry", "shy", "calm" 等';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'setMood': _setMood,
  };

  dynamic _setMood(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing mood"}';
    SoulManager().setMood(args[0].toString());
    return '{"status": "success"}';
  }
}