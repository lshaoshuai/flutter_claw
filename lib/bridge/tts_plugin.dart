import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

import 'bridge_registry.dart';
import '../events/event_bus.dart';
import '../utils/logger.dart';

/// 文本转语音 (Text-to-Speech) 插件。
///
/// 双引擎策略：
/// - `supertonic_flutter`：神经 TTS，模型本地化后完全离线。
///   覆盖 EN / KO / ES / PT / FR。
/// - `flutter_tts`：系统级 TTS，作为 zh-CN / ja-JP 等
///   supertonic 不支持语种的兜底。
///
/// supertonic 首次使用会从 HuggingFace 下载 ~268MB 模型，
/// 因此采用懒加载：第一次需要它时才触发 `initialize()`，
/// 不阻塞插件构造。
///
/// 每个 [TTSPlugin] 实例可以挂在不同的 [BridgeRegistry] 下，给不同的
/// agent 各自一张嘴；通过 [agentId] 把 SpeakingStatusEvent 路由回 UI。
class TTSPlugin extends ClawBridgePlugin {
  TTSPlugin({
    this.agentId,
    String defaultVoiceStyle = 'F1',
    double speechSpeed = 1.05,
  })  : _defaultVoiceStyle = defaultVoiceStyle,
        _ttsConfig = TTSConfig(speechSpeed: speechSpeed) {
    _initFallbackTts();
  }

  /// 哪个 agent 在说话。null = 全局/默认。
  final String? agentId;

  // ---- supertonic (主引擎) ----
  final String _defaultVoiceStyle;
  final TTSConfig _ttsConfig;
  final SupertonicTTS _supertonic = SupertonicTTS();
  final TTSAudioPlayer _player = TTSAudioPlayer();
  Future<bool>? _supertonicReady;

  // ---- flutter_tts (zh / ja 兜底) ----
  final FlutterTts _fallbackTts = FlutterTts();

  Future<void> _initFallbackTts() async {
    await _fallbackTts.setSpeechRate(0.5);
    await _fallbackTts.setPitch(1.2);

    _fallbackTts.setStartHandler(() {
      Log.i('🗣️ [TTSPlugin/sys] 开始播报');
      EventBus().fire(SpeakingStatusEvent(true, agentId: agentId));
    });
    _fallbackTts.setCompletionHandler(() {
      Log.i('🤐 [TTSPlugin/sys] 播报结束');
      EventBus().fire(SpeakingStatusEvent(false, agentId: agentId));
    });
    _fallbackTts.setCancelHandler(() {
      Log.w('🛑 [TTSPlugin/sys] 播报被取消');
      EventBus().fire(SpeakingStatusEvent(false, agentId: agentId));
    });
    _fallbackTts.setErrorHandler((msg) {
      Log.e('❌ [TTSPlugin/sys] 播报出错: $msg');
      EventBus().fire(SpeakingStatusEvent(false, agentId: agentId));
    });

    try {
      if (Platform.isAndroid) {
        await _fallbackTts.setQueueMode(1);
      } else if (Platform.isIOS) {
        await _fallbackTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
        );
      }
    } catch (e) {
      Log.e('⚠️ [TTSPlugin/sys] 平台专属配置初始化失败: $e');
    }
  }

  /// 懒加载 supertonic 引擎。首次调用会触发模型缓存检查 / 下载。
  Future<bool> _ensureSupertonicReady() {
    return _supertonicReady ??= () async {
      try {
        Log.i('🧠 [TTSPlugin] 正在初始化 supertonic 神经 TTS…');
        await _supertonic.initialize();
        Log.i('✅ [TTSPlugin] supertonic 就绪');
        return true;
      } catch (e) {
        Log.e('❌ [TTSPlugin] supertonic 初始化失败: $e');
        return false;
      }
    }();
  }

  @override
  String get namespace => 'tts';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
        'speak': _speak,
      };

  @override
  List<String> get jsSignatures => [
        'Claw.tts_speak(text: String) -> Returns JSON string {"status": "success"} // 调用扬声器用语音读出文本内容。自带中、日、英、韩、西、葡、法语言自动识别（中日走系统 TTS，其余走离线神经 TTS）。请确保传入的文本尽量口语化，避免包含复杂的 Markdown 代码或生僻符号。'
      ];

  dynamic _speak(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing text parameter"}';

    final rawText = args[0].toString();
    final safeText = rawText
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('*', '')
        .replaceAll('#', '');

    _speakWithLanguageDetection(safeText);
    return '{"status": "success"}';
  }

  Future<void> _speakWithLanguageDetection(String text) async {
    final hasChinese = RegExp(r'[一-龥]').hasMatch(text);
    final hasJapanese = RegExp(r'[ぁ-んァ-ン]').hasMatch(text);
    final hasKorean = RegExp(r'[가-힯]').hasMatch(text);

    if (hasChinese) {
      await _speakWithFallback(text, 'zh-CN');
      return;
    }
    if (hasJapanese) {
      await _speakWithFallback(text, 'ja-JP');
      return;
    }

    final language = hasKorean ? 'ko' : 'en';
    await _speakWithSupertonic(text, language: language);
  }

  Future<void> _speakWithSupertonic(
    String text, {
    required String language,
  }) async {
    final ready = await _ensureSupertonicReady();
    if (!ready) {
      await _speakWithFallback(text, 'en-US');
      return;
    }

    EventBus().fire(SpeakingStatusEvent(true, agentId: agentId));
    try {
      Log.i('🗣️ [TTSPlugin/supertonic] $language/$_defaultVoiceStyle 开始合成');
      final result = await _supertonic.synthesize(
        text,
        language: language,
        voiceStyle: _defaultVoiceStyle,
        config: _ttsConfig,
      );
      await _player.play(result);
      Log.i('🤐 [TTSPlugin/supertonic] 播报结束');
    } catch (e) {
      Log.e('❌ [TTSPlugin/supertonic] 合成或播放失败: $e');
    } finally {
      EventBus().fire(SpeakingStatusEvent(false, agentId: agentId));
    }
  }

  Future<void> _speakWithFallback(String text, String locale) async {
    try {
      await _fallbackTts.setLanguage(locale);
      await _fallbackTts.speak(text);
    } catch (e) {
      Log.e('❌ [TTSPlugin/sys] 语言切换或播报失败: $e');
      EventBus().fire(SpeakingStatusEvent(false, agentId: agentId));
    }
  }
}
