import 'dart:convert';
import 'package:http/http.dart' as http;
import 'bridge_registry.dart';

/// 真实的异步网络请求插件
/// 解决了 Dart 同步回传与 HTTP 异步执行的冲突问题
class NetworkPlugin extends ClawBridgePlugin {
  // 用于缓存异步请求的结果
  // Key: 任务ID (taskId), Value: 请求结果或报错信息
  final Map<String, String> _responseCache = {};

  @override
  String get namespace => 'network';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'fetch': _startFetch,
    'getResult': _getFetchResult,
  };

  /// JS 端调用: const taskId = Claw.network_fetch('https://api.example.com/data');
  /// 这个方法是同步返回的，它只负责触发请求并返回一个 taskId。
  dynamic _startFetch(List<dynamic> args) {
    if (args.isEmpty) {
      return '{"error": "Missing URL parameter"}';
    }

    final url = args[0].toString();
    // 生成一个简单的唯一任务 ID
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}';

    // 初始化缓存状态为 'pending'
    _responseCache[taskId] = '{"status": "pending"}';

    print('🌐 [NetworkPlugin] 收到异步 GET 请求: $url (TaskID: $taskId)');

    // 真正发起异步 HTTP 请求 (不 await，让 JS 继续往下走)
    _executeRequest(taskId, url);

    // 立即向 JS 返回 taskId
    return taskId;
  }

  /// 真正的异步网络请求逻辑
  Future<void> _executeRequest(String taskId, String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      // 请求完成，将结果写入缓存
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _responseCache[taskId] = jsonEncode({
          'status': 'success',
          'statusCode': response.statusCode,
          'body': response.body, // 注意：如果 body 是纯文本，可能需要处理转义
        });
      } else {
        _responseCache[taskId] = jsonEncode({
          'status': 'error',
          'statusCode': response.statusCode,
          'message': 'HTTP Request failed with status: ${response.statusCode}',
        });
      }
      print('✅ [NetworkPlugin] 异步请求完成 (TaskID: $taskId)');
    } catch (e) {
      // 捕获网络异常 (如断网、DNS 解析失败)
      _responseCache[taskId] = jsonEncode({
        'status': 'error',
        'message': e.toString(),
      });
      print('❌ [NetworkPlugin] 异步请求失败 (TaskID: $taskId): $e');
    }
  }

  /// JS 端轮询调用: const result = Claw.network_getResult(taskId);
  /// 返回 '{"status": "pending"}' 或 '{"status": "success", "body": "..."}'
  dynamic _getFetchResult(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing taskId parameter"}';

    final taskId = args[0].toString();

    if (!_responseCache.containsKey(taskId)) {
      return '{"status": "error", "message": "Unknown taskId: $taskId"}';
    }

    final resultStr = _responseCache[taskId]!;

    // 如果任务已经完成（成功或失败），读取后清理缓存以防止内存泄漏
    final resultMap = jsonDecode(resultStr);
    if (resultMap['status'] != 'pending') {
      _responseCache.remove(taskId);
    }

    return resultStr;
  }
}