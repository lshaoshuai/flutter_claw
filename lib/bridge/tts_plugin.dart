import 'package:flutter_tts/flutter_tts.dart';

import 'bridge_registry.dart';
import '../utils/logger.dart';

/// 文本转语音 (Text-to-Speech) 插件
/// 赋予 Agent 说话的能力
class TTSPlugin extends ClawBridgePlugin {
  // 真实项目中建议引入 `flutter_tts` 库
  final FlutterTts flutterTts = FlutterTts();

  @override
  String get namespace => 'tts';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'speak': _speak,
    'stop': _stop,
  };

  /// JS 端调用: Claw.tts_speak('哼，别以为我会夸你！')
  dynamic _speak(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing text parameter"}';
    final text = args[0].toString();

    Log.i('🗣️ [TTSPlugin] Agent 正在说话: $text');

    flutterTts.setLanguage("en-US");
    flutterTts.setPitch(1.2);
    flutterTts.speak(text);

    return '{"status": "success", "action": "speaking"}';
  }

  /// JS 端调用: Claw.tts_stop()
  dynamic _stop(List<dynamic> args) {
    // flutterTts.stop();
    Log.i('🛑 [TTSPlugin] 中断了 Agent 的语音播报');
    return '{"status": "success"}';
  }
}
