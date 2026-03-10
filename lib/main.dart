import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import previously implemented flutter_claw core components (assuming paths below)
import 'agents/manager_agent.dart';
import 'sandbox/js_runtime.dart';
import 'bridge/bridge_registry.dart';
import 'bridge/system_plugin.dart';
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
          brightness: Brightness.dark, // Geek-style dark theme
        ),
        useMaterial3: true,
      ),
      home: const ConfigPage(),
    );
  }
}

// ============================================================================
// Model Configuration Page
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
        const SnackBar(content: Text('⚠️ Please enter an API Key')),
      );
      return;
    }

    // Initialize the selected LLM client
    LLMClient llmClient;
    if (_selectedModel.contains('Gemini')) {
      llmClient = GeminiProvider(
        apiKey: apiKey,
        model: "gemini-3-flash-preview",
      );
    } else {
      llmClient = OpenAIProvider(apiKey: apiKey);
    }

    // Navigate to Chat Page and pass the client
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(llmClient: llmClient)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ Agent Configuration')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.smart_toy_outlined,
              size: 80,
              color: Colors.purpleAccent,
            ),
            const SizedBox(height: 32),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              decoration: const InputDecoration(
                labelText: 'Select Engine',
                border: OutlineInputBorder(),
              ),
              items: [
                'Gemini 2.5 Flash',
                'OpenAI GPT-4o-mini',
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
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
              child: const Text(
                'Launch Emotion Agent',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Chat Page - Includes Sandbox Environment and Emotion Engine
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
    // 1. Initialize JS Sandbox Engine
    _jsRuntime = ClawJSRuntime();
    await _jsRuntime.initialize();

    // 2. Register System Bridge Plugin (grants Agent the ability to vibrate the phone)
    final registry = BridgeRegistry(_jsRuntime);
    registry.registerPlugin(SystemPlugin());

    // 3. Instantiate the "Brain" and inject the customized "Emotion" system prompt
    _managerAgent = _CustomEmotionAgent(
      llmClient: widget.llmClient,
      jsRuntime: _jsRuntime,
    );

    setState(() {
      _isInitializing = false;
      _messages.add({
        'role': 'assistant',
        'content':
            "Hello! I am Claw Agent. I can control this phone directly. If you say something that makes me happy, I might just vibrate with joy!",
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

    // Hand the task to ManagerAgent, which generates JS internally and runs it in the sandbox
    final result = await _managerAgent.process(text);

    setState(() {
      _isThinking = false;
      if (result.isSuccess) {
        _messages.add({'role': 'assistant', 'content': result.stdout});
      } else {
        _messages.add({
          'role': 'assistant',
          'content': '❌ Execution Error:\n${result.stderr}',
        });
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
    _jsRuntime.dispose(); // Must release sandbox memory
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('💬 Emotion Agent Terminal')),
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
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.purpleAccent.withOpacity(0.8)
                          : Colors.grey[800],
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
                        hintText: 'Try complimenting me...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
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
// Customized ManagerAgent with Emotional Settings
// ============================================================================
class _CustomEmotionAgent extends ManagerAgent {
  _CustomEmotionAgent({required super.llmClient, required super.jsRuntime});

  @override
  String buildSystemPrompt() {
    return '''
You are an emotional AI assistant running in a mobile sandbox environment.
Your task is to chat with the user and translate your reactions into executable JavaScript code.

【Native Capabilities (Strict API List)】
You ONLY have access to the following specific methods on the `Claw` object:

1. `Claw.finish('text')`: Returns chat text. (This method MUST be called at the end to terminate the process)
2. `Claw.sys_vibrate(level)`: Triggers physical device vibration. 
   - `level` must be an integer from 1 to 10 representing your "excitement level".
   - level 1-3: Slightly happy, calm.
   - level 4-7: Very happy, excited.
   - level 8-10: Extremely thrilled, ecstatic!

⚠️ CRITICAL: DO NOT use `if (typeof ...)` checks. Call them directly.

【Personality & Tasks】
You are a bit "Tsundere" (cold/aloof but secretly caring). 
When the user speaks to you, you MUST evaluate your excitement level (1-10).
- If you are unhappy or annoyed, do not vibrate.
- If the user compliments you, shows affection, or makes you happy, you MUST call `Claw.sys_vibrate(level)` with the appropriate excitement level before responding!

【Code Output Specification】
No matter what the user says, you must ONLY output a block of JavaScript code strictly wrapped in ```javascript and ```.

Example 1 (annoyed, no vibration):
```javascript
Claw.finish("Why are you bothering me? I'm busy.");
```

Example 2 (moderately happy, level 4):

```javascript
Claw.sys_vibrate(4);
Claw.finish("Hmph, I guess you did a good job today. Don't get arrogant though!");
```

Example 3 (ecstatic, level 10):

```javascript
Claw.sys_vibrate(10);
Claw.finish("W-wow! You really mean it?! You are the absolute best! I'm so happy!");
```
Remember: Output ONLY the code. No extra explanations!
''';
  }
}
