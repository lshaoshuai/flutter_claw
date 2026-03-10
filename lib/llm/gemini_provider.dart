import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'llm_client.dart';

/// Google Gemini 模型的具体实现
/// 推荐使用 gemini-2.5-flash-preview 或 gemini-1.5-flash，速度极快且成本低廉，非常适合做端侧 Agent 的大脑。
class GeminiProvider implements LLMClient {
  final String apiKey;
  final String model;

  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-2.5-flash', // 默认使用 flash 模型，速度最快
  });

  /// 构建 Gemini API 的 URL
  String get _baseUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

  @override
  Future<String> chat(List<Message> messages) async {
    return _callGeminiApi(messages, isJsonMode: false);
  }

  @override
  Future<String> generateJson(String prompt) async {
    // 将单一 prompt 包装为单轮对话，并开启 JSON 模式
    return _callGeminiApi([Message.user(prompt)], isJsonMode: true);
  }

  /// 核心的 Gemini API 调用逻辑
  Future<String> _callGeminiApi(List<Message> messages, {required bool isJsonMode}) async {
    // 1. 分离 System Prompt 和常规历史对话
    // Gemini 的 API 规范中，系统提示词需要单独放在 systemInstruction 字段
    String? systemInstruction;
    final List<Map<String, dynamic>> contents = [];

    for (var msg in messages) {
      if (msg.role == 'system') {
        systemInstruction = msg.content;
      } else {
        // Gemini 的角色定义：'user' 表示用户，'model' 表示 AI
        final role = msg.role == 'assistant' ? 'model' : 'user';
        contents.add({
          'role': role,
          'parts': [{'text': msg.content}]
        });
      }
    }

    // 2. 构建请求 Payload
    final Map<String, dynamic> payload = {
      'contents': contents,
    };

    // 注入 System Prompt
    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      payload['systemInstruction'] = {
        'parts': [{'text': systemInstruction}]
      };
    }

    // 开启 JSON 模式（要求 Gemini 返回结构化对象）
    if (isJsonMode) {
      payload['generationConfig'] = {
        'responseMimeType': 'application/json',
      };
    }

    // 3. 发送网络请求
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // 提取生成的文本内容
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'].toString();
          }
        }
        throw Exception('Gemini 响应格式异常: 无法提取文本内容');
      } else {
        throw Exception('Gemini API 错误 [${response.statusCode}]: ${response.body}');
      }
    } catch (e) {
      print('❌ [GeminiProvider] 调用模型失败: $e');
      rethrow;
    }
  }
}