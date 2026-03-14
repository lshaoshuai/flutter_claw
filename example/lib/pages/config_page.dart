import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🌟 引入 shared_preferences

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

  // 存储用的 Keys
  static const String _prefsKeyModel = 'saved_llm_model';
  static const String _prefsKeyApiKey = 'saved_api_key';

  @override
  void initState() {
    super.initState();
    _loadSavedConfig(); // 🌟 页面启动时，自动读取本地保存的配置
  }

  /// 🌟 从本地磁盘加载上次的配置
  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModel = prefs.getString(_prefsKeyModel);
    final savedApiKey = prefs.getString(_prefsKeyApiKey);

    // 如果组件还没被销毁，则更新 UI
    if (mounted) {
      setState(() {
        if (savedModel != null && (savedModel == 'Gemini' || savedModel == 'OpenAI')) {
          _selectedModel = savedModel;
        }
        if (savedApiKey != null) {
          _apiKeyController.text = savedApiKey;
        }
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  /// 🌟 注意这里加上了 async，因为保存硬盘是异步操作
  Future<void> _startChat() async {
    final apiKey = _apiKeyController.text.trim();

    // 1. 校验 API Key
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

    // 🌟 2. 校验通过！把当前的模型和 Key 存进硬盘
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyModel, _selectedModel);
    await prefs.setString(_prefsKeyApiKey, apiKey);

    // 3. 根据用户的选择，初始化对应的 LLM 客户端
    LLMClient llmClient;
    if (_selectedModel == 'Gemini') {
      llmClient = GeminiProvider(
        apiKey: apiKey,
      );
    } else {
      llmClient = OpenAIProvider(
        apiKey: apiKey,
        model: 'gpt-4o-mini', // 默认使用快速模型
      );
    }

    // 4. 极其优雅的 GetX 路由跳转
    Get.to(
          () => ChatPage(llmClient: llmClient),
      transition: Transition.rightToLeftWithFade,
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
                isExpanded: true,
                initialValue: _selectedModel,
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
                    child: Text(
                      'Google Gemini (Recommended)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'OpenAI',
                    child: Text(
                      'OpenAI GPT-4o',
                      overflow: TextOverflow.ellipsis,
                    ),
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