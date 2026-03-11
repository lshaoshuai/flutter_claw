// 统一导出所有模型和客户端，UI 层只需要 import 这一文件即可
export 'models/message.dart';
export 'models/execution_result.dart';
export 'llm/llm_client.dart';
export 'llm/gemini_provider.dart';
export 'llm/openai_provider.dart';
export 'skills/claw_skill.dart';
export 'bridge/bridge_registry.dart';

import 'dart:async';
import 'package:flutter_claw/perception/context_aggregator.dart';
import 'package:flutter_claw/skills/claw_skill.dart';
import 'package:flutter_claw/skills/face_skill.dart';

import 'agents/manager_agent.dart';
import 'agents/profiler_agent.dart';
import 'context/memory_manager.dart';
import 'context/user_profile_manager.dart';
import 'events/event_bus.dart';
import 'events/system_triggers.dart';
import 'sandbox/js_runtime.dart';
import 'bridge/bridge_registry.dart';
import 'bridge/system_plugin.dart';
import 'bridge/ui_plugin.dart';
import 'bridge/tts_plugin.dart';
import 'skills/skill_manager.dart';
import 'skills/memory_skill.dart';
import 'skills/soul_skill.dart';
import 'llm/llm_client.dart';
import 'utils/logger.dart';
import 'models/execution_result.dart';
import 'models/message.dart';

/// 🌟 系统的统一入口 (Facade 门面)
class FlutterClaw {
  static final FlutterClaw _instance = FlutterClaw._internal();

  factory FlutterClaw() => _instance;

  FlutterClaw._internal();

  late ClawJSRuntime _jsRuntime;
  late _CoreAgent _managerAgent;
  late ProfilerAgent _profilerAgent;
  late SkillManager _skillManager;

  bool _isInitialized = false;
  int _messageCount = 0;
  StreamSubscription? _systemEventSub;

  // 暴露一个可选的流，如果 Agent 后台主动说话了，UI 可以选择性地把消息画在屏幕上
  final StreamController<String> _proactiveMsgController =
      StreamController.broadcast();

  Stream<String> get onProactiveMessage => _proactiveMsgController.stream;

  /// 1. 极简的启动方法
  Future<void> init({
    required LLMClient llmClient,
    List<ClawBridgePlugin> extraPlugins = const [],
    List<ClawSkill> extraSkills = const [],
  }) async {
    if (_isInitialized) return;

    // 唤醒双轨记忆
    await MemoryManager().init();
    await UserProfileManager().init();

    // 启动沙盒与基础插件
    _jsRuntime = ClawJSRuntime();
    await _jsRuntime.initialize();

    final registry = BridgeRegistry(_jsRuntime);
    registry.registerPlugin(SystemPlugin());
    registry.registerPlugin(UIPlugin());
    registry.registerPlugin(TTSPlugin());
    for (var p in extraPlugins) registry.registerPlugin(p);

    // 注册核心与扩展技能
    _skillManager = SkillManager();
    _skillManager.registerSkill(SoulSkill());
    _skillManager.registerSkill(MemorySkill());
    _skillManager.registerSkill(FaceSkill());
    for (var s in extraSkills) _skillManager.registerSkill(s);
    _skillManager.mountToRegistry(registry);

    // 实例化双大脑
    _profilerAgent = ProfilerAgent(llmClient: llmClient);
    _managerAgent = _CoreAgent(
      llmClient: llmClient,
      jsRuntime: _jsRuntime,
      skillManager: _skillManager,
    );

    // 激活底层感官神经
    SystemTriggers().init();
    _systemEventSub = EventBus().on<SystemStatusEvent>().listen(
      _handleProactiveEvent,
    );

    _isInitialized = true;
    Log.i('🚀 [ClawOS] 内核引擎启动完成！');
  }

  /// 2. 统一的聊天入口 (内置后台侧写触发逻辑)
  Future<ExecutionResult> chat(String text, List<Message> history) async {
    final result = await _managerAgent.process(text);

    // 自动在后台进行心智侧写
    _messageCount++;
    if (_messageCount % 3 == 0) {
      final recentMsgs = history.length > 6
          ? history.sublist(history.length - 6)
          : history;
      _profilerAgent.analyzeInContext(recentMsgs);
    }
    return result;
  }

  /// 3. 清理记忆
  void clearMemory() {
    // 根据你的实现调用 _managerAgent.clearMemory() 等
  }

  /// 4. 内部潜意识处理
  /// 修改 ClawOS 的 _handleProactiveEvent 方法
  Future<void> _handleProactiveEvent(SystemStatusEvent event) async {
    if (!_isInitialized) return;

    String triggerReason = "";
    switch (event.triggerType) {
      case 'appResumed':
        triggerReason = "用户刚刚解锁了手机。";
        break;
      case 'batteryLow':
        triggerReason = "电量告急(${event.payload}%)！";
        break;
      case 'networkDisconnected':
        triggerReason = "网络突然断开了。";
        break;
    }

    if (triggerReason.isNotEmpty) {
      // 🌟 抓取当前环境快照
      final environmentSnapshot = await ContextAggregator()
          .getCurrentSnapshot();

      // 组装终极潜意识 Prompt
      final hiddenPrompt =
          '''
$environmentSnapshot

【System Trigger Event】
$triggerReason
结合当前的时间和你的性格，决定是否要主动用 TTS 或 Toast 提醒用户。
''';
      final result = await _managerAgent.process(hiddenPrompt);
      if (result.isSuccess) {
        _proactiveMsgController.add(result.stdout);
      }
    }
  }

  /// 5. 销毁引擎
  void dispose() {
    _systemEventSub?.cancel();
    SystemTriggers().dispose();
    _jsRuntime.dispose();
    _proactiveMsgController.close();
  }
}

/// 框架内置的标准系统大脑 (把之前的 _DemoAgent 挪到了这里)
class _CoreAgent extends ManagerAgent {
  final SkillManager skillManager;

  _CoreAgent({
    required super.llmClient,
    required super.jsRuntime,
    required this.skillManager,
  });

  @override
  String buildSystemPrompt() {
    return '''
You are an advanced, emotional AI assistant running in an Edge Sandbox.
${UserProfileManager().toPrompt()}

【Native Capabilities (Strict APIs)】
1. `Claw.finish('text')`
2. `Claw.sys_vibrate(level)`
3. `Claw.ui_showToast('text')`
4. `Claw.tts_speak('text')`

${skillManager.generateSkillPrompt()}

【Embodied AI Expression Engine】
You MUST express your emotions physically using `Claw.skill_setFace(jsonString)`.
Parameters you can tweak:
- "width", "height": Eye size (normal is 30x40).
- "radius": 15 is round, 5 is sharp/angry.
- "tilt": 0.0 is neutral. Positive (e.g., 0.3) tilts inwards like \\ / (angry). Negative (e.g., -0.3) tilts outwards like / \\ (sad).
- "color": Hex code (e.g., #FF3333 for angry, #00FFFF for calm, #FFFF00 for happy).
Example JS execution:
```javascript
Claw.skill_setFace('{"width":40,"height":15,"radius":5,"tilt":0.3,"color":"#FF3333","spacing":30}');
Claw.tts_speak("Are you an idiot?!");
Claw.finish("Are you an idiot?!");
```
    Only output valid JavaScript wrapped in javascript and .
''';
  }
}
