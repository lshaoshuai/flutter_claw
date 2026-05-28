import 'dart:async';
import 'dart:io' show Directory, File, Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import 'bridge_registry.dart';
import 'tts_engine.dart';
import '../context/claw_config.dart';
import '../events/event_bus.dart';
import '../utils/logger.dart';

/// 文本转语音 (Text-to-Speech) 插件。
///
/// 设计：
/// * **神经 TTS** — 由 host 应用通过 [TTSEngineRegistry.current] 注入一个
///   [TTSEngine] 实现 (weclaw 注入的是 sherpa-onnx Supertonic 3，覆盖 31 种
///   语言，含中文)。所有语种都走它。
/// * **系统 TTS** — 当 host 没注入引擎、或引擎 warmUp / 合成失败时，回退到
///   [FlutterTts]。语种由文本脚本自动识别。
///
/// 每个 [TTSPlugin] 实例可以挂在不同的 [BridgeRegistry] 下，给不同的
/// agent 各自一张嘴；通过 [agentId] 把 SpeakingStatusEvent 路由回 UI。
class TTSPlugin extends ClawBridgePlugin {
  TTSPlugin({this.agentId}) {
    _initFallbackTts();
  }

  /// 哪个 agent 在说话。null = 全局/默认。
  final String? agentId;

  /// 自己用 audioplayers + .wav 临时文件播放神经 TTS 输出 — iOS AVPlayer
  /// 拿到不带扩展名的 BytesSource 会拒收，所以我们走临时文件路径。
  static final AudioPlayer _player = AudioPlayer();
  static int _wavSerial = 0;

  static Future<bool>? _warmUpFuture;

  /// Tail of the serial speak queue.  Static so it serializes across every
  /// [TTSPlugin] instance — different agents still share one mouth/speaker.
  ///
  /// Why a queue: [_speak] is fire-and-forget from the JS sandbox's view
  /// (returns immediately so the iterative loop can move on), but the
  /// underlying [_player] is a single shared instance.  Without a queue,
  /// step N+1's `tts_speak` would call `_player.stop()` and cut off step
  /// N's voice mid-sentence.  The queue chains them so each clip plays in
  /// full before the next one starts.
  static Future<void>? _speakQueueTail;

  /// Append [task] to the global serial speak queue and return when it
  /// finishes.  Callers that don't want to await (e.g. the JS bridge entry)
  /// just ignore the returned future — the task is still queued.
  ///
  /// Errors in earlier tasks don't block later ones — we wrap each step so
  /// a thrown synth/play failure can't poison the rest of the queue.
  static Future<void> _enqueueSpeak(Future<void> Function() task) {
    final prev = _speakQueueTail ?? Future.value();
    final next = prev.catchError((_) {}).then((_) => task());
    _speakQueueTail = next;
    return next;
  }

  /// 在 app 启动时调用即可"暖机" — 走 [TTSEngineRegistry.current] 注入的
  /// 引擎（首次会下载模型）。无引擎注册时直接返回 false，调用方应回退到系统
  /// TTS。
  ///
  /// 可以反复调用，多并发也安全（内部 future 缓存）。第一个调用方传入的
  /// onProgress 是有效的；后续调用如果想监听进度，可以观察引擎自己的
  /// reactive 状态（例如 weclaw 的 SherpaSupertonic3Tts.downloadProgress）。
  static Future<bool> warmUp({DownloadProgressCallback? onProgress}) {
    return _warmUpFuture ??= () async {
      final engine = TTSEngineRegistry.current;
      if (engine == null) {
        Log.w('⚠️ [TTSPlugin] no TTSEngine registered — neural TTS disabled, '
            'falling back to system TTS for all speech');
        return false;
      }
      try {
        Log.i('📦 [TTSPlugin] warm-up via registered engine');
        final ok = await engine.warmUp(
          onProgress: onProgress == null
              ? null
              : (fraction, {phase}) {
                  // Adapt to the legacy 4-tuple shape so UIs wired against
                  // the old supertonic_flutter callback keep working.  We
                  // pretend a single file with fileProgress == fraction.
                  onProgress(0, 1, phase ?? 'model', fraction);
                },
        );
        if (ok) Log.i('✅ [TTSPlugin] engine ready');
        return ok;
      } catch (e) {
        Log.e('❌ [TTSPlugin] engine warm-up failed: $e');
        return false;
      }
    }();
  }

  // ---- flutter_tts (无引擎 / 引擎失败时的兜底) ----
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

  @override
  String get namespace => 'tts';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
        'speak': _speak,
      };

  @override
  List<String> get jsSignatures => [
        'Claw.tts_speak(text: String) -> Returns JSON string {"status": "success"} // 调用扬声器用语音读出文本内容。Host 通常会注入一个多语言神经 TTS 引擎；未注入时回退系统 TTS。文本请尽量口语化，避免 Markdown / 生僻符号。'
      ];

  dynamic _speak(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing text parameter"}';

    final rawText = args[0].toString();
    final safeText = rawText
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('*', '')
        .replaceAll('#', '');

    // Queue instead of fire-and-forget so step N+1's `tts_speak` doesn't
    // cut step N's playback mid-sentence (see [_enqueueSpeak] doc).  We
    // intentionally don't await — the JS sandbox still gets an instant
    // success response, the iterative loop can move on, the audio plays
    // in order as a side-effect.
    // ignore: unawaited_futures
    _enqueueSpeak(() => _speakWithLanguageDetection(safeText));
    return '{"status": "success"}';
  }

  Future<void> _speakWithLanguageDetection(String text) async {
    final hasChinese = RegExp(r'[一-龥]').hasMatch(text);
    final hasJapanese = RegExp(r'[ぁ-んァ-ン]').hasMatch(text);
    final hasKorean = RegExp(r'[가-힯]').hasMatch(text);

    final engine = TTSEngineRegistry.current;
    if (engine != null) {
      // Neural engine handles every language (Supertonic 3 covers 31).
      final lang = hasChinese
          ? 'zh'
          : hasJapanese
              ? 'ja'
              : hasKorean
                  ? 'ko'
                  : 'en';
      await _speakWithEngine(text, language: lang);
      return;
    }

    // No engine registered — system TTS for everything.
    final locale = hasChinese
        ? 'zh-CN'
        : hasJapanese
            ? 'ja-JP'
            : hasKorean
                ? 'ko-KR'
                : 'en-US';
    await _speakWithFallback(text, locale);
  }

  Future<void> _speakWithEngine(
    String text, {
    required String language,
  }) async {
    final engine = TTSEngineRegistry.current!;
    final ready = engine.isReady ? true : await engine.warmUp();
    if (!ready) {
      await _speakWithFallback(text, 'en-US');
      return;
    }
    final voice = ClawConfig().getApiKey('TTS_VOICE_STYLE');
    EventBus().fire(SpeakingStatusEvent(true, agentId: agentId));
    try {
      Log.i('🗣️ [TTSPlugin/engine] $language 开始合成');
      final wavBytes = await engine.synthesizeToWav(
        text,
        language: language,
        voice: voice,
      );
      // Pre-compute amplitude envelope so the lip-sync scheduler can run
      // in lock-step with playback.
      final envelope = _computeWavEnvelope(wavBytes, frameRate: 30);
      await _playWavBytes(wavBytes, envelope: envelope);
      Log.i('🤐 [TTSPlugin/engine] 播报结束');
    } catch (e) {
      Log.e('❌ [TTSPlugin/engine] 合成或播放失败: $e');
      // Last-ditch: try system TTS so the user at least hears something.
      await _speakWithFallback(text, 'en-US');
    } finally {
      EventBus().fire(SpeakingStatusEvent(false, agentId: agentId));
      EventBus().fire(LipSyncAmplitudeEvent(0, agentId: agentId));
    }
  }

  /// Play synthesized WAV bytes via audioplayers using a real `.wav` file.
  ///
  /// iOS AVPlayer relies on the file extension (or a mimeType hint) to pick
  /// a decoder; raw bytes without either are rejected.  Temp file is awaited
  /// to completion then deleted in the background.
  ///
  /// If [envelope] is provided, schedules a 30fps tick that fires
  /// [LipSyncAmplitudeEvent]s aligned with playback for accurate lip sync.
  Future<void> _playWavBytes(Uint8List bytes,
      {List<double>? envelope}) async {
    final dir = await getTemporaryDirectory();
    final ttsDir = Directory('${dir.path}/tts');
    if (!ttsDir.existsSync()) ttsDir.createSync(recursive: true);

    final path = '${ttsDir.path}/utt_${_wavSerial++}.wav';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    final completer = Completer<void>();
    late final StreamSubscription sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    await _player.stop();
    await _player.play(DeviceFileSource(path));

    Timer? lipTimer;
    if (envelope != null && envelope.isNotEmpty) {
      final start = DateTime.now();
      // Frame rate determined by computeWavEnvelope (default 30fps).
      const frameMs = 33;
      lipTimer = Timer.periodic(const Duration(milliseconds: frameMs), (t) {
        final elapsedMs =
            DateTime.now().difference(start).inMilliseconds;
        final idx = (elapsedMs / frameMs).floor();
        if (idx >= envelope.length || completer.isCompleted) {
          t.cancel();
          return;
        }
        EventBus().fire(
            LipSyncAmplitudeEvent(envelope[idx], agentId: agentId));
      });
    }

    try {
      await completer.future.timeout(const Duration(seconds: 60));
    } catch (_) {
      // 超时不阻塞下一句；删除文件、清理订阅。
    } finally {
      lipTimer?.cancel();
      await sub.cancel();
      file.delete().ignore();
    }
  }

  /// Parse PCM WAV bytes and compute per-frame RMS amplitude (0..1) at the
  /// given [frameRate] (Hz).  Supports the 16-bit PCM little-endian format
  /// the engine produces; returns an empty list on any header surprise.
  ///
  /// Heuristic normalization: RMS / 8000 then clipped — keeps speech at
  /// realistic mouth-open values without occasional loud syllables blowing
  /// out to mouth-wide-open.
  List<double> _computeWavEnvelope(Uint8List bytes, {int frameRate = 30}) {
    if (bytes.length < 44) return const [];
    final bd = ByteData.sublistView(bytes);
    if (bytes[0] != 0x52 || bytes[1] != 0x49) return const [];
    final sampleRate = bd.getUint32(24, Endian.little);
    final bitsPerSample = bd.getUint16(34, Endian.little);
    if (sampleRate == 0 || bitsPerSample != 16) return const [];

    int dataStart = 36;
    while (dataStart + 8 < bytes.length) {
      final chunkId =
          String.fromCharCodes(bytes.sublist(dataStart, dataStart + 4));
      final chunkSize = bd.getUint32(dataStart + 4, Endian.little);
      if (chunkId == 'data') {
        dataStart += 8;
        break;
      }
      dataStart += 8 + chunkSize;
    }
    if (dataStart >= bytes.length) return const [];

    final samplesPerFrame = (sampleRate / frameRate).round();
    final samples = ByteData.sublistView(bytes, dataStart);
    final sampleCount = samples.lengthInBytes ~/ 2;

    final out = <double>[];
    for (int i = 0; i < sampleCount; i += samplesPerFrame) {
      double sumSq = 0;
      int n = 0;
      for (int j = i; j < i + samplesPerFrame && j < sampleCount; j++, n++) {
        final s = samples.getInt16(j * 2, Endian.little).toDouble();
        sumSq += s * s;
      }
      if (n == 0) break;
      final rms = math.sqrt(sumSq / n);
      out.add((rms / 8000).clamp(0.0, 1.0));
    }
    return out;
  }

  /// System TTS path — we don't get the PCM stream back, so drive lip sync
  /// with a low-frequency sine wave for the estimated duration of the speech.
  /// Rough estimate: 4 chars per second for CN/JA.
  Future<void> _speakWithFallback(String text, String locale) async {
    final estDurationMs = math.max(800, (text.length * 250));
    final start = DateTime.now();
    final lipTimer = Timer.periodic(const Duration(milliseconds: 33), (t) {
      final elapsedMs = DateTime.now().difference(start).inMilliseconds;
      if (elapsedMs > estDurationMs + 500) {
        t.cancel();
        EventBus().fire(LipSyncAmplitudeEvent(0, agentId: agentId));
        return;
      }
      final phase = elapsedMs / 1000.0 * 4 * 2 * math.pi;
      final envelope = math
          .min(1.0, math.min(elapsedMs / 200, (estDurationMs - elapsedMs) / 200))
          .clamp(0.0, 1.0);
      final amp = ((math.sin(phase) + 1) / 2 * 0.7) * envelope;
      EventBus().fire(LipSyncAmplitudeEvent(amp, agentId: agentId));
    });

    try {
      await _fallbackTts.setLanguage(locale);
      await _fallbackTts.speak(text);
    } catch (e) {
      Log.e('❌ [TTSPlugin/sys] 语言切换或播报失败: $e');
      EventBus().fire(SpeakingStatusEvent(false, agentId: agentId));
    } finally {
      Future.delayed(Duration(milliseconds: estDurationMs + 600), () {
        lipTimer.cancel();
        EventBus().fire(LipSyncAmplitudeEvent(0, agentId: agentId));
      });
    }
  }
}

/// Legacy progress signature kept for source compatibility with hosts that
/// wired UIs against the old supertonic_flutter callback.  When sherpa-onnx
/// is in play, only the last param is meaningful.
typedef DownloadProgressCallback = void Function(
  int completedFiles,
  int totalFiles,
  String currentFile,
  double fileProgress,
);
