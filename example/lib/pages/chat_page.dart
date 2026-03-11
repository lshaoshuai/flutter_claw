import 'package:flutter/material.dart';
import 'package:flutter_claw/ui/widgets/claw_avatar.dart';
import 'package:get/get.dart';

// 🌟 只需引入这一个文件！
import 'package:flutter_claw/flutter_claw.dart';

// 如果你想额外注入天气技能，再引一下你的业务技能：
import 'package:flutter_claw/skills/weather_skill.dart';

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

  bool _isInitializing = true;
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    // 🌟 1. 一行代码，唤醒整个 OS！
    await FlutterClaw().init(
      llmClient: widget.llmClient,
      extraSkills: [WeatherSkill()], // 业务端想插什么技能就传什么
    );

    // 🌟 2. 监听 Agent 的后台主动插话 (可选)
    FlutterClaw().onProactiveMessage.listen((msgText) {
      if (mounted) {
        setState(() => _messages.add(Message.assistant(msgText)));
        _scrollToBottom();
      }
    });

    setState(() {
      _isInitializing = false;
      _messages.add(Message.assistant("系统启动完成！哼，找我干嘛？"));
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(Message.user(text));
      _inputController.clear();
      _isThinking = true;
    });
    _scrollToBottom();

    // 🌟 3. 极简的调用方式，自动处理后台侧写
    final result = await FlutterClaw().chat(text, _messages);

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
    // 🌟 4. 一键销毁
    FlutterClaw().dispose();
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
          const ClawAvatar(),
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
