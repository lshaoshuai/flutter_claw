import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../utils/logger.dart';
import 'llm_client.dart';

/// Concrete implementation of the Google Gemini model.
/// Recommended to use gemini-2.5-flash-preview or gemini-1.5-flash for their
/// exceptional speed and low cost—ideal for on-device Agent brains.
class GeminiProvider implements LLMClient {
  final String apiKey;
  final String model;

  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-2.5-flash', // Defaults to the Flash model for maximum speed
  });

  @override
  Duration get defaultTimeout => const Duration(seconds: 30);

  /// Constructs the Gemini API URL
  String get _baseUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

  @override
  Future<String> chat(List<Message> messages, {Duration? timeout}) async {
    return _callGeminiApi(messages, isJsonMode: false, timeout: timeout);
  }

  @override
  Future<String> generateJson(String prompt, {Duration? timeout}) async {
    // Wraps a single prompt into a single-turn conversation and enables JSON mode
    return _callGeminiApi([Message.user(prompt)], isJsonMode: true, timeout: timeout);
  }

  /// Core Gemini API calling logic
  Future<String> _callGeminiApi(List<Message> messages,
      {required bool isJsonMode, Duration? timeout}) async {
    // 1. Separate System Prompt from regular conversation history.
    // In Gemini's API specification, the system prompt must be placed
    // in the 'systemInstruction' field separately.
    String? systemInstruction;
    final List<Map<String, dynamic>> contents = [];

    for (var msg in messages) {
      if (msg.role == 'system') {
        systemInstruction = msg.content;
      } else {
        // Gemini role definitions: 'user' for user, 'model' for AI
        final role = msg.role == 'assistant' ? 'model' : 'user';
        contents.add({
          'role': role,
          'parts': [{'text': msg.content}]
        });
      }
    }

    // 2. Build the request Payload
    final Map<String, dynamic> payload = {
      'contents': contents,
    };

    // Inject System Prompt
    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      payload['systemInstruction'] = {
        'parts': [{'text': systemInstruction}]
      };
    }

    // Enable JSON mode (requires Gemini to return a structured object)
    if (isJsonMode) {
      payload['generationConfig'] = {
        'responseMimeType': 'application/json',
      };
    }

    // 3. Send the network request
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(timeout ?? defaultTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Extract the generated text content
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'].toString();
          }
        }
        throw Exception('Gemini response format error: Unable to extract text content');
      } else {
        throw Exception('Gemini API Error [${response.statusCode}]: ${response.body}');
      }
    } catch (e) {
      Log.e('❌ [GeminiProvider] Model call failed: $e');
      rethrow;
    }
  }

  /// Gemini doesn't ship a clean SSE delta stream out of the box (its
  /// "streamGenerateContent" returns a JSON array stream).  For now we
  /// fall back to non-streaming — yields the full response as a single
  /// chunk so the streaming caller keeps working with no observable change.
  /// TODO: implement real Gemini SSE if/when needed.
  @override
  Stream<String> streamChat(List<Message> messages, {Duration? timeout}) async* {
    yield await chat(messages, timeout: timeout);
  }

  /// Gemini's native function-calling lives at a different endpoint
  /// (`generateContent` with `tools: [{functionDeclarations: [...]}]`) and
  /// returns `functionCall` parts instead of OpenAI-style `tool_calls`.
  /// Wiring that adapter is doable but out of scope for the initial native
  /// tool-calls rollout — we deliberately throw so [AgentRuntime] catches
  /// the error and falls back to the JS-sandbox path on this provider.
  @override
  Future<ChatTurnResult> chatWithTools(
    List<Message> messages,
    List<Map<String, dynamic>> tools, {
    Duration? timeout,
  }) {
    throw UnsupportedError(
      'GeminiProvider does not yet implement native tool calling — '
      'runtime will fall back to the JS-sandbox path automatically.',
    );
  }
}