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
  }) : defaultConfig = defaultConfig ?? TaskConfig(taskId: 'default_manager_task');

  /// Receives operational instructions and starts the processing flow.
  /// [config] optional task-specific configuration.
  Future<ExecutionResult> process(String instruction, {TaskConfig? config}) async {
    final taskConfig = config ?? defaultConfig;
    Log.i('🧠 ManagerAgent received task [${taskConfig.taskId}]: $instruction');

    // 1. Initialize conversation history (injecting the System Prompt)
    List<Message> conversation = [
      Message(role: 'system', content: _buildSystemPrompt()),
      Message(role: 'user', content: instruction),
    ];

    int attempts = 0;
    final maxRetries = taskConfig.maxRetries;

    // 2. Start the self-correcting execution loop (The Agent Loop)
    while (attempts <= maxRetries) {
      if (attempts > 0) {
        Log.i('🔄 Starting retry attempt #$attempts for planning and code generation...');
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
        final result = await jsRuntime.evaluate(cleanJsCode, timeout: taskConfig.timeout);

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
  String _buildSystemPrompt() {
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
    // Regex logic:
    // 1. Matches the start of a markdown code block ``` optionally followed by js/javascript
    // 2. Captures all content until the closing ```
    final RegExp codeBlockRegex = RegExp(
      r'```(?:javascript|js)?\s*([\s\S]*?)```',
      caseSensitive: false,
    );
    final match = codeBlockRegex.firstMatch(text);

    if (match != null && match.groupCount >= 1) {
      return match.group(1)!.trim();
    }
    return text.trim();
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
