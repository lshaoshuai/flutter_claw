import 'dart:async';
import '../models/emotion_params.dart';
import '../utils/logger.dart';

// ============================================================================
// 1. 定义全局事件基类 (所有事件都必须继承它，保证类型安全)
// ============================================================================
abstract class ClawEvent {
  final DateTime timestamp;

  /// 哪个 agent 发出的事件。null 表示全局/默认 agent。
  /// 当 weclaw 这类多 agent runtime 共享 EventBus 时，UI 用这个字段
  /// 路由到对应 agent 的头像/状态条。
  final String? agentId;

  ClawEvent({this.agentId}) : timestamp = DateTime.now();
}

// ============================================================================
// 2. 定义具体的业务事件 (你可以随着业务拓展无限增加)
// ============================================================================

/// 系统硬件状态事件 (如：电量低、断网、亮屏)
class SystemStatusEvent extends ClawEvent {
  final String triggerType; // 例如: "battery_low", "app_resumed"
  final dynamic payload;    // 携带的数据，例如电量百分比 15

  SystemStatusEvent(this.triggerType, {this.payload, super.agentId});
}

/// 记忆更新事件 (当 Agent 记住了新东西时触发，可用于刷新 UI)
class MemoryUpdatedEvent extends ClawEvent {
  final String newFact;
  MemoryUpdatedEvent(this.newFact, {super.agentId});
}

/// 主动对话请求事件 (潜意识引擎决定开口说话时触发)
class ProactiveSpeakEvent extends ClawEvent {
  final String thoughtContext;
  ProactiveSpeakEvent(this.thoughtContext, {super.agentId});
}

/// 当主人说话时，传递麦克风捕获的音量级别
class ListeningLevelEvent extends ClawEvent {
  final double level;
  ListeningLevelEvent(this.level, {super.agentId});
}

/// 情绪表现事件 (控制眼睛是开心、生气还是悲伤)
/// 🌟 参数化面部控制事件 (由大模型直接输出参数)
class FaceExpressionEvent extends ClawEvent {
  final double eyeWidth;
  final double eyeHeight;
  final double eyeRadius;
  final double spacing;
  final double tiltAngle;
  final String colorHex;
  final double mouthSmile; // 嘴巴弧度: 1.0(大笑), 0.0(平直), -1.0(悲伤下拉)

  FaceExpressionEvent({
    required this.eyeWidth,
    required this.eyeHeight,
    required this.eyeRadius,
    required this.spacing,
    required this.tiltAngle,
    required this.colorHex,
    required this.mouthSmile,
    super.agentId,
  });
}

class SpeakingStatusEvent extends ClawEvent {
  final bool isSpeaking;
  SpeakingStatusEvent(this.isSpeaking, {super.agentId});
}

/// 🌟 嘴型同步用：随 TTS 音频实时推送声波振幅 (0..1)。
///
/// 渲染层（Live2D / 矢量 avatar）拿这个值作为 mouthOpen 的瞬时驱动，从而
/// 让嘴型跟说话节奏对齐。约每 33ms 一帧 (~30fps)。
///
/// supertonic 路径会预解析 WAV 的 RMS 包络精确驱动；flutter_tts 系统 TTS
/// 拿不到 PCM，则退化为 ~4Hz 正弦波，节奏对不齐但嘴在动。
class LipSyncAmplitudeEvent extends ClawEvent {
  /// 0 = 完全闭嘴, 1 = 全开。
  final double amplitude;
  LipSyncAmplitudeEvent(this.amplitude, {super.agentId});
}

/// 🌟 富参数情绪事件 — 推荐用法。
///
/// 比 [FaceExpressionEvent] 表达力更强：渲染层拿到完整 [EmotionParams] 后
/// 可以平滑插值、做颤抖、做色相偏移等动画。AI 通过 `Claw.skill_setEmotion`
/// 触发；旧的 setFace 路径仍走 [FaceExpressionEvent] 以保兼容。
class EmotionStateEvent extends ClawEvent {
  final EmotionParams params;

  /// AI 当时给的语义标签 (e.g. "angry")，UI 可拿来显示文字提示；可空。
  final String? semanticLabel;

  EmotionStateEvent(this.params, {this.semanticLabel, super.agentId});
}

class SendMemeEvent extends ClawEvent {
  final String memeUrl;
  final String emotion;

  SendMemeEvent({required this.memeUrl, required this.emotion, super.agentId});
}

/// 🚨 Agent 越权霸屏事件 — AI 通过 [AlertSkill.alertUser] 主动打破常规
/// 对话流程，强制弹出一块"高于其他 UI 的"反馈卡片。宿主 App 监听并渲染。
///
/// [level] 决定视觉强度：
///  * "info"    — 底部 snackbar / 顶部小条
///  * "warning" — 顶部黄色横幅 + 中等震动
///  * "urgent"  — 屏幕闪红 + 全屏 modal + 重震动
///
/// [haptic] / [flash] 是 UI 层渲染时的参考开关；具体效果由宿主决定。
class AlertEvent extends ClawEvent {
  final String level;          // "info" | "warning" | "urgent"
  final String title;
  final String? message;
  final String? color;         // hex like "#FF3333", optional
  final int durationMs;        // 0 = require manual dismiss
  final bool flash;
  final String haptic;         // "none" | "light" | "medium" | "heavy"

  AlertEvent({
    required this.title,
    this.message,
    this.level = 'info',
    this.color,
    this.durationMs = 4000,
    this.flash = false,
    this.haptic = 'medium',
    super.agentId,
  });
}

// ============================================================================
// 3. 核心事件总线 (EventBus) - 单例模式 + 广播流
// ============================================================================
class EventBus {
  // 单例模式
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  // 创建一个支持多订阅者的广播流控制器
  final StreamController<ClawEvent> _streamController =
  StreamController<ClawEvent>.broadcast();

  /// 🌟 监听特定类型的事件
  /// 任何模块都可以调用 EventBus().on<SystemStatusEvent>().listen(...) 来订阅
  Stream<T> on<T extends ClawEvent>() {
    if (T == dynamic) {
      return _streamController.stream as Stream<T>;
    } else {
      // 巧妙利用 Dart 的 where 和 cast 语法，按类型过滤事件流
      return _streamController.stream.where((event) => event is T).cast<T>();
    }
  }

  /// 🌟 广播事件
  /// 感知层或触发器调用此方法把事件扔进总线
  void fire(ClawEvent event) {
    Log.i('🚏 [EventBus] 路由事件: ${event.runtimeType}');
    _streamController.add(event);
  }

  /// 销毁总线 (通常在 App 彻底退出时调用)
  void destroy() {
    _streamController.close();
  }
}