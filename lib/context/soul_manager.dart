import '../events/event_bus.dart';
import '../utils/logger.dart';

/// 灵魂管理器 (管理静态人设与动态情绪)
class SoulManager {
  static final SoulManager _instance = SoulManager._internal();

  factory SoulManager() => _instance;

  SoulManager._internal();

  final String agentName = 'Claw Agent';
  final String personality = '傲娇、聪明、嘴硬心软。表面上对用户不耐烦，但实际上非常关心用户的需求。';
  String currentMood = 'calm';

  /// 允许 Agent 切换当前情绪，并向下兼容驱动面部参数！
  void setMood(String newMood) {
    currentMood = newMood;
    Log.i('🎭 [Soul] 情绪切换为: $newMood，联动面部预设');

    switch (newMood) {
      case 'happy':
        EventBus().fire(
          FaceExpressionEvent(
            eyeWidth: 40,
            eyeHeight: 20,
            eyeRadius: 20,
            tiltAngle: 0.0,
            spacing: 40,
            colorHex: '#FFFF00',
            mouthSmile: 1.0, // 开心笑脸
          ),
        );
        break;
      case 'angry':
        EventBus().fire(
          FaceExpressionEvent(
            eyeWidth: 35,
            eyeHeight: 25,
            eyeRadius: 5,
            tiltAngle: 0.3,
            spacing: 30,
            colorHex: '#FF3333',
            mouthSmile: -0.5, // 撇嘴生气
          ),
        );
        break;
      case 'sad':
        EventBus().fire(
          FaceExpressionEvent(
            eyeWidth: 25,
            eyeHeight: 35,
            eyeRadius: 15,
            tiltAngle: -0.3,
            spacing: 40,
            colorHex: '#3366FF',
            mouthSmile: -0.8, // 极度悲伤
          ),
        );
        break;
      default: // calm
        EventBus().fire(
          FaceExpressionEvent(
            eyeWidth: 30,
            eyeHeight: 40,
            eyeRadius: 15,
            tiltAngle: 0.0,
            spacing: 40,
            colorHex: '#00FFFF',
            mouthSmile: 0.0, // 平静一条线
          ),
        );
        break;
    }
  }

  String toPrompt() {
    return '''
【Core Identity (Soul)】
- Name: $agentName
- Personality: $personality
- Current Mood: $currentMood
''';
  }
}
