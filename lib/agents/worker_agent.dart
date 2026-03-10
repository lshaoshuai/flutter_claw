import 'dart:async';
import '../models/message.dart';
import '../models/execution_result.dart';
import '../llm/llm_client.dart';
import 'base_agent.dart';

/// 具体的执行者 Agent (Worker)
/// 这是一个通用的 Worker 类，可以通过注入不同的 System Prompt
/// 让它扮演不同的专业角色（如：文案生成员、SQL 编写者、数据分析助手）。
class WorkerAgent extends BaseAgent {
  /// 该 Worker 专属的系统提示词（人设与核心约束）
  final String _customSystemPrompt;

  WorkerAgent({
    required super.name,
    required super.roleDescription,
    required super.llmClient,
    required String customSystemPrompt,
  }) : _customSystemPrompt = customSystemPrompt;

  @override
  String buildSystemPrompt() {
    // 直接返回初始化时注入的专属提示词
    return _customSystemPrompt;
  }

  @override
  Future<ExecutionResult> processTask(String instruction) async {
    print('👷 [$name] 开始处理任务: $instruction');

    // 1. 将用户的新指令记录到该 Worker 的短期记忆中
    addMemory(Message(role: 'user', content: instruction));

    // 2. 带着完整的上下文（System Prompt + 历史对话）去请求大模型
    // thinkAndRespond 是在 BaseAgent 中封装好的带有重试机制的方法
    final response = await thinkAndRespond(getFullContext());

    // 3. 错误处理：如果多次重试依然失败
    if (response == null || response.isEmpty) {
      return ExecutionResult.error('[$name] 响应失败，可能是网络问题或 Token 超限。');
    }

    // 4. 将 Agent 成功生成的回复也加入记忆，形成完整的上下文闭环
    addMemory(Message(role: 'assistant', content: response));

    print('✅ [$name] 任务处理完成。');

    // 5. 将结果包装为统一的 ExecutionResult 返回
    // 注意：WorkerAgent 主要负责生成文本（如纯文案、分析报告或提供代码片段）。
    // 实际的代码执行 (Evaluate JS) 动作，通常由更上层的 ManagerAgent 调度沙盒完成。
    return ExecutionResult(
      isSuccess: true,
      stdout: response, // 把生成的文本作为标准输出返回
      stderr: '',
    );
  }

  /// 工厂方法：快速创建一个内容运营专员
  static WorkerAgent createContentOpsWorker(LLMClient client) {
    return WorkerAgent(
      name: 'Content Ops Expert',
      roleDescription: 'content_ops',
      llmClient: client,
      customSystemPrompt: '''
你是一个资深的内容运营专家。你的目标是根据用户提供的数据或背景，
撰写高质量、高转化率的营销文案（如小红书笔记、微信推文、邮件营销等）。
要求：语言生动，自带 Emoji，结构清晰。
''',
    );
  }

  /// 工厂方法：快速创建一个数据解释员
  static WorkerAgent createDataInterpreterWorker(LLMClient client) {
    return WorkerAgent(
      name: 'Data Interpreter',
      roleDescription: 'data_analysis',
      llmClient: client,
      customSystemPrompt: '''
你是一个数据解释专家。Manager Agent 会把沙盒执行代码后得到的冰冷数字或 JSON 抛给你。
你的任务是把这些枯燥的数据，翻译成老板或业务人员能一眼看懂的“业务洞察”和“行动建议”。
不要输出任何代码，只输出分析报告。
''',
    );
  }
}