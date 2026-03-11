import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// 用户画像管理器 (User Persona)
class UserProfileManager {
  static final UserProfileManager _instance = UserProfileManager._internal();
  factory UserProfileManager() => _instance;
  UserProfileManager._internal();

  static const String _keyProfile = 'agent_user_profile';
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // 用户的画像标签 (Key: 维度, Value: 描述)
  // 例如: {"occupation": "软件工程师", "communication_style": "喜欢用短句，偏极客"}
  Map<String, String> traits = {};

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    final String? profileJson = _prefs.getString(_keyProfile);
    if (profileJson != null) {
      traits = Map<String, String>.from(json.decode(profileJson));
    }

    _isInitialized = true;
    Log.i('👤 [UserProfile] 画像加载完成: $traits');
  }

  /// 🌟 更新或添加画像标签
  Future<void> updateTraits(Map<String, String> newTraits) async {
    bool hasChanged = false;
    newTraits.forEach((key, value) {
      if (traits[key] != value) {
        traits[key] = value;
        hasChanged = true;
      }
    });

    if (hasChanged) {
      await _prefs.setString(_keyProfile, json.encode(traits));
      Log.i('✨ [UserProfile] 用户画像已更新并固化: $traits');
    }
  }

  /// 拼装给主 Agent 看的提示词
  String toPrompt() {
    if (traits.isEmpty) return '【User Persona】: Unknown (Analyze the user over time)';

    StringBuffer buffer = StringBuffer();
    buffer.writeln('【User Persona (Analyzed Background)】');
    traits.forEach((key, value) {
      buffer.writeln('- $key: $value');
    });
    return buffer.toString();
  }
}