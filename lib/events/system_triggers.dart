import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';
import 'event_bus.dart';

// --- 定义事件枚举与数据结构 ---
enum TriggerType {
  appResumed,          // 用户切回了应用 / 刚解锁屏幕亮起
  batteryLow,          // 电量告急 (<20%)
  networkDisconnected, // 突然断网
  networkRestored      // 网络恢复
}

class SystemEvent {
  final TriggerType type;
  final dynamic data; // 携带的附加数据，比如当前的电量百分比
  SystemEvent(this.type, {this.data});
}

// --- 系统触发器核心类 ---
/// 混入 WidgetsBindingObserver 以监听 Flutter 引擎级别的生命周期
class SystemTriggers with WidgetsBindingObserver {
  static final SystemTriggers _instance = SystemTriggers._internal();
  factory SystemTriggers() => _instance;
  SystemTriggers._internal();

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? _batterySub;
  StreamSubscription? _connectivitySub;
  bool _isInitialized = false;

  /// 🌟 移除了回调函数参数，完全依赖 EventBus
  void init() {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);

    _batterySub = _battery.onBatteryStateChanged.listen((BatteryState state) async {
      if (state == BatteryState.discharging) {
        final level = await _battery.batteryLevel;
        if (level <= 20) {
          _fireEvent(SystemEvent(TriggerType.batteryLow, data: level));
        }
      }
    });

    _connectivitySub = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none)) {
        _fireEvent(SystemEvent(TriggerType.networkDisconnected));
      } else {
        _fireEvent(SystemEvent(TriggerType.networkRestored));
      }
    });

    _isInitialized = true;
    Log.i('📡 [SystemTriggers] 系统硬件级神经末梢已激活');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fireEvent(SystemEvent(TriggerType.appResumed));
    }
  }

  void _fireEvent(SystemEvent event) {
    Log.i('🔔 [SystemTriggers] 捕获到系统事件: ${event.type.name}');
    // 🌟 将事件丢进全局总线
    EventBus().fire(SystemStatusEvent(event.type.name, payload: event.data));
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _batterySub?.cancel();
    _connectivitySub?.cancel();
    _isInitialized = false;
  }
}