import 'dart:async';
import '../models/message.dart';
import '../models/execution_result.dart';
import '../llm/llm_client.dart';

/// Agent 的运行状态枚举
enum AgentStatus {
  idle,       // 空闲状态
  thinking,   // 思考中 (正在请求 LLM)
  executing,  // 执行中 (正在跑代码或调用工具)
  waitingForHuman, // 等待人类介入审批 (如: 准备发送群发邮件前)
  error,      // 运行出错
  completed   // 任务成功完成
}

/// 抽象基础 Agent 类
/// 所有的运营 Agent (无论是数据分析、还是内容生成) 都应该继承自此类
abstract class BaseAgent {
  /// 每个 Agent 必须有一个名字标识自己 (如 "Data Analyst Agent")
  final String name;

  /// 该 Agent 所属的领域 (如 "data_ops")
  final String roleDescription;

  /// 驱动该 Agent 思考的大脑 (LLM 客户端)
  final LLMClient llmClient;

  /// Agent 当前的状态 (供 UI 层监听并展示给用户看)
  AgentStatus _status = AgentStatus.idle;

  /// Agent 自身的长期记忆/对话历史 (用于维护多轮对话的上下文)
  final List<Message> _memory = [];

  /// 状态变更流 (供外部如 Flutter Bloc/Provider 监听，实现 UI 实时刷新)
  final StreamController<AgentStatus> _statusController = StreamController<AgentStatus>.broadcast();

  BaseAgent({
    required this.name,
    required this.roleDescription,
    required this.llmClient,
  });

  // ==========================================
  // 核心抽象方法：子类必须实现
  // ==========================================

  /// 子类必须实现的核心处理逻辑：Agent 收到任务后具体要怎么干活
  Future<ExecutionResult> processTask(String instruction);

  /// 子类必须实现的：构建该 Agent 独有的 System Prompt (人设与能力定义)
  String buildSystemPrompt();

  // ==========================================
  // 公共功能：子类直接复用
  // ==========================================

  /// 获取当前状态
  AgentStatus get status => _status;

  /// 监听状态变化 (UI 层用)
  Stream<AgentStatus> get statusStream => _statusController.stream;

  /// 供子类在执行过程中更新状态
  void updateStatus(AgentStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
      print('🤖 [$name] 状态变更为: ${newStatus.name}');
    }
  }

  /// 向该 Agent 的记忆池中添加对话上下文
  void addMemory(Message message) {
    _memory.add(message);
    // TODO(Optimization): 在这里可以引入一个滑动窗口机制，防止 _memory 撑爆 Token。
    // 如果 _memory 超过 20 条，强制裁剪最早的对话。
  }

  /// 获取完整的对话历史 (注入了 System Prompt)
  List<Message> getFullContext() {
    return [
      Message(role: 'system', content: buildSystemPrompt()),
      ..._memory
    ];
  }

  /// 清空该 Agent 的短期记忆
  void clearMemory() {
    _memory.clear();
    updateStatus(AgentStatus.idle);
    print('🧹 [$name] 记忆已清空，重置为空闲状态。');
  }

  /// 销毁 Agent (释放 Stream 资源)
  void dispose() {
    _statusController.close();
  }

  // ==========================================
  // 通用 LLM 交互封装：带有重试机制和状态扭转
  // ==========================================

  /// 发起一轮对话请求 (自动处理 thinking 状态和错误捕获)
  Future<String?> thinkAndRespond(List<Message> context, {int retries = 2}) async {
    updateStatus(AgentStatus.thinking);
    int attempts = 0;

    while (attempts < retries) {
      attempts++;
      try {
        final response = await llmClient.chat(context);
        updateStatus(AgentStatus.idle);
        return response;
      } catch (e) {
        print('⚠️ [$name] 请求大模型失败 (尝试 $attempts/$retries): $e');
        if (attempts >= retries) {
          updateStatus(AgentStatus.error);
          return null; // 彻底失败
        }
        // 指数退避重试 (简单的 2 秒延迟)
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return null;
  }
}