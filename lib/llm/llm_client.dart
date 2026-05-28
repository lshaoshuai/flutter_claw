import '../models/message.dart';

/// LLM Client Abstract Interface
/// All Large Language Models (Gemini, OpenAI, Claude, etc.) integrated
/// into flutter_claw must implement this interface.
abstract class LLMClient {
  /// Default timeout for LLM API calls
  Duration get defaultTimeout => const Duration(seconds: 60);

  /// Initiates a multi-turn dialogue and returns the generated plain-text response.
  /// [messages] contains the context history and the current Prompt.
  Future<String> chat(List<Message> messages, {Duration? timeout});

  /// Forces the model to output data in JSON format.
  /// Typically used for RouterAgent dispatching or when requiring the
  /// model to output a structured configuration.
  Future<String> generateJson(String prompt, {Duration? timeout});

  /// Streaming chat: yields content chunks (deltas) as they arrive from
  /// the model.  Enables the agent to start executing side-effects (face
  /// changes, TTS, sandbox calls) BEFORE the full response has finished
  /// generating, dramatically improving perceived latency.
  ///
  /// Default implementation falls back to a single-shot [chat] call so
  /// providers that don't support real streaming still work — they just
  /// emit the whole response as one final chunk.  Override in concrete
  /// providers (e.g. OpenAI SSE) for true incremental delivery.
  Stream<String> streamChat(List<Message> messages, {Duration? timeout}) async* {
    yield await chat(messages, timeout: timeout);
  }

  /// Native tool-calling round.  Sends [messages] together with a [tools]
  /// array (use [SkillManager.toNativeTools] to build it) and returns
  /// whatever the model produced — final text, a list of tool invocations
  /// it wants run, or both.
  ///
  /// Caller drives the multi-turn loop:
  /// ```dart
  ///   var convo = [...history, Message.user(input)];
  ///   while (true) {
  ///     final turn = await client.chatWithTools(convo, tools);
  ///     if (!turn.hasToolCalls) return turn.content;
  ///     convo.add(Message.assistantToolCalls(turn.toolCalls, content: turn.content));
  ///     for (final c in turn.toolCalls) {
  ///       final args = jsonDecode(c.argumentsJson) as Map<String, dynamic>;
  ///       final result = await skillManager.invokeTool(c.name, args);
  ///       convo.add(Message.tool(toolCallId: c.id, content: result));
  ///     }
  ///   }
  /// ```
  ///
  /// Default implementation throws — providers that don't support native
  /// tool calling should rely on the JS-sandbox path instead.
  Future<ChatTurnResult> chatWithTools(
    List<Message> messages,
    List<Map<String, dynamic>> tools, {
    Duration? timeout,
  }) {
    throw UnsupportedError(
      'Provider does not implement native tool calling — use the JS-sandbox path.',
    );
  }
}
