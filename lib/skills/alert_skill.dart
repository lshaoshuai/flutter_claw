import 'dart:convert';

import '../events/event_bus.dart';
import 'claw_skill.dart';

/// 🚨 Self-driven UI hijack — lets the AI break out of the normal chat
/// flow and force a high-priority popup onto the user's screen.  Use for
/// genuinely time-sensitive moments only (stock alert, schedule reminder
/// about to lapse, security event) — not for daily small talk.
///
/// Fires an [AlertEvent] into the EventBus; the host app must register a
/// listener (e.g. AlertOverlayService) that renders the actual UI.
class AlertSkill extends ClawSkill {
  AlertSkill({this.agentId});

  final String? agentId;

  @override
  String get skillName => 'AlertUser';

  @override
  String get namespace => 'skill';

  @override
  String get description =>
      '🚨 当事情真的紧急或重要时（关注的股突然跳水、日程即将逾期、监测到异常信号），'
      '可以打破"对话气泡"的常规流程，直接霸屏弹出一块高优先级提示卡片。'
      '请极克制使用——日常聊天/普通信息不要用这个。';

  @override
  String get jsSignature =>
      'Claw.skill_alertUser(jsonString)\n'
      '// 必填: title\n'
      '// 选填: message, level("info"|"warning"|"urgent"), color("#RRGGBB"),\n'
      '//      durationMs (0=要用户手动关闭), flash(true=屏闪), haptic\n'
      '// 例: Claw.skill_alertUser(JSON.stringify({\n'
      '//   level: "urgent",\n'
      '//   title: "🔥 茅台跌停",\n'
      '//   message: "刚刚跌至 1620，已触发你设的预警线 1650",\n'
      '//   color: "#E53935", flash: true, haptic: "heavy",\n'
      '//   durationMs: 0\n'
      '// }));\n'
      '// 何时用: 1) 用户明确设了预警 2) 突发风险 3) 时间敏感的提醒\n'
      '//        4) 严重错误 5) 安全/隐私事件';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
        'alertUser': _alertUser,
      };

  dynamic _alertUser(List<dynamic> args) {
    if (args.isEmpty) return '{"error":"need json"}';
    try {
      final raw = args[0];
      final json = raw is String ? jsonDecode(raw) : raw;
      if (json is! Map) return '{"error":"expected object"}';
      final m = Map<String, Object?>.from(json);

      final title = m['title']?.toString();
      if (title == null || title.isEmpty) {
        return '{"error":"title is required"}';
      }
      final level = (m['level']?.toString() ?? 'info').toLowerCase();
      final allowedLevels = {'info', 'warning', 'urgent'};
      if (!allowedLevels.contains(level)) {
        return '{"error":"level must be info|warning|urgent"}';
      }

      EventBus().fire(AlertEvent(
        title: title,
        message: m['message']?.toString(),
        level: level,
        color: m['color']?.toString(),
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 4000,
        flash: m['flash'] as bool? ?? (level == 'urgent'),
        haptic: m['haptic']?.toString() ??
            (level == 'urgent'
                ? 'heavy'
                : level == 'warning'
                    ? 'medium'
                    : 'light'),
        agentId: agentId,
      ));

      return '{"status":"ok"}';
    } catch (e) {
      return '{"error":"invalid alert spec: $e"}';
    }
  }
}
