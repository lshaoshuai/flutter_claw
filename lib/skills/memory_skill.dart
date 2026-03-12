import '../context/memory_manager.dart';
import 'claw_skill.dart';

class MemorySkill extends ClawSkill {
  @override
  String get skillName => 'MemoryControl';

  @override
  String get namespace => 'skill'; // 显式声明命名空间

  @override
  String get description =>
      '用于管理长期记忆和亲密度。当用户告诉你重要个人信息时必须调用 remember。当用户夸奖你时，调用 changeIntimacy 增加好感。';

  @override
  String get jsSignature =>
      'Claw.skill_remember(factString) // 记录事实\n'
          'Claw.skill_forget(factKeyword) // 遗忘事实\n'
          'Claw.skill_changeIntimacy(deltaNumber) // 改变亲密度(如 2 或 -1)';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'remember': _remember,
    'forget': _forget,
    'changeIntimacy': _changeIntimacy,
  };

  dynamic _remember(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing fact"}';
    MemoryManager().rememberFact(args[0].toString());
    return '{"status": "success"}';
  }

  dynamic _forget(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing keyword"}';
    MemoryManager().forgetFact(args[0].toString());
    return '{"status": "success"}';
  }

  dynamic _changeIntimacy(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing delta"}';
    final delta = int.tryParse(args[0].toString()) ?? 1;
    MemoryManager().changeIntimacy(delta);
    return '{"status": "success"}';
  }
}