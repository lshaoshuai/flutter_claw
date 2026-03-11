import 'dart:async';
import '../models/execution_result.dart';
import '../models/message.dart';
import '../models/task_config.dart';
import '../sandbox/js_runtime.dart';
import '../llm/llm_client.dart';
import '../utils/logger.dart';

/// Core Orchestration Brain: Responsible for intent understanding, code generation,
/// sandbox execution, and error-handling retries.
class ManagerAgent {
  final LLMClient llmClient;
  final ClawJSRuntime jsRuntime;

  /// Default task configuration used if no specific config is provided for a task.
  final TaskConfig defaultConfig;

  ManagerAgent({
    required this.llmClient,
    required this.jsRuntime,
    TaskConfig? defaultConfig,
  }) : defaultConfig =
           defaultConfig ?? TaskConfig(taskId: 'default_manager_task');

  /// Receives operational instructions and starts the processing flow.
  /// [config] optional task-specific configuration.
  Future<ExecutionResult> process(
    String instruction, {
    TaskConfig? config,
  }) async {
    final taskConfig = config ?? defaultConfig;
    Log.i('🧠 ManagerAgent received task [${taskConfig.taskId}]: $instruction');

    // 1. Check if sandbox is ready
    if (!jsRuntime.isInitialized) {
      Log.w('⚠️ Sandbox not initialized. Attempting automatic initialization...');
      try {
        await jsRuntime.initialize();
      } catch (e) {
        return ExecutionResult.error(
          'Failed to initialize sandbox automatically: $e',
        );
      }
    }

    // 2. Initialize conversation history (injecting the System Prompt)
    List<Message> conversation = [
      Message(role: 'system', content: buildSystemPrompt()),
      Message(role: 'user', content: instruction),
    ];

    int attempts = 0;
    final maxRetries = taskConfig.maxRetries;

    // 2. Start the self-correcting execution loop (The Agent Loop)
    while (attempts <= maxRetries) {
      if (attempts > 0) {
        Log.i(
          '🔄 Starting retry attempt #$attempts for planning and code generation...',
        );
      }
      attempts++;

      try {
        // Request LLM to generate JS code
        final llmResponse = await llmClient.chat(conversation);
        print('Raw Response: \n$llmResponse');

        // Extract and clean the code
        final rawJsCode = _extractJSCode(llmResponse);
        print('Extracted Code: \n[[$rawJsCode]]');

        final cleanJsCode = _sanitizeJsCode(rawJsCode);
        print('Final Execution Code: \n[[$cleanJsCode]]');

        if (cleanJsCode.isEmpty) {
          return ExecutionResult.error(
            'Agent failed to generate valid JavaScript code. Response: $llmResponse',
          );
        }

        print(
          '📦 Code generation complete. Pushing to Edge Sandbox for execution...',
        );

        // Execute code
        final result = await jsRuntime.evaluate(
          cleanJsCode,
          timeout: taskConfig.timeout,
        );

        // If execution is successful, return the result directly and break the loop
        if (result.isSuccess) {
          print('✅ Code executed successfully!');
          return result;
        } else {
          // ⚠️ Execution failed. Capture error info and prepare for LLM Debugging
          print('❌ Execution Error: ${result.stderr}');

          // Construct targeted error feedback
          String errorFeedback =
              'Your code encountered an error. Please fix it. Error log:\n${result.stderr}\n';

          // If the error is caused by full-width characters, provide a strong warning
          if (result.stderr.contains('Invalid character') ||
              result.stderr.contains('\uff01')) {
            errorFeedback +=
                '⚠️ Warning: Illegal full-width characters detected! Please ensure all punctuation (exclamation marks, semicolons, brackets, quotes, etc.) are strictly half-width English characters!\n';
          }

          errorFeedback +=
              'Please output the fixed code ONLY. No explanation needed.';

          // Append error info to history so the LLM knows what went wrong
          conversation.add(Message(role: 'assistant', content: llmResponse));
          conversation.add(Message(role: 'user', content: errorFeedback));
        }
      } catch (e, stacktrace) {
        Log.e('❌ Caught unhandled exception: $e', stackTrace: stacktrace);
        return ExecutionResult.error('Critical System Error: $e');
      }
    }

    // Maximum retries exceeded
    return ExecutionResult.error(
      'Task failed. Maximum retries reached ($maxRetries). Check logs for the final error.',
    );
  }

  /// Constructs a strictly enforced Sandbox System Prompt
  String buildSystemPrompt() {
    return '''
You are an advanced JavaScript (ES6) Data Analysis Expert running in a mobile sandbox environment.
Your task is to translate natural language user requirements into JS code and execute them automatically.

【Environmental Restrictions - EXTREMELY IMPORTANT】
1. You are NOT in a browser or Node.js! There is no `window`, `document`, `DOM`, `require`, or `import`.
2. You can ONLY use native ES6 syntax.
3. To return a final result, you MUST use the global function `Claw.finish(result)`. If this is not called, the system cannot retrieve your output.
4. You may use the following pre-injected global bridge methods:
   - `Claw.httpGet(url)`: Initiates a GET request and returns a string.
   - `Claw.readVFS(path)`: Reads data from the local Virtual File System.

【Coding Standards - ZERO ERROR TOLERANCE】
1. Strictly prohibit the use of full-width/Chinese punctuation (e.g., ！；，。《》【】（）“”‘’). All punctuation and symbols must be half-width English characters.
2. Always wrap your code in a markdown JS block, for example:
```javascript
const data = Claw.readVFS('/data.csv');
// Processing logic...
Claw.finish(result);
```
    ''';
  }

  /// Extracts the code block from the LLM's Markdown response
  String _extractJSCode(String text) {
    String cleaned = text.trim();

    // 1. Regex logic: Try to extract from Markdown code blocks
    // Using non-capturing group for language identifier to focus on content
    final RegExp codeBlockRegex = RegExp(
      r'```(?:javascript|js)?\s*([\s\S]*?)```',
      caseSensitive: false,
    );
    final allMatches = codeBlockRegex.allMatches(cleaned);

    if (allMatches.isNotEmpty) {
      // 🌟 IMPROVEMENT: If multiple blocks exist, we usually want the last one
      // (often the thinking/planning comes first, or a corrected version later)
      return allMatches.last.group(1)!.trim();
    }

    // 2. 🌟 ULTIMATE FALLBACK: Slice off stray "javascript" or "js" prefixes
    // This catches cases where the LLM didn't use backticks,
    // or put a newline before the language tag causing the regex to miss it.
    final lowerCleaned = cleaned.toLowerCase();
    if (lowerCleaned.startsWith('javascript')) {
      return cleaned.substring(10).trim();
    } else if (lowerCleaned.startsWith('js')) {
      return cleaned.substring(2).trim();
    }

    // 3. FINAL FALLBACK: If nothing else works, return the trimmed text itself
    // This handles raw code output without any markdown or prefixes.
    return cleaned;
  }

  /// Static Cleaning: Forcefully replace common full-width symbols as a last line of defense
  String _sanitizeJsCode(String code) {
    if (code.isEmpty) return '';

    return code
        .replaceAll('！', '!')
        .replaceAll('；', ';')
        .replaceAll('，', ',')
        .replaceAll('：', ':')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");
  }
}
