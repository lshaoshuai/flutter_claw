/// 🦀 Flutter Claw: A Lightweight, Edge-Computing Agent OS & Local Sandbox for Flutter.
library flutter_claw;

// ============================================================================
// 1. 核心导出 (Exports) - 决定了外部库能 import 哪些类
// ============================================================================

// 导出数据模型 (外部需要用这些类来构造请求和接收结果)
export 'models/task_config.dart';
export 'models/execution_result.dart';
export 'models/message.dart';

// 导出 Agent 核心 (允许高阶用户自己继承基类手搓 Agent)
export 'agents/base_agent.dart';
export 'agents/manager_agent.dart';
export 'agents/worker_agent.dart';

// 导出底层控制 (允许外部注册自定义的 Dart 函数给 JS 引擎调用)
export 'bridge/bridge_registry.dart';
export 'sandbox/js_runtime.dart';

// 导出 LLM 接口 (允许外部传入不同的模型提供商)
export 'llm/llm_client.dart';
export 'llm/gemini_provider.dart';

// ============================================================================
// 2. 核心门面类 (Facade) - 提供极简的初始化和调用入口
// ============================================================================

import 'package:flutter_claw/utils/logger.dart';

import 'models/execution_result.dart';
import 'agents/manager_agent.dart';
import 'models/task_config.dart';
import 'sandbox/js_runtime.dart';
import 'llm/llm_client.dart';
import 'bridge/bridge_registry.dart';

class FlutterClaw {
  // 单例模式，确保整个 App 只有一个全局的 Agent OS 调度中心
  static final FlutterClaw _instance = FlutterClaw._internal();

  factory FlutterClaw() => _instance;

  FlutterClaw._internal();

  late ManagerAgent _managerAgent;
  late ClawJSRuntime _jsRuntime;
  bool _isInitialized = false;

  /// 初始化 Agent OS 环境
  /// [llmClient] 注入你封装好的大模型请求客户端
  /// [defaultConfig] 默认的任务配置
  /// [customBridges] 如果你需要注入自定义的原生方法（如操作特定的本地数据库），在这里传入
  Future<void> init({
    required LLMClient llmClient,
    TaskConfig? defaultConfig,
    List<ClawBridgePlugin>? customBridges,
  }) async {
    if (_isInitialized) return;

    final config = defaultConfig ?? TaskConfig(taskId: 'flutter_claw_system');

    // 1. 初始化 JS 沙盒引擎 (QuickJS)
    _jsRuntime = ClawJSRuntime();
    await _jsRuntime.initialize();

    // 2. 注册基础原生能力 (网络、存储等)
    final registry = BridgeRegistry(_jsRuntime);
    registry.registerDefaultPlugins(config);

    // 注册业务方自定义的插件
    if (customBridges != null) {
      for (var bridge in customBridges) {
        registry.registerPlugin(bridge);
      }
    }

    // 3. 初始化主控 Agent (大脑)
    _managerAgent = ManagerAgent(
      llmClient: llmClient,
      jsRuntime: _jsRuntime,
      defaultConfig: config,
    );

    _isInitialized = true;
    Log.i('🦀 FlutterClaw OS Initialized Successfully.');
  }

  /// 提交一个运营任务给 Agent OS
  /// 例如: "去拉取一下本地 user_data.csv，计算昨天的 DAU 并返回"
  Future<ExecutionResult> executeTask(String instruction, {TaskConfig? config}) async {
    if (!_isInitialized) {
      throw Exception('FlutterClaw is not initialized. Call init() first.');
    }

    // 把任务丢给 Manager Agent 进行路由、代码生成和本地执行
    return await _managerAgent.process(instruction, config: config);
  }

  /// 释放底层 C++ / JS 引擎内存，防止内存泄漏
  void dispose() {
    _jsRuntime.dispose();
    _isInitialized = false;
  }
}
