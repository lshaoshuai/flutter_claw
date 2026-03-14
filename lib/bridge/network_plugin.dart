import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import 'bridge_registry.dart';

/// Real Asynchronous Network Request Plugin
/// Resolves the conflict between Dart's synchronous return requirement
/// and the asynchronous nature of HTTP execution.
class NetworkPlugin extends ClawBridgePlugin {
  // Used to cache results of asynchronous requests
  // Key: taskId, Value: Request result or error message
  final Map<String, String> _responseCache = {};

  @override
  String get namespace => 'network';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'fetch': _startFetch,
    'getResult': _getFetchResult,
  };

  // ============================================================================
  // 🌟 核心优化：非常详细的自描述，甚至包含 JS 轮询范例，防止大模型写错代码
  // ============================================================================
  @override
  List<String> get jsSignatures => [
    'Claw.network_fetch(url: String) -> Returns String (taskId) // 发起异步网络请求并立即返回一个 taskId',
    '''Claw.network_getResult(taskId: String) -> Returns JSON String // 根据 taskId 轮询请求结果。
// JS 调用范例 (请使用 while 循环轮询):
// const taskId = Claw.network_fetch("https://api.example.com");
// let result;
// while(true) { 
//   result = JSON.parse(Claw.network_getResult(taskId));
//   if(result.status !== "pending") break;
// }
// return result.body;'''
  ];

  /// JS Side Call: const taskId = Claw.network_fetch('https://api.example.com/data');
  /// This method returns synchronously; it only triggers the request and returns a taskId.
  dynamic _startFetch(List<dynamic> args) {
    if (args.isEmpty) {
      return '{"error": "Missing URL parameter"}';
    }

    final url = args[0].toString();
    // Generate a simple unique task ID
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}';

    // Initialize cache status as 'pending'
    _responseCache[taskId] = '{"status": "pending"}';

    Log.i('🌐 [NetworkPlugin] Received async GET request: $url (TaskID: $taskId)');

    // Trigger the actual async HTTP request (no await, allowing JS execution to continue)
    _executeRequest(taskId, url);

    // Immediately return the taskId to JS
    return taskId;
  }

  /// Actual asynchronous network request logic
  Future<void> _executeRequest(String taskId, String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      // Request completed, write result to cache
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _responseCache[taskId] = jsonEncode({
          'status': 'success',
          'statusCode': response.statusCode,
          'body': response.body, // Note: If body is plain text, escaping might be required
        });
      } else {
        _responseCache[taskId] = jsonEncode({
          'status': 'error',
          'statusCode': response.statusCode,
          'message': 'HTTP Request failed with status: ${response.statusCode}',
        });
      }
      Log.i('✅ [NetworkPlugin] Async request completed (TaskID: $taskId)');
    } catch (e) {
      // Catch network exceptions (e.g., disconnected, DNS resolution failure)
      _responseCache[taskId] = jsonEncode({
        'status': 'error',
        'message': e.toString(),
      });
      Log.e('❌ [NetworkPlugin] Async request failed (TaskID: $taskId): $e');
    }
  }

  /// JS Side Polling Call: const result = Claw.network_getResult(taskId);
  /// Returns '{"status": "pending"}' or '{"status": "success", "body": "..."}'
  dynamic _getFetchResult(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing taskId parameter"}';

    final taskId = args[0].toString();

    if (!_responseCache.containsKey(taskId)) {
      return '{"status": "error", "message": "Unknown taskId: $taskId"}';
    }

    final resultStr = _responseCache[taskId]!;

    // If task is finished (success or error), clear cache after reading to prevent memory leaks
    final resultMap = jsonDecode(resultStr);
    if (resultMap['status'] != 'pending') {
      _responseCache.remove(taskId);
    }

    return resultStr;
  }
}