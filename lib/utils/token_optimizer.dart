import '../models/message.dart';
import '../llm/llm_client.dart';

/// Token 优化器
/// 负责对长对话历史进行裁剪、压缩和总结，以最大程度节省大模型 API 调用的 Token 成本。
class TokenOptimizer {

  /// 简单的滑动窗口裁剪 (按消息数量和字符总长度限制)
  /// [memory] 当前 Agent 的对话记忆 (不包含 System Prompt)
  /// [maxKeepMessages] 最多保留最近的几条对话轮次 (防无限增长)
  /// [maxCharLimit] 粗略的字符总限制，如果超过则继续裁掉最老的消息
  static List<Message> applySlidingWindow(
      List<Message> memory, {
        int maxKeepMessages = 6,
        int maxCharLimit = 6000,
      }) {
    if (memory.isEmpty) return memory;

    List<Message> optimized = [];

    // 1. 数量裁剪：只保留最新的 maxKeepMessages 条记录
    if (memory.length > maxKeepMessages) {
      optimized = memory.sublist(memory.length - maxKeepMessages);
    } else {
      optimized = List.from(memory);
    }

    // 2. 长度裁剪：计算剩余消息的总字符数，超载则从旧到新移除
    int currentChars = optimized.fold(0, (sum, msg) => sum + msg.content.length);

    // 强制至少保留最后一条（通常是最新的报错或者用户最新需求）
    while (currentChars > maxCharLimit && optimized.length > 1) {
      final removedMsg = optimized.removeAt(0);
      currentChars -= removedMsg.content.length;
      print('✂️ [TokenOptimizer] 移除超长历史消息 (节省 ${removedMsg.content.length} chars)');
    }

    return optimized;
  }

  /// 智能上下文压缩 (调用廉价大模型进行历史对话总结)
  /// 当 Agent 发现记忆列表过长时，可调用此方法，将几十轮废话压缩为一小段核心记忆。
  /// [longHistory] 需要被压缩的冗长历史
  /// [fastClient] 传入一个廉价且速度快的模型实例 (如 Gemini 2.5 Flash)
  static Future<Message> summarizeHistory(
      List<Message> longHistory,
      LLMClient fastClient
      ) async {
    print('🧠 [TokenOptimizer] 正在触发历史智能压缩...');

    final historyText = longHistory.map((m) => '${m.role}: ${m.content}').join('\n---\n');

    final prompt = '''
请将以下冗长的多轮 Agent 对话历史压缩成一段 150 字以内的核心摘要。
你必须保留：
1. 已经成功获取的关键数据或业务参数。
2. 明确的最终结论。
3. 当前卡在哪里/下一步要做什么。

绝对不要输出废话，不要包含任何代码，只输出浓缩后的纯文本背景信息。

【对话历史】
$historyText
''';

    try {
      final summary = await fastClient.chat([Message.user(prompt)]);
      print('✅ [TokenOptimizer] 压缩完成，摘要: $summary');

      // 将总结后的内容作为一条 assistant 的记忆返回
      return Message(
          role: 'assistant',
          content: '[系统注入的历史摘要] $summary'
      );
    } catch (e) {
      print('⚠️ [TokenOptimizer] 历史总结请求失败，退回最后一条消息兜底: $e');
      // 容错机制：如果总结的 API 挂了，至少保留用户最后说的话
      return Message(
          role: 'assistant',
          content: '[摘要提取失败] 最后的上下文: ${longHistory.last.content}'
      );
    }
  }
}