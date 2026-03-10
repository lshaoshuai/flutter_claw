import 'dart:convert';
import '../models/message.dart';
import '../llm/llm_client.dart';

/// 任务难度枚举
enum TaskDifficulty {
  /// 等级 1: 简单查询、格式转换、明确的 API 调用 (适合极速/廉价模型，如 Gemini Flash)
  level1_simple,

  /// 等级 2: 数据分析、需要编写简单逻辑代码、文案生成 (适合中等模型，如 GPT-4o-mini 或 Claude Haiku)
  level2_moderate,

  /// 等级 3: 复杂的跨表关联分析、深度的战略规划、复杂的代码 Debug (适合高级模型，如 GPT-4o 或 Claude 3.5 Sonnet)
  level3_complex,

  /// 未知难度，默认按中等处理
  unknown
}

/// 领域标签枚举 (用于分发给特定的领域 Agent 或加载特定的 SOP)
enum DomainTag {
  data_analysis, // 数据分析 (CSV/Excel 处理、SQL 生成)
  content_ops,   // 内容运营 (文案生成、SEO、社交媒体)
  user_ops,      // 用户运营 (CRM 查询、邮件发送)
  general_qa     // 通用问答 (不需要执行代码)
}

/// 路由决策结果
class RouteDecision {
  final TaskDifficulty difficulty;
  final DomainTag domain;
  final String reasoning; // 模型做出此决定的理由 (用于 Debug 或记录)

  RouteDecision({
    required this.difficulty,
    required this.domain,
    required this.reasoning,
  });

  factory RouteDecision.fromJson(Map<String, dynamic> json) {
    return RouteDecision(
      difficulty: _parseDifficulty(json['difficulty']),
      domain: _parseDomain(json['domain']),
      reasoning: json['reasoning'] ?? 'No reasoning provided.',
    );
  }

  static TaskDifficulty _parseDifficulty(String? value) {
    switch (value?.toLowerCase()) {
      case 'level1': return TaskDifficulty.level1_simple;
      case 'level2': return TaskDifficulty.level2_moderate;
      case 'level3': return TaskDifficulty.level3_complex;
      default: return TaskDifficulty.unknown;
    }
  }

  static DomainTag _parseDomain(String? value) {
    switch (value?.toLowerCase()) {
      case 'data': return DomainTag.data_analysis;
      case 'content': return DomainTag.content_ops;
      case 'user': return DomainTag.user_ops;
      default: return DomainTag.general_qa;
    }
  }

  @override
  String toString() {
    return 'RouteDecision(Difficulty: $difficulty, Domain: $domain, Reasoning: $reasoning)';
  }
}

/// 路由 Agent (分诊台)：负责解析用户意图并进行难度/领域定级
class RouterAgent {
  // Router Agent 必须使用最快、最便宜的模型 (如 Gemini Flash)，因为它只做选择题，不干重活
  final LLMClient fastLlmClient;

  RouterAgent({required this.fastLlmClient});

  /// 分析用户指令，返回路由决策
  Future<RouteDecision> analyzeTask(String userInstruction) async {
    print('🚦 RouterAgent 正在分析任务复杂度...');

    final prompt = _buildRoutingPrompt(userInstruction);

    try {
      // 强制模型输出 JSON 格式
      final responseText = await fastLlmClient.generateJson(prompt);
      final jsonMap = jsonDecode(responseText);

      final decision = RouteDecision.fromJson(jsonMap);
      print('🧭 路由决策完成: $decision');
      return decision;
    } catch (e) {
      print('⚠️ RouterAgent 分析失败，退回默认中等难度路由: $e');
      // 容错机制：如果解析失败，默认走中等难度的数据分析流
      return RouteDecision(
          difficulty: TaskDifficulty.level2_moderate,
          domain: DomainTag.data_analysis,
          reasoning: 'Fallback due to parsing error.'
      );
    }
  }

  /// 构建路由专用的 System Prompt
  /// 这个 Prompt 非常关键，它定义了系统如何判断一个任务到底是“简单”还是“复杂”
  String _buildRoutingPrompt(String instruction) {
    return '''
你是一个高级运营多 Agent 系统的“前台调度员 (Router)”。
你的唯一工作是分析用户的自然语言需求，评估其难度，并打上合适的领域标签。

【评估标准 - 难度 (difficulty)】
- "level1" (简单): 不需要复杂的逻辑推理，不需要写很长的代码。例如："帮我查一下昨天某篇文章的阅读量"、"把这段文字转成 Markdown 格式"、"调用发邮件的 API"。
- "level2" (中等): 需要编写中等长度的脚本处理数据，或进行常规的文案创作。例如："读取本地的 sales.csv，算出客单价并画个柱状图"、"根据这份产品文档写一篇公众号推文"。
- "level3" (复杂): 需要深度思考、多步推理、跨越多个数据源，或编写复杂的分析算法。例如："结合上周的用户流失数据和竞品的降价策略，写一份挽回用户的行动方案并在本地跑出预测模型"。

【评估标准 - 领域 (domain)】
- "data": 明显涉及数字、表格(CSV/Excel)、报表、统计计算。
- "content": 涉及写文章、翻译、润色、社交媒体文案。
- "user": 涉及查用户信息、发消息、客服工单、用户画像打标签。
- "general": 其他纯文本问答，不需要调用本地沙盒环境。

【用户需求】
"$instruction"

【输出要求】
你必须且只能输出一个合法的 JSON 对象，不要输出任何 Markdown 标记 (如 ```json) 或其他废话。
格式如下：
{
  "difficulty": "level1" | "level2" | "level3",
  "domain": "data" | "content" | "user" | "general",
  "reasoning": "一句话解释你为什么这么分类"
}
''';
  }
}