import 'dart:async';
import 'dart:convert';
import 'package:flutter_js/flutter_js.dart';
import '../models/execution_result.dart';

/// Edge Sandbox 核心：基于 QuickJS 的本地 JavaScript 执行引擎
/// 负责隔离运行大模型生成的 JS 代码，并桥接原生能力。
class ClawJSRuntime {
  JavascriptRuntime? _runtime;

  /// 用于处理异步的 JS 执行。因为 Agent 的代码可能包含异步网络请求，
  /// 我们需要等待 JS 代码主动调用 `Claw.finish()` 才能拿到最终结果。
  Completer<ExecutionResult>? _executionCompleter;

  /// 初始化沙盒环境
  Future<void> initialize() async {
    // 拉起一个全新的 QuickJS 实例
    _runtime = getJavascriptRuntime();

    // 初始化全局的命名空间 Claw
    _runtime!.evaluate('var Claw = {};');

    // 注册核心的生命周期回调：Claw.finish
    // 当 LLM 跑完代码并得到最终业务结果时，必须调用此方法通知 Dart 层
    _runtime!.onMessage('Claw_finish', (dynamic args) {
      if (_executionCompleter != null && !_executionCompleter!.isCompleted) {
        // 解析传回来的结果 (args 通常是 JS 发送过来的数据)
        String finalOutput = '';
        if (args is List && args.isNotEmpty) {
          finalOutput = args.first.toString();
        } else {
          finalOutput = args.toString();
        }

        // 成功捕获结果，结束 Dart 层的等待
        _executionCompleter!.complete(ExecutionResult(
          isSuccess: true,
          stdout: finalOutput,
          stderr: '',
        ));
      }
    });

    // 在 JS 环境中注入 Claw.finish 的函数实现
    _runtime!.evaluate('''
      Claw.finish = function(result) {
        // 将复杂对象序列化为 JSON 字符串回传给 Dart
        var resultStr = typeof result === 'object' ? JSON.stringify(result) : String(result);
        sendMessage('Claw_finish', JSON.stringify([resultStr]));
      };
    ''');

    print('🛡️ Claw Edge Sandbox (QuickJS) 初始化完成。');
  }

  /// 供 BridgeRegistry 使用：将 Dart 函数注册到 JS 沙盒中
  /// [methodName] 在 JS 中调用的方法名，例如 'httpGet' -> 变成 `Claw.httpGet`
  /// [handler] Dart 层的处理函数
  void registerBridgeMethod(String methodName, dynamic Function(List<dynamic>) handler) {
    if (_runtime == null) throw Exception('沙盒未初始化');

    final channelName = 'Claw_$methodName';

    // 1. 注册 Dart 层的监听
    _runtime!.onMessage(channelName, (dynamic args) {
      try {
        // 将 JS 传过来的 JSON 字符串数组解析为 Dart 的 List
        List<dynamic> parsedArgs = [];
        if (args is List && args.isNotEmpty) {
          parsedArgs = jsonDecode(args.first.toString());
        }
        // 调用原生处理逻辑
        return handler(parsedArgs);
      } catch (e) {
        print('❌ Bridge 调用出错 [$methodName]: $e');
        return '{"error": "${e.toString()}"}';
      }
    });

    // 2. 在 JS 层注入对应的包装函数
    _runtime!.evaluate('''
      Claw.$methodName = function(...args) {
        // flutter_js 的 sendMessage 需要传递 channelName 和字符串参数
        var res = sendMessage('$channelName', JSON.stringify([JSON.stringify(args)]));
        try {
           return JSON.parse(res);
        } catch(e) {
           return res; // 如果不是 JSON 就返回原字符串
        }
      };
    ''');
  }

  /// 执行 LLM 生成的 JavaScript 代码
  /// 带有超时控制和异常捕获机制，防止恶意代码死循环卡死 App
  Future<ExecutionResult> evaluate(String jsCode, {Duration timeout = const Duration(seconds: 30)}) async {
    if (_runtime == null) {
      return ExecutionResult.error('沙盒未初始化，请先调用 initialize()');
    }

    _executionCompleter = Completer<ExecutionResult>();

    try {
      print('▶️ 开始在沙盒中执行代码...');

      // 1. 同步解析并执行代码
      final JsEvalResult evalResult = _runtime!.evaluate(jsCode);

      // 2. 检查是否有语法错误或同步运行时错误
      if (evalResult.isError) {
        return ExecutionResult.error('JS 代码运行报错: ${evalResult.stringResult}');
      }

      // 3. 开启超时等待
      // 因为真正的结果可能在异步回调中通过 Claw.finish() 传回来
      return await _executionCompleter!.future.timeout(timeout);

    } on TimeoutException {
      // 发生死循环或耗时过长，强行终止（在真正的生产环境中，建议直接 dispose 重建 runtime）
      return ExecutionResult.error('代码执行超时 (${timeout.inSeconds} 秒)，可能是死循环或网络请求过慢。');
    } catch (e) {
      return ExecutionResult.error('沙盒底层严重异常: $e');
    } finally {
      // 重置状态
      _executionCompleter = null;
    }
  }

  /// 释放 C/C++ 层的 JS 引擎内存
  /// 极度重要！在 App 退出或重置环境时必须调用，否则会导致严重内存泄漏
  void dispose() {
    _runtime?.dispose();
    _runtime = null;
    print('🧹 Claw Edge Sandbox 内存已释放。');
  }
}