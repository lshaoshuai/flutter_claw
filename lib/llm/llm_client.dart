import '../models/message.dart';

/// LLM 客户端抽象接口
/// 所有接入 flutter_claw 的大模型（Gemini, OpenAI, Claude 等）都必须实现此接口
abstract class LLMClient {
  /// 发起多轮对话，返回生成的纯文本回复
  /// [messages] 包含上下文历史和当前的 Prompt
  Future<String> chat(List<Message> messages);

  /// 强制模型输出 JSON 格式的数据
  /// 通常用于 RouterAgent 路由分发，或要求模型输出结构化配置时使用
  Future<String> generateJson(String prompt);
}