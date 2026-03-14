import '../models/message.dart';
import '../llm/llm_client.dart';
import 'logger.dart';

/// Token Optimizer
/// Responsible for pruning, compressing, and summarizing long conversation histories
/// to maximize Token cost savings for LLM API calls.
class TokenOptimizer {

  /// Simple Sliding Window Pruning (limits by message count and total character length)
  /// [memory] The current Agent's conversation memory (excluding the System Prompt).
  /// [maxKeepMessages] Maximum number of recent conversation turns to keep (prevents infinite growth).
  /// [maxCharLimit] Rough total character limit; older messages are dropped if exceeded.
  static List<Message> applySlidingWindow(
      List<Message> memory, {
        int maxKeepMessages = 6,
        int maxCharLimit = 6000,
      }) {
    if (memory.isEmpty) return memory;

    List<Message> optimized = [];

    // 1. Count-based Pruning: Retain only the most recent maxKeepMessages records.
    if (memory.length > maxKeepMessages) {
      optimized = memory.sublist(memory.length - maxKeepMessages);
    } else {
      optimized = List.from(memory);
    }

    // 2. Length-based Pruning: Calculate total characters; remove oldest to newest if overloaded.
    int currentChars = optimized.fold(0, (sum, msg) => sum + msg.content.length);

    // Ensure at least the last message is kept (usually the latest error or user requirement).
    while (currentChars > maxCharLimit && optimized.length > 1) {
      final removedMsg = optimized.removeAt(0);
      currentChars -= removedMsg.content.length;
      Log.i('✂️ [TokenOptimizer] Pruning excessive history (saved ${removedMsg.content.length} chars)');
    }

    return optimized;
  }

  /// Intelligent Context Compression (calls a cheap LLM to summarize history)
  /// Can be triggered when the memory list grows too long, compressing dozens of
  /// turns into a concise core memory.
  /// [longHistory] The verbose history to be compressed.
  /// [fastClient] An instance of a cheap and fast model (e.g., Gemini 2.5 Flash).
  static Future<Message> summarizeHistory(
      List<Message> longHistory,
      LLMClient fastClient
      ) async {
    Log.i('🧠 [TokenOptimizer] Triggering intelligent history compression...');

    final historyText = longHistory.map((m) => '${m.role}: ${m.content}').join('\n---\n');

    final prompt = '''
Please compress the following verbose multi-turn Agent conversation history into a core summary of under 150 words.
You MUST preserve:
1. Key data or business parameters successfully retrieved.
2. Explicit final conclusions.
3. Current bottlenecks or next steps.

Strictly avoid filler text. Do not include code. Output only the condensed plain-text background information.

【Conversation History】
$historyText
''';

    try {
      final summary = await fastClient.chat([Message.user(prompt)]);
      Log.i('✅ [TokenOptimizer] Compression complete. Summary: $summary');

      // Return the summarized content as an assistant memory entry
      return Message(
          role: 'assistant',
          content: '[System-injected History Summary] $summary'
      );
    } catch (e) {
      Log.e('⚠️ [TokenOptimizer] History summarization request failed; falling back to last message: $e');
      // Fallback mechanism: If the summarization API fails, at least retain the user's last input.
      return Message(
          role: 'assistant',
          content: '[Summary Extraction Failed] Final context: ${longHistory.last.content}'
      );
    }
  }
}