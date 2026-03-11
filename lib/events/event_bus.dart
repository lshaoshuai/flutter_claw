import 'dart:async';
import '../utils/logger.dart';

// ============================================================================
// 1. 定义全局事件基类 (所有事件都必须继承它，保证类型安全)
// ============================================================================
abstract class ClawEvent {
  final DateTime timestamp;
  ClawEvent() : timestamp = DateTime.now();
}

// ============================================================================
// 2. 定义具体的业务事件 (你可以随着业务拓展无限增加)
// ============================================================================

/// 系统硬件状态事件 (如：电量低、断网、亮屏)
class SystemStatusEvent extends ClawEvent {
  final String triggerType; // 例如: "battery_low", "app_resumed"
  final dynamic payload;    // 携带的数据，例如电量百分比 15

  SystemStatusEvent(this.triggerType, {this.payload});
}

/// 记忆更新事件 (当 Agent 记住了新东西时触发，可用于刷新 UI)
class MemoryUpdatedEvent extends ClawEvent {
  final String newFact;
  MemoryUpdatedEvent(this.newFact);
}

/// 主动对话请求事件 (潜意识引擎决定开口说话时触发)
class ProactiveSpeakEvent extends ClawEvent {
  final String thoughtContext; // 告诉 Agent 为什么开口，例如："用户刚起床，说句早安"
  ProactiveSpeakEvent(this.thoughtContext);
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