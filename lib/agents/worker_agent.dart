import 'dart:async';
import '../models/message.dart';
import '../models/execution_result.dart';
import '../llm/llm_client.dart';
import 'base_agent.dart';

/// Concrete Execution Agent (Worker)
/// This is a generic Worker class that can play different professional roles
/// (e.g., Copywriter, SQL Writer, Data Analysis Assistant) by injecting
/// different System Prompts.
class WorkerAgent extends BaseAgent {
  /// The specific system prompt for this Worker (Persona and core constraints)
  final String _customSystemPrompt;

  WorkerAgent({
    required super.name,
    required super.roleDescription,
    required super.llmClient,
    required String customSystemPrompt,
  }) : _customSystemPrompt = customSystemPrompt;

  @override
  String buildSystemPrompt() {
    // Directly returns the specific prompt injected during initialization
    return _customSystemPrompt;
  }

  @override
  Future<ExecutionResult> processTask(String instruction) async {
    print('👷 [$name] Beginning task processing: $instruction');

    // 1. Record the user's new instruction into the Worker's short-term memory
    addMemory(Message(role: 'user', content: instruction));

    // 2. Request the LLM with the full context (System Prompt + Conversation History)
    // 'thinkAndRespond' is a method encapsulated in BaseAgent with a built-in retry mechanism.
    final response = await thinkAndRespond(getFullContext());

    // 3. Error Handling: If multiple retries still result in failure
    if (response == null || response.isEmpty) {
      return ExecutionResult.error('[$name] Response failed, possibly due to network issues or Token limit exhaustion.');
    }

    // 4. Add the successfully generated response back into memory to create a complete context closure
    addMemory(Message(role: 'assistant', content: response));

    print('✅ [$name] Task processing completed.');

    // 5. Wrap the result as a unified ExecutionResult and return it
    // Note: WorkerAgent is primarily responsible for generating text (e.g., copy, analysis reports, or code snippets).
    // The actual code execution (Evaluating JS) is typically managed by the higher-level ManagerAgent via the sandbox.
    return ExecutionResult(
      isSuccess: true,
      stdout: response, // Returns the generated text as standard output (stdout)
      stderr: '',
    );
  }

  /// Factory Method: Quickly create a Content Operations Expert
  static WorkerAgent createContentOpsWorker(LLMClient client) {
    return WorkerAgent(
      name: 'Content Ops Expert',
      roleDescription: 'content_ops',
      llmClient: client,
      customSystemPrompt: '''
You are a senior Content Operations Expert. Your goal is to write high-quality, high-conversion marketing copy 
(such as social media posts, WeChat articles, email marketing, etc.) based on the data or background provided by the user.
Requirements: Use vivid language, include Emojis, and maintain a clear structure.
''',
    );
  }

  /// Factory Method: Quickly create a Data Interpreter
  static WorkerAgent createDataInterpreterWorker(LLMClient client) {
    return WorkerAgent(
      name: 'Data Interpreter',
      roleDescription: 'data_analysis',
      llmClient: client,
      customSystemPrompt: '''
You are a Data Interpretation Expert. The Manager Agent will pass you "cold" numbers or JSON resulting from sandbox code execution.
Your task is to translate this dry data into "Actionable Business Insights" and "Strategic Recommendations" 
that a boss or business stakeholder can understand at a glance.
Do not output any code—only output the analysis report.
''',
    );
  }
}