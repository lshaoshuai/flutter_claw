import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart'; // 🌟 引入定位包
import '../utils/logger.dart';

/// 环境上下文聚合器 (Agent 的全息感知面板)
class ContextAggregator {
  static final ContextAggregator _instance = ContextAggregator._internal();
  factory ContextAggregator() => _instance;
  ContextAggregator._internal();

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  /// 🌟 抓取当前所有环境状态，生成全息快照
  Future<String> getCurrentSnapshot() async {
    try {
      // 1. 时间维度感知
      final now = DateTime.now();
      final timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      final timeOfDay = _getTimeOfDay(now.hour);

      // 2. 设备电量感知
      final batteryLevel = await _battery.batteryLevel;
      final batteryState = await _battery.batteryState;
      final batteryStatus = "$batteryLevel% (${batteryState.name})";

      // 3. 网络连通性感知
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);
      final networkStatus = isOffline ? "Offline" : "Online";

      // 4. 🌟 地理位置与运动感知
      String locationStatus = "Unknown (Permission Denied or GPS Off)";
      final position = await _determinePosition();
      if (position != null) {
        // 判断移动状态：大于 2 m/s (约 7.2 km/h) 视为正在移动
        final isMoving = position.speed > 2.0;
        final speedKmh = (position.speed * 3.6).toStringAsFixed(1);
        final movementStr = isMoving ? "Moving ($speedKmh km/h)" : "Stationary";

        // 保留 4 位小数，精度大概在 10 米级别，对大模型来说足够了
        locationStatus = "Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)} [$movementStr]";
      }

      // 5. 组装为 LLM 极易理解的格式
      return '''
【Current Environment Snapshot】
- Local Time: $timeString ($timeOfDay)
- Spatial Location: $locationStatus
- Device Battery: $batteryStatus
- Network Status: $networkStatus
''';
    } catch (e) {
      Log.e('❌ [ContextAggregator] 获取环境快照失败: $e');
      return '【Current Environment Snapshot】: Unavailable';
    }
  }

  /// 🌟 内部核心：安全获取地理位置，带超时保护
  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 测试定位服务是否开启
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    // 检查并请求权限
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      // 优化：先尝试拿最后一次的缓存位置，最快不阻塞聊天！
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) return lastPosition;

      // 如果没有缓存，再去现取。设置 3 秒超时，防止大模型等太久体验卡顿
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // 对于聊天上下文，low 的精度(几百米)完全足够且最省电
        timeLimit: const Duration(seconds: 3),
      );
    } catch (e) {
      Log.w('⚠️ [ContextAggregator] GPS 获取超时或失败: $e');
      return null;
    }
  }

  String _getTimeOfDay(int hour) {
    if (hour >= 5 && hour < 12) return "Morning";
    if (hour >= 12 && hour < 17) return "Afternoon";
    if (hour >= 17 && hour < 22) return "Evening";
    return "Late Night";
  }
}