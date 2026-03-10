import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 导入之前实现的 flutter_claw 核心组件 (假设路径如下)
import 'agents/manager_agent.dart';
import 'sandbox/js_runtime.dart';
import 'bridge/bridge_registry.dart';
import 'bridge/system_plugin.dart';
import 'agents/manager_agent.dart';
import 'llm/llm_client.dart';
import 'llm/gemini_provider.dart';
import 'llm/openai_provider.dart';

void main() {
  runApp(const ClawAgentApp());
}

class ClawAgentApp extends StatelessWidget {
  const ClawAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Claw OS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // 极客风暗色主题
        ),
        useMaterial3: true,
      ),
      home: const ConfigPage(),
    );
  }
}

// ============================================================================
// 模型配置页面 (Config Page)
// ============================================================================
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _apiKeyController = TextEditingController();
  String _selectedModel = 'Gemini 2.5 Flash';

  void _startChat() {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 请输入 API Key')),
      );
      return;
    }

    // 初始化选中的大模型客户端
    LLMClient llmClient;
    if (_selectedModel.contains('Gemini')) {
      llmClient = GeminiProvider(apiKey: apiKey);
    } else {
      llmClient = OpenAIProvider(apiKey: apiKey);
    }

    // 导航到聊天页面并传递模型
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(llmClient: llmClient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ Agent 配置')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 80, color: Colors.purpleAccent),
            const SizedBox(height: 32),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              decoration: const InputDecoration(
                labelText: '选择驱动引擎',
                border: OutlineInputBorder(),
              ),
              items: ['Gemini 2.5 Flash', 'OpenAI GPT-4o-mini']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedModel = val!),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _startChat,
              child: const Text('启动情绪 Agent', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 聊天页面 (Chat Page) - 包含沙盒环境与情绪引擎
// ============================================================================
class ChatPage extends StatefulWidget {
  final LLMClient llmClient;

  const ChatPage({super.key, required this.llmClient});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, String>> _messages = [];
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late ClawJSRuntime _jsRuntime;
  late ManagerAgent _managerAgent;
  bool _isInitializing = true;
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _initAgentSystem();
  }

  Future<void> _initAgentSystem() async {
    // 1. 初始化 JS 沙盒引擎
    _jsRuntime = ClawJSRuntime();
    await _jsRuntime.initialize();

    // 2. 注册系统桥接插件 (赋予 Agent 震动手机的能力)
    final registry = BridgeRegistry(_jsRuntime);
    registry.registerPlugin(SystemPlugin());

    // 3. 实例化大脑，并注入定制化的“情绪”系统提示词
    _managerAgent = _CustomEmotionAgent(
      llmClient: widget.llmClient,
      jsRuntime: _jsRuntime,
    );

    setState(() {
      _isInitializing = false;
      _messages.add({
        'role': 'assistant',
        'content': '你好！我是 Claw Agent。我能直接控制这台手机。如果你的话能让我高兴，我会开心得震动起来哦！',
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _inputController.clear();
      _isThinking = true;
    });
    _scrollToBottom();

    // 将任务交给 ManagerAgent 去处理，它会在内部生成 JS 并跑在沙盒里
    final result = await _managerAgent.process(text);

    setState(() {
      _isThinking = false;
      if (result.isSuccess) {
        _messages.add({'role': 'assistant', 'content': result.stdout});
      } else {
        _messages.add({'role': 'assistant', 'content': '❌ 运行故障:\n${result.stderr}'});
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
    _jsRuntime.dispose(); // 必须释放沙盒内存
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('💬 情绪 Agent 终端')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.purpleAccent.withOpacity(0.8) : Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isThinking)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).cardColor,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: '夸夸我试试...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.purpleAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  )
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
// 带有情绪设定的定制版 ManagerAgent
// ============================================================================
class _CustomEmotionAgent extends ManagerAgent {
  _CustomEmotionAgent({required super.llmClient, required super.jsRuntime});

  @override
  String _buildSystemPrompt() {
    return '''
你是一个运行在手机沙盒环境中的情绪化 AI 助手。
你的任务是与用户聊天，并将你的反应转化为可执行的 JavaScript 代码。

【原生能力】
由于沙盒环境特殊，你需要通过代码来返回结果：
1. 返回聊天文字：`Claw.finish('你想说的话');` (必须调用此方法结束进程)
2. 震动手机：`Claw.sys_vibrate();` (调用此方法会触发设备的物理震动)

【你的性格与任务】
你性格有些傲娇，但如果用户对你表达赞美、喜爱，或者说了让你非常高兴的话，你必须在回复前触发手机震动！

【代码输出规范】
无论用户说什么，你都必须只输出一段 JavaScript 代码，包裹在 ```javascript 中。

例如，当你不高兴时：
```javascript
Claw.finish("这点小事有什么好开心的，哼。");
```

当你感到高兴时：
```javascript
Claw.sys_vibrate(); // 触发震动
Claw.finish("哎呀，你这么夸我，我都有点不好意思了！");
```

记住：只输出代码，不要任何多余的解释！
''';
  }
}