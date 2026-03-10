import 'dart:async';
import '../models/execution_result.dart';
import '../models/task_config.dart';

/// Context environment for a single code execution
/// Responsible for managing the task lifecycle, timeout circuit breaking,
/// and collecting standard input/output (I/O) streams.
class ExecutionContext {
  /// Task configuration (includes timeout duration, retry strategies, etc.)
  final TaskConfig config;

  /// Records the timestamp when execution began
  final DateTime startTime;

  /// Used to asynchronously await JS code triggering Claw.finish() or throwing an exception
  final Completer<ExecutionResult> _completer = Completer<ExecutionResult>();

  /// Standard output buffer (e.g., intercepting JS console.log)
  final StringBuffer _stdoutBuffer = StringBuffer();

  /// Standard error buffer (e.g., intercepting JS console.error)
  final StringBuffer _stderrBuffer = StringBuffer();

  ExecutionContext(this.config) : startTime = DateTime.now();

  /// Retrieves the execution result Future with built-in timeout control
  Future<ExecutionResult> get future => _completer.future.timeout(
    config.timeout,
    onTimeout: () {
      // Trigger timeout circuit-breaker mechanism
      if (!_completer.isCompleted) {
        fail('Code execution timed out (${config.timeout.inSeconds}s) and was forcibly blocked by the system. This may be due to an infinite loop or excessive network wait.');
      }
      return _completer.future;
    },
  );

  /// Appends to standard output (Stdout)
  void appendStdout(String log) {
    _stdoutBuffer.writeln(log);
    // TODO: A Stream event could be emitted here to allow the Flutter UI
    // to display execution logs with a real-time typewriter effect.
  }

  /// Appends to error output (Stderr)
  void appendStderr(String error) {
    _stderrBuffer.writeln(error);
  }

  /// Successfully terminates execution (triggered by Claw.finish() on the JS side)
  void finish(String finalOutput) {
    if (!_completer.isCompleted) {
      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

      // Merge runtime console logs with the final result
      final fullOutput = _stdoutBuffer.isNotEmpty
          ? '${_stdoutBuffer.toString().trim()}\n$finalOutput'
          : finalOutput;

      _completer.complete(ExecutionResult.success(
        fullOutput,
        timeMs: executionTime,
      ));
    }
  }

  /// Terminates execution with an exception (triggered by active errors or crashes)
  void fail(String errorMsg) {
    if (!_completer.isCompleted) {
      final executionTime = DateTime.now().difference(startTime).inMilliseconds;

      // Merge runtime error logs with the final error message
      final fullError = _stderrBuffer.isNotEmpty
          ? '${_stderrBuffer.toString().trim()}\n$errorMsg'
          : errorMsg;

      _completer.complete(ExecutionResult.error(
        fullError,
        timeMs: executionTime,
      ));
    }
  }

  /// Indicates whether the execution has already completed
  bool get isCompleted => _completer.isCompleted;
}