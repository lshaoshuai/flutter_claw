/// 标准化的执行结果模型
/// 无论是大模型的纯文本生成，还是 QuickJS 沙盒的代码执行，
/// 最终都会封装成这个对象返回给调用方。
class ExecutionResult {
  /// 是否执行成功
  final bool isSuccess;

  /// 标准输出 (对应 JS 里的 console.log 或最终的返回数据)
  final String stdout;

  /// 标准错误 (对应 JS 里的异常堆栈或语法错误信息)
  final String stderr;

  /// 执行耗时 (毫秒)，可用于性能监控
  final int? executionTimeMs;

  ExecutionResult({
    required this.isSuccess,
    this.stdout = '',
    this.stderr = '',
    this.executionTimeMs,
  });

  /// 快速构造成功结果
  factory ExecutionResult.success(String output, {int? timeMs}) {
    return ExecutionResult(
      isSuccess: true,
      stdout: output,
      executionTimeMs: timeMs,
    );
  }

  /// 快速构造失败/报错结果
  factory ExecutionResult.error(String errorMsg, {int? timeMs}) {
    return ExecutionResult(
      isSuccess: false,
      stderr: errorMsg,
      executionTimeMs: timeMs,
    );
  }

  /// 转换为 JSON 格式，方便记录日志或进行网络传输
  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'stdout': stdout,
      'stderr': stderr,
      if (executionTimeMs != null) 'executionTimeMs': executionTimeMs,
    };
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'ExecutionResult[SUCCESS]:\n$stdout';
    } else {
      return 'ExecutionResult[ERROR]:\n$stderr';
    }
  }
}