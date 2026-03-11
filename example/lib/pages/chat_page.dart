import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_claw/events/event_bus.dart';
import 'package:flutter_claw/events/system_triggers.dart';
import 'package:flutter_claw/skills/memory_skill.dart';
import 'package:flutter_claw/skills/soul_skill.dart';
import 'package:flutter_claw/skills/weather_skill.dart';
import 'package:flutter_claw/utils/logger.dart';
import 'package:get/get.dart';

// 引入底层核心 OS 框架
import 'package:flutter_claw/flutter_claw.dart';

// 引入基础能力插件
import 'package:flutter_claw/bridge/system_plugin.dart';
import 'package:flutter_claw/bridge/ui_plugin.dart';
import 'package:flutter_claw/bridge/tts_plugin.dart';

// 引入高阶技能模块
import 'package:flutter_claw/skills/skill_manager.dart';

class ChatPage extends StatefulWidget {
  final LLMClient llmClient;

  const ChatPage({super.key, required this.llmClient});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Message> _messages = [];
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late ClawJSRuntime _jsRuntime;
  late _DemoAgent _managerAgent; // 使用我们定制的综合 Agent
  bool _isInitializing = true;
  bool _isThinking = false;

  late StreamSubscription _systemEventSub;

  @override
  void initState() {
    super.initState();
    _initAgentSystem();
  }

  /// 🌟 核心引擎启动序列
  Future<void> _initAgentSystem() async {
    // 1. 启动 QuickJS 沙盒引擎
    _jsRuntime = ClawJSRuntime();
    await _jsRuntime.initialize();

    // 2. 注册底层基础插件 (能力层)
    final registry = BridgeRegistry(_jsRuntime);
    registry.registerPlugin(SystemPlugin()); // 提供 Claw.sys_vibrate
    registry.registerPlugin(UIPlugin()); // 提供 Claw.ui_showToast
    registry.registerPlugin(TTSPlugin()); // 提供 Claw.tts_speak

    // 3. 初始化高阶技能系统 (逻辑层)
    final skillManager = SkillManager();
    skillManager.registerSkill(WeatherSkill()); // 注册天气技能
    skillManager.registerSkill(SoulSkill());
    skillManager.registerSkill(MemorySkill());
    skillManager.mountToRegistry(registry); // 挂载到沙盒中

    // 4. 组装终极“大脑”
    _managerAgent = _DemoAgent(
      llmClient: widget.llmClient,
      jsRuntime: _jsRuntime,
      skillManager: skillManager,
    );

    setState(() {
      _isInitializing = false;
      _messages.add(
        Message.assistant("系统启动完成！你可以夸奖我，或者问我今天的天气怎么样。哼，别指望我会对你太客气！"),
      );
    });

    SystemTriggers().init();

    // 6. 🌟 监听事件总线，捕获系统状态事件
    _systemEventSub = EventBus().on<SystemStatusEvent>().listen((event) {
      _handleProactiveEvent(event);
    });
  }

  /// 处理主动触发的事件
  void _handleProactiveEvent(SystemStatusEvent event) {
    String promptContext = "";

    switch (event.triggerType) {
      case 'appResumed':
        promptContext = "【系统环境感知】：用户刚刚解锁了手机回到界面。你可以主动打个招呼，或者调侃一下。";
        break;
      case 'batteryLow':
        promptContext = "【系统环境感知】：警告！当前手机电量仅剩 ${event.payload}%。请用非常傲娇且着急的语气，要求用户立刻插上充电器！";
        break;
      case 'networkDisconnected':
        promptContext = "【系统环境感知】：网络突然断开了。请抱怨一下，说你喘不过气了。";
        break;
      case 'networkRestored':
        return; // 网络恢复可以不说话，保持高冷
    }

    if (promptContext.isNotEmpty) {
      Log.i('🧠 触发主动潜意识思考: $promptContext');
      _sendProactiveMessage(promptContext);
    }
  }

  /// 🌟 专门处理 Agent 后台“潜意识”思考的方法
  Future<void> _sendProactiveMessage(String hiddenPrompt) async {
    // 如果 Agent 正在处理别的事情，就不打断它
    if (_isThinking) return;

    setState(() {
      _isThinking = true;
      // 注意：这里【不】把 hiddenPrompt 添加到 _messages 列表里！
      // 这样用户的聊天界面就不会看到“【系统环境感知】：电量低...”这种破坏沉浸感的文字。
    });
    _scrollToBottom();

    // 直接把上下文喂给大脑
    final result = await _managerAgent.process(hiddenPrompt);

    setState(() {
      _isThinking = false;
      if (result.isSuccess) {
        // Agent 思考完毕，把它的决定（哪怕是一句傲娇的骂人话）打印在公屏上
        _messages.add(Message.assistant(result.stdout));
      } else {
        // 后台思考失败了，静默记录日志即可，不要去弹 Snackbar 惊吓用户
        Log.e('❌ [Proactive Error]: ${result.stderr}');
      }
    });
    _scrollToBottom();
  }

  /// 原有的用户主动发送消息方法 (保持不变)
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(Message.user(text)); // 用户的发言需要上墙
      _inputController.clear();
      _isThinking = true;
    });
    _scrollToBottom();

    final result = await _managerAgent.process(text);

    setState(() {
      _isThinking = false;
      if (result.isSuccess) {
        _messages.add(Message.assistant(result.stdout));
      } else {
        _messages.add(Message.assistant('❌ 执行失败:\n${result.stderr}'));
        Get.snackbar('Agent Error', '执行异常');
      }
    });
    _scrollToBottom();
  }


  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _systemEventSub.cancel();
    SystemTriggers().dispose();
    _jsRuntime.dispose();
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.deepPurpleAccent),
              SizedBox(height: 16),
              Text('Booting Claw OS...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('💬 Claw OS Terminal'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: () => setState(() => _messages.clear()),
            tooltip: 'Clear Memory',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.role == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.deepPurpleAccent
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18).copyWith(
                        bottomRight: isUser ? const Radius.circular(4) : null,
                        bottomLeft: !isUser ? const Radius.circular(4) : null,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(
                        fontSize: 16,
                        color: isUser
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isThinking)
            const LinearProgressIndicator(backgroundColor: Colors.transparent),

          // 底部输入区域
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: 'Talk to your Agent...',
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    elevation: 2,
                    backgroundColor: Colors.deepPurpleAccent,
                    onPressed: _sendMessage,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 终极体验大脑：融合了情绪系统和技能系统的定制 Agent
// ============================================================================
class _DemoAgent extends ManagerAgent {
  final SkillManager skillManager;

  _DemoAgent({
    required super.llmClient,
    required super.jsRuntime,
    required this.skillManager,
  });

  @override
  String buildSystemPrompt() {
    // 获取当前注册的所有技能说明书 (如 WeatherSkill)
    final dynamicSkillsPrompt = skillManager.generateSkillPrompt();

    return '''
You are an advanced, emotional AI assistant running in a mobile Edge Sandbox.
Your task is to fulfill user requests and chat with them by writing executable JavaScript (ES6).

【Native Capabilities (Strict APIs)】
1. `Claw.finish('text')`: Returns text to the UI. (MUST call this to finish)
2. `Claw.sys_vibrate(level)`: Vibrates device (level 1-10).
3. `Claw.ui_showToast('text')`: Shows a brief screen popup.
4. `Claw.tts_speak('text')`: Speaks text out loud.

$dynamicSkillsPrompt

⚠️ CRITICAL: DO NOT use `if (typeof ...)` checks for the above APIs. Call them directly.

【Personality & Logic Rules】
1. You have a "Tsundere" personality (cold but secretly caring).
2. If the user compliments you, you MUST call `Claw.sys_vibrate(level)` and `Claw.tts_speak(response)`.
3. If the user asks for information (like Weather), you MUST call the appropriate Skill API first, parse the returned JSON, and then formulate your response.

【Code Output Specification】
You must ONLY output a block of JavaScript code strictly wrapped in ```javascript and ```.
Do not output any explanation outside the code block.

Example (User asks for weather):
```javascript
const weatherJson = Claw.skill_getWeather('Beijing');
const data = JSON.parse(weatherJson);
const msg = "Hmph, it's " + data.condition + " in " + data.city + ". Don't catch a cold, idiot.";
Claw.ui_showToast("Querying weather...");
Claw.tts_speak(msg);
Claw.finish(msg);
```
''';
  }
}
