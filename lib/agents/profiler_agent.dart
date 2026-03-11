import 'dart:convert';
import '../llm/llm_client.dart';
import '../models/message.dart';
import '../utils/logger.dart';
import '../context/user_profile_manager.dart';

/// 潜伏在后台的画像分析员
class ProfilerAgent {
  final LLMClient llmClient;

  ProfilerAgent({required this.llmClient});

  /// 传入最近的对话记录进行分析
  Future<void> analyzeInContext(List<Message> recentChatHistory) async {
    if (recentChatHistory.isEmpty) return;

    Log.i('🕵️ [ProfilerAgent] 开始在后台对用户进行心理侧写...');

    // 提取聊天记录纯文本
    final chatText = recentChatHistory
        .where((m) => m.role != 'system')
        .map((m) => "${m.role == 'user' ? 'User' : 'Agent'}: ${m.content}")
        .join('\n');

    // 构造极度严格的分析 Prompt
    final prompt =
        '''
You are a psychological profiler AI running in the background.
Analyze the following conversation between a User and an Agent.
Extract the User's core persona traits.

Must output ONLY a valid JSON object with the following keys. If you cannot deduce a key, omit it.
- "occupation": The user's job or main activity.
- "interests": Hobbies, technical stacks, or topics they like.
- "communication_style": How they talk (e.g., formal, casual, impatient, analytical).
- "emotional_state": Their current general mood.

[Conversation Log]
$chatText

Output ONLY JSON. No markdown, no explanations.
''';

    try {
      final response = await llmClient.chat([Message.user(prompt)]);

      // 🌟 清洗返回的 JSON (大模型有时候还是会带上 ```json ```)
      String cleanJson = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      // 解析并存入硬盘
      final Map<String, dynamic> parsedData = json.decode(cleanJson);
      final Map<String, String> stringTraits = parsedData.map(
        (k, v) => MapEntry(k, v.toString()),
      );

      await UserProfileManager().updateTraits(stringTraits);
    } catch (e) {
      Log.e('❌ [ProfilerAgent] 画像分析失败 (可能 JSON 格式错误): $e');
    }
  }
}
