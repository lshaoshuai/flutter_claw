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
}