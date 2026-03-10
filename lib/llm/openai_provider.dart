import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'llm_client.dart';

/// OpenAI 模型的具体实现
/// 支持 GPT-4o, GPT-4o-mini 等模型，可无缝接入 flutter_claw 路由系统。
class OpenAIProvider implements LLMClient {
  final String apiKey;
  final String model;

  /// 允许自定义 Base URL，方便接入各类国内代理或私有化部署的兼容 API（如 OneAPI）
  final String baseUrl;

  OpenAIProvider({
    required this.apiKey,
    this.model = 'gpt-4o-mini', // 默认使用较快且便宜的模型，适合多数常规任务
    this.baseUrl = 'https://api.openai.com/v1',
  });

  @override
  Duration get defaultTimeout => const Duration(seconds: 45);

  @override
  Future<String> chat(List<Message> messages, {Duration? timeout}) async {
    return _callOpenAIApi(messages, isJsonMode: false, timeout: timeout);
  }

  @override
  Future<String> generateJson(String prompt, {Duration? timeout}) async {
    // 💡 OpenAI API 强制要求：如果开启了 json_object 模式，
    // 系统提示词或用户提示词中必须显式要求模型输出 JSON。
    final messages = [
      Message.system('You are a helpful assistant designed to output JSON.'),
      Message.user(prompt)
    ];
    return _callOpenAIApi(messages, isJsonMode: true, timeout: timeout);
  }

  /// 核心的 OpenAI API 调用逻辑
  Future<String> _callOpenAIApi(List<Message> messages,
      {required bool isJsonMode, Duration? timeout}) async {
    final url = Uri.parse('$baseUrl/chat/completions');

    // 1. 转换 Message 为 OpenAI API 需要的格式
    // OpenAI 的 Role 定义非常标准：'system', 'user', 'assistant'，与我们的 Message 模型完美契合
    final List<Map<String, String>> formattedMessages = messages.map((msg) {
      return {
        'role': msg.role,
        'content': msg.content,
      };
    }).toList();

    // 2. 构建请求 Payload
    final Map<String, dynamic> payload = {
      'model': model,
      'messages': formattedMessages,
      // 可以在此处添加额外的参数，如 temperature 调节发散度
      'temperature': 0.2,
    };

    // 开启强制 JSON 输出模式
    if (isJsonMode) {
      payload['response_format'] = {'type': 'json_object'};
    }

    // 3. 发送网络请求
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(payload),
      ).timeout(timeout ?? defaultTimeout);

      // 处理中文字符编码问题 (UTF-8)
      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(responseBody);

        // 提取生成的文本内容
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'];
          if (message != null && message['content'] != null) {
            return message['content'].toString();
          }
        }
        throw Exception('OpenAI 响应格式异常: 无法提取文本内容');
      } else {
        throw Exception('OpenAI API 错误 [${response.statusCode}]: $responseBody');
      }
    } catch (e) {
      print('❌ [OpenAIProvider] 调用模型失败: $e');
      rethrow;
    }
  }
}