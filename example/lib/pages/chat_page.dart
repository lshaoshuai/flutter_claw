import 'dart:async'; // 🌟 1. 新增引入：用于 StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter_claw/events/event_bus.dart';
import 'package:flutter_claw/ui/widgets/claw_avatar.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import 'package:flutter_claw/flutter_claw.dart';
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
  bool _hasInputText = false;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  late StreamSubscription _memeSub; // 🌟 2. 新增：表情包事件的监听器

  @override
  void initState() {
    super.initState();
    _initEngine();
    _initSpeech();

    _inputController.addListener(() {
      setState(() {
        _hasInputText = _inputController.text.trim().isNotEmpty;
      });
    });

    // 🌟 3. 新增：监听 Agent 发来的表情包事件
    _memeSub = EventBus().on<SendMemeEvent>().listen((event) {
      if (mounted) {
        setState(() {
          // 为了让 UI 知道这是一个表情包，我们给文字加上特殊的隐式标签 [MEME_URL:xxx]
          _messages.add(Message.assistant('[MEME_URL:${event.memeUrl}]'));
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (val) => debugPrint('Speech Error: ${val.errorMsg}'),
      onStatus: (val) => debugPrint('Speech Status: $val'),
    );
    setState(() {});
  }

  Future<void> _initEngine() async {
    await FlutterClaw().init(
      llmClient: widget.llmClient,
      // 注意：MemeSkill 应该已经在 FlutterClaw.init 内部注册了，
      // 如果没有，你可以在这里的 extraSkills 里加上 MemeSkill()
      extraSkills: [WeatherSkill()],
    );

    FlutterClaw().onProactiveMessage.listen((msgText) {
      if (mounted) {
        setState(() => _messages.add(Message.assistant(msgText)));
        _scrollToBottom();
      }
    });

    setState(() {
      _isInitializing = false;
      _messages.add(Message.assistant("系统启动完成！视觉与听觉模块已就绪。"));
    });
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    _inputController.clear();
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'zh_CN',
      onSoundLevelChange: (level) {
        EventBus().fire(ListeningLevelEvent(level));
      },
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
    EventBus().fire(ListeningLevelEvent(0.0));
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _inputController.text = result.recognizedWords;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
    });

    if (result.finalResult) {
      setState(() {
        _isListening = false;
      });
      EventBus().fire(ListeningLevelEvent(0.0));
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isThinking) return;

    if (_isListening) _stopListening();

    setState(() {
      _messages.add(Message.user(text));
      _inputController.clear();
      _isThinking = true;
    });

    FocusScope.of(context).unfocus();
    _scrollToBottom();

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
    _speechToText.cancel();
    _memeSub.cancel(); // 🌟 4. 新增：销毁表情包监听，防止内存泄漏
    FlutterClaw().dispose();
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

                // ==========================================================
                // 🌟 5. 核心修改：气泡内容渲染器 (拦截表情包 URL 并渲染图片)
                // ==========================================================
                Widget messageContent;
                bool isMeme = msg.content.startsWith('[MEME_URL:') && msg.content.endsWith(']');

                if (isMeme) {
                  // 提取 URL
                  final url = msg.content.substring(10, msg.content.length - 1);
                  messageContent = ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: 200,
                      fit: BoxFit.cover,
                      // 添加一个极客风的加载占位符
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 200, height: 150,
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.cyanAccent),
                          ),
                        );
                      },
                      errorBuilder: (ctx, error, stackTrace) => const SizedBox(
                        width: 200, height: 150,
                        child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
                  );
                } else {
                  // 普通文本
                  messageContent = Text(
                    msg.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  );
                }

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: isMeme ? EdgeInsets.zero : const EdgeInsets.all(14), // 图片不需要内边距
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      // 表情包不需要背景色，纯图片更好看；文字才需要背景色
                      color: isMeme
                          ? Colors.transparent
                          : (isUser ? Colors.deepPurpleAccent : Theme.of(context).colorScheme.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: messageContent,
                  ),
                );
              },
            ),
          ),
          if (_isThinking)
            const LinearProgressIndicator(backgroundColor: Colors.transparent),

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
                        hintText: _isListening ? '正在倾听...' : 'Talk to your Agent...',
                        filled: true,
                        fillColor: _isListening
                            ? Colors.deepPurpleAccent.withOpacity(0.1)
                            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        suffixIcon: (_hasInputText || _isListening)
                            ? IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.grey),
                          onPressed: () {
                            _inputController.clear();
                            if (_isListening) _stopListening();
                            FocusScope.of(context).unfocus();
                          },
                        )
                            : null,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: _isListening
                        ? _stopListening
                        : (_hasInputText ? _sendMessage : _startListening),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isListening
                            ? Colors.redAccent
                            : (_hasInputText ? Colors.deepPurpleAccent : Colors.grey[800]),
                        shape: BoxShape.circle,
                        boxShadow: _isListening
                            ? [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                            : null,
                      ),
                      child: Icon(
                        _isListening
                            ? Icons.stop
                            : (_hasInputText ? Icons.send : Icons.mic),
                        color: Colors.white,
                      ),
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