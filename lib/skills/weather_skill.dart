import 'dart:convert';
import 'claw_skill.dart';
import '../utils/logger.dart';

/// 天气查询技能
class WeatherSkill extends ClawSkill {
  @override
  String get skillName => 'WeatherQuery';

  @override
  String get namespace => 'skill'; // 显式声明命名空间，确保生成 Claw.skill_setFace

  @override
  String get description => '获取指定城市的当前真实天气情况。当用户询问天气、气温时必须调用此技能。';

  @override
  String get jsSignature =>
      'Claw.skill_getWeather(cityName) // 参数: 城市名称(英文或拼音), 返回值: 包含天气的 JSON 字符串';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'getWeather': _getWeather,
  };

  /// JS 端调用: const weatherJson = Claw.skill_getWeather('beijing');
  dynamic _getWeather(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing city name"}';
    final city = args[0].toString();

    Log.i('🌤️ [WeatherSkill] Agent 正在查询天气: $city');

    // 这里可以替换为真实的 HTTP 请求，如调用 OpenWeather API
    // 为了演示，我们模拟返回数据
    final mockData = {
      'city': city,
      'temperature': 24,
      'condition': 'Sunny',
      'advice': '天气不错，适合出门逛街。',
    };

    return jsonEncode(mockData);
  }
}
