import 'package:flutter/material.dart';
import 'package:flutter_claw/llm/openai_provider.dart';
import 'package:get/get.dart';

// 引入你自己的核心库
import 'package:flutter_claw/flutter_claw.dart';

// 引入下一页
import 'chat_page.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final TextEditingController _apiKeyController = TextEditingController();

  // 默认选择的模型
  String _selectedModel = 'Gemini';

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _startChat() {
    final apiKey = _apiKeyController.text.trim();

    // 1. 校验 API Key (使用 Get.snackbar，无需 context)
    if (apiKey.isEmpty) {
      Get.snackbar(
        '⚠️ 缺少凭证',
        '请输入大模型的 API Key 才能唤醒 Agent',
        snackPosition: SnackPosition.top,
        backgroundColor: Colors.redAccent.withOpacity(0.8),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // 2. 根据用户的选择，初始化对应的 LLM 客户端
    LLMClient llmClient;
    if (_selectedModel == 'Gemini') {
      llmClient = GeminiProvider(
        apiKey: apiKey,
        // 如果你需要用特定的模型版本，可以在 Provider 里配置
      );
    } else {
      llmClient = OpenAIProvider(
        apiKey: apiKey,
        model: 'gpt-4o-mini', // 默认使用快速模型
      );
    }

    // 3. 极其优雅的 GetX 路由跳转，将实例化好的“大脑”传给聊天页
    Get.to(
      () => ChatPage(llmClient: llmClient),
      transition: Transition.rightToLeftWithFade, // 加一个炫酷的过场动画
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Agent Configuration'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部 LOGO 或 Icon
              const Icon(
                Icons.smart_toy_outlined,
                size: 100,
                color: Colors.deepPurpleAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'Claw OS Edge Sandbox',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // 模型选择下拉框
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: InputDecoration(
                  labelText: 'Select AI Engine',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.memory),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Gemini',
                    child: Text('Google Gemini (Recommended)'),
                  ),
                  DropdownMenuItem(
                    value: 'OpenAI',
                    child: Text('OpenAI GPT-4o'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedModel = val);
                  }
                },
              ),
              const SizedBox(height: 24),

              // API Key 输入框
              TextField(
                controller: _apiKeyController,
                obscureText: true, // 密码模式，隐藏输入的 Key
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                ),
                onSubmitted: (_) => _startChat(), // 按回车直接启动
              ),
              const SizedBox(height: 48),

              // 启动按钮
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                onPressed: _startChat,
                icon: const Icon(Icons.rocket_launch),
                label: const Text(
                  'Initialize Agent',
                  style: TextStyle(fontSize: 18, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
