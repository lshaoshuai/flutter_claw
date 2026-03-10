/// 🦀 Flutter Claw: A Lightweight, Edge-Computing Agent OS & Local Sandbox for Flutter.
library flutter_claw;

// ============================================================================
// 1. Core Exports - Determines which classes are accessible to external users
// ============================================================================

// Export Data Models (Users need these to construct requests and receive results)
export 'models/task_config.dart';
export 'models/execution_result.dart';
export 'models/message.dart';

// Export Agent Core (Allows advanced users to inherit from base classes to build custom Agents)
export 'agents/base_agent.dart';
export 'agents/manager_agent.dart';
export 'agents/worker_agent.dart';

// Export Low-level Control (Allows registering custom Dart functions for the JS engine to call)
export 'bridge/bridge_registry.dart';
export 'sandbox/js_runtime.dart';

// Export LLM Interface (Allows users to inject different model providers)
export 'llm/llm_client.dart';
export 'llm/gemini_provider.dart';

// ============================================================================
// 2. Core Facade Class - Provides a simplified entry point for initialization and calls
// ============================================================================

import 'package:flutter_claw/utils/logger.dart';
import 'models/execution_result.dart';
import 'agents/manager_agent.dart';
import 'models/task_config.dart';
import 'sandbox/js_runtime.dart';
import 'llm/llm_client.dart';
import 'bridge/bridge_registry.dart';

class FlutterClaw {
  // Singleton pattern ensures a single global Agent OS orchestration center for the entire App
  static final FlutterClaw _instance = FlutterClaw._internal();

  factory FlutterClaw() => _instance;

  FlutterClaw._internal();

  late ManagerAgent _managerAgent;
  late ClawJSRuntime _jsRuntime;
  bool _isInitialized = false;

  /// Initializes the Agent OS environment
  /// [llmClient]: Inject your encapsulated Large Language Model client
  /// [defaultConfig]: The default task configuration
  /// [customBridges]: If you need to inject custom native methods (e.g., operating a specific local DB), pass them here
  Future<void> init({
    required LLMClient llmClient,
    TaskConfig? defaultConfig,
    List<ClawBridgePlugin>? customBridges,
  }) async {
    if (_isInitialized) return;

    final config = defaultConfig ?? TaskConfig(taskId: 'flutter_claw_system');

    // 1. Initialize the JS Sandbox engine (QuickJS)
    _jsRuntime = ClawJSRuntime();
    await _jsRuntime.initialize();

    // 2. Register core native capabilities (Network, Storage, etc.)
    final registry = BridgeRegistry(_jsRuntime);
    registry.registerDefaultPlugins(config);

    // Register custom business plugins
    if (customBridges != null) {
      for (var bridge in customBridges) {
        registry.registerPlugin(bridge);
      }
    }

    // 3. Initialize the Orchestrator Agent (The Brain)
    _managerAgent = ManagerAgent(
      llmClient: llmClient,
      jsRuntime: _jsRuntime,
      defaultConfig: config,
    );

    _isInitialized = true;
    Log.i('🦀 FlutterClaw OS Initialized Successfully.');
  }

  /// Submits an operational task to the Agent OS
  /// Example: "Fetch the local user_data.csv, calculate yesterday's DAU, and return it."
  Future<ExecutionResult> executeTask(String instruction, {TaskConfig? config}) async {
    if (!_isInitialized) {
      throw Exception('FlutterClaw is not initialized. Call init() first.');
    }

    // Dispatch the task to the Manager Agent for routing, code generation, and local execution
    return await _managerAgent.process(instruction, config: config);
  }

  /// Releases low-level C++ / JS engine memory to prevent memory leaks
  void dispose() {
    _jsRuntime.dispose();
    _isInitialized = false;
  }
}