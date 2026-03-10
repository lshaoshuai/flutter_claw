import 'dart:async';
import '../models/execution_result.dart';
import '../models/task_config.dart';

/// 单次代码执行的上下文环境
/// 负责管理单次任务的生命周期、超时熔断以及标准输入/输出流的收集
class ExecutionContext {
  /// 任务配置 (包含超时时间、重试策略等)
  final TaskConfig config;

  /// 记录执行开始的时间
  final DateTime startTime;

  /// 用于异步等待 JS 代码触发 Claw.finish() 或抛出异常
  final Completer<ExecutionResult> _completer = Completer<ExecutionResult>();

  /// 标准输出缓冲 (比如拦截 JS 的 console.log)
  final StringBuffer _stdoutBuffer = StringBuffer();

  /// 标准错误缓冲 (比如拦截 JS 的 console.error)
  final StringBuffer _stderrBuffer = StringBuffer();

  ExecutionContext(this.config) : startTime = DateTime.now();

  /// 获取带超时控制的执行结果 Future
  Future<ExecutionResult> get future => _completer.future.timeout(
    config.timeout,
    onTimeout: () {
      // 触发超时熔断机制
      if (!_completer.isCompleted) {
        fail('代码执行超时 (${config.timeout.inSeconds} 秒)，已被系统强制阻断。可能是死循环或网络等待过长。');
      }
      return _completer.future;
    },
  );

  /// 追加标准输出 (Stdout)
  void appendStdout(String log) {
    _stdoutBuffer.writeln(log);
    // TODO: 这里可以抛出一个 Stream 事件，让 Flutter UI 实时显示打字机效果的运行日志
  }

  /// 追加错误输出 (Stderr)
  void appendStderr(String error) {
    _stderrBuffer.writeln(error);
  }

  /// 正常结束执行 (由 JS 端的 Claw.finish() 触发)
  void finish(String finalOutput) {
    if (!_completer.isCompleted) {
      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

      // 合并运行时的 console 日志和最终结果
      final fullOutput = _stdoutBuffer.isNotEmpty
          ? '${_stdoutBuffer.toString().trim()}\n$finalOutput'
          : finalOutput;

      _completer.complete(ExecutionResult.success(
        fullOutput,
        timeMs: executionTime,
      ));
    }
  }

  /// 异常结束执行 (主动抛出错误或遇到崩溃)
  void fail(String errorMsg) {
    if (!_completer.isCompleted) {
      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

      // 合并运行时的 error 日志和最终报错信息
      final fullError = _stderrBuffer.isNotEmpty
          ? '${_stderrBuffer.toString().trim()}\n$errorMsg'
          : errorMsg;

      _completer.complete(ExecutionResult.error(
        fullError,
        timeMs: executionTime,
      ));
    }
  }

  /// 是否已经执行完毕
  bool get isCompleted => _completer.isCompleted;
}