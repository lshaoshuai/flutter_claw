import 'dart:developer' as developer;

/// 内部日志工具类
/// 用于统一管理 flutter_claw 的日志输出，支持多级别和一键开关。
class ClawLogger {
  /// 是否开启调试日志 (生产环境建议设为 false)
  static bool enableDebug = true;

  /// 打印通用信息 (如 Agent 的正常流转状态)
  static void info(String message, {String tag = 'Claw'}) {
    if (!enableDebug) return;
    final logMsg = '🔵 [$tag] $message';
    developer.log(logMsg, name: tag);
    print(logMsg);
  }

  /// 打印警告信息 (如网络超时重试、Token 接近超限)
  static void warning(String message, {String tag = 'Claw'}) {
    if (!enableDebug) return;
    final logMsg = '🟡 [$tag] $message';
    developer.log(logMsg, name: tag, level: 900);
    print(logMsg);
  }

  /// 打印严重错误信息 (如 JS 引擎崩溃、路径越权拦截)
  /// 错误日志不受 enableDebug 控制，始终打印
  static void error(String message, {Object? error, StackTrace? stackTrace, String tag = 'Claw'}) {
    final logMsg = '🔴 [$tag] $message';
    developer.log(logMsg, name: tag, error: error, stackTrace: stackTrace, level: 1000);
    print(logMsg);

    if (error != null) {
      print('Exception: $error');
    }
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }
  }

  /// 打印成功状态 (如代码执行成功、路由分发完成)
  static void success(String message, {String tag = 'Claw'}) {
    if (!enableDebug) return;
    final logMsg = '🟢 [$tag] $message';
    developer.log(logMsg, name: tag);
    print(logMsg);
  }

  /// 打印极客风的调试数据 (如完整的大模型请求 Payload、JS 堆栈)
  static void debug(String message, {String tag = 'Claw Debug'}) {
    if (!enableDebug) return;
    final logMsg = '⚙️ [$tag] $message';
    developer.log(logMsg, name: tag, level: 500);
    print(logMsg);
  }
}