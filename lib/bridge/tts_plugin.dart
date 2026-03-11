import 'dart:io' show Platform;
import 'package:flutter_tts/flutter_tts.dart';
import 'bridge_registry.dart';
import '../events/event_bus.dart'; // 🌟 引入事件总线
import '../utils/logger.dart';     // 顺手把你之前的 print 换成标准日志

/// 文本转语音 (Text-to-Speech) 插件
/// 赋予 Agent 说话的能力，支持自动识别语言，并联动 UI 表情系统
class TTSPlugin extends ClawBridgePlugin {
  final FlutterTts flutterTts = FlutterTts();

  TTSPlugin() {
    _initTts();
  }

  Future<void> _initTts() async {
    // 基础设置 (语速、音调)
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.2);

    // 🌟 1. 绑定发声生命周期到事件总线 (联动 ClawAvatar)
    flutterTts.setStartHandler(() {
      Log.i('🗣️ [TTSPlugin] 开始播报');
      EventBus().fire(SpeakingStatusEvent(true)); // 通知脸部：开始动嘴巴/眼睛闪烁
    });

    flutterTts.setCompletionHandler(() {
      Log.i('🤐 [TTSPlugin] 播报结束');
      EventBus().fire(SpeakingStatusEvent(false)); // 通知脸部：恢复平静
    });

    flutterTts.setCancelHandler(() {
      Log.w('🛑 [TTSPlugin] 播报被取消');
      EventBus().fire(SpeakingStatusEvent(false));
    });

    flutterTts.setErrorHandler((msg) {
      Log.e('❌ [TTSPlugin] 播报出错: $msg');
      EventBus().fire(SpeakingStatusEvent(false));
    });

    // 🌟 2. 平台专属配置初始化
    try {
      if (Platform.isAndroid) {
        // 仅 Android 支持 QueueMode
        await flutterTts.setQueueMode(1);
      } else if (Platform.isIOS) {
        // 仅 iOS 支持 AudioCategory
        await flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers
          ],
        );
      }
    } catch (e) {
      Log.e('⚠️ [TTSPlugin] 平台专属配置初始化失败: $e');
    }
  }

  @override
  String get namespace => 'tts';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'speak': _speak,
  };

  /// JS 端同步调用: Claw.tts_speak('你好 / Hello')
  dynamic _speak(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing text parameter"}';

    // 过滤破坏性符号 (换行、Markdown 标记)
    final rawText = args[0].toString();
    final safeText = rawText
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('*', '')
        .replaceAll('#', '');

    // 异步触发语音播报与语言切换 (不阻塞 JS 执行线程)
    _speakWithLanguageDetection(safeText);

    return '{"status": "success"}';
  }

  /// 内部异步方法：检测语言并播报
  Future<void> _speakWithLanguageDetection(String text) async {
    // 正则匹配：是否包含中文字符 (CJK 统一表意文字)
    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
    // 正则匹配：是否包含日文假名
    final hasJapanese = RegExp(r'[ぁ-んァ-ン]').hasMatch(text);

    try {
      if (hasChinese) {
        await flutterTts.setLanguage("zh-CN");
      } else if (hasJapanese) {
        await flutterTts.setLanguage("ja-JP");
      } else {
        // 如果都没有，默认回退到英文
        await flutterTts.setLanguage("en-US");
      }

      // 切换完语言后，开始播报。由于我们在 init 里设置了 Handler，
      // 这里调用 speak 后，EventBus 会自动捕获并通知 UI！
      await flutterTts.speak(text);
    } catch (e) {
      Log.e('❌ [TTSPlugin] 语言切换或播报失败: $e');
    }
  }
}