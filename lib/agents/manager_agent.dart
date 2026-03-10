import 'dart:async';
import '../models/execution_result.dart';
import '../models/message.dart';
import '../sandbox/js_runtime.dart';
import '../llm/llm_client.dart';

/// 核心调度大脑：负责理解意图、生成代码、执行沙盒并处理报错重试
class ManagerAgent {
  final LLMClient llmClient;
  final ClawJSRuntime jsRuntime;

  // 最大重试次数，防止 Agent 陷入死循环浪费 Token
  final int maxRetries;

  ManagerAgent({
    required this.llmClient,
    required this.jsRuntime,
    this.maxRetries = 3,
  });

  /// 接收运营指令并开始处理流
  Future<ExecutionResult> process(String instruction) async {
    print('🧠 ManagerAgent 收到任务: $instruction');

    // 1. 初始化对话历史 (注入 System Prompt)
    List<Message> conversation = [
      Message(role: 'system', content: _buildSystemPrompt()),
      Message(role: 'user', content: instruction),
    ];

    int attempts = 0;

    // 2. 开启自纠错执行循环 (The Agent Loop)
    while (attempts < maxRetries) {
      attempts++;
      print('🔄 开始第 $attempts 次尝试规划和生成代码...');

      try {
        // 请求 LLM 生成 JS 代码
        final llmResponse = await llmClient.chat(conversation);
        final jsCode = _extractJSCode(llmResponse);

        if (jsCode.isEmpty) {
          return ExecutionResult.error(
            'Agent 未能生成有效的 JavaScript 代码。响应: $llmResponse',
          );
        }

        print('📦 代码生成完毕，准备推入 Edge Sandbox 执行...');

        // 执行代码
        final result = await jsRuntime.evaluate(jsCode);

        // 如果执行成功，直接返回结果，跳出循环
        if (result.isSuccess) {
          print('✅ 代码执行成功！');
          // 可选：将最终的 stdout 再次发给 LLM，让它总结成人类可读的话术
          // 这里为了极致节省 Token，直接返回沙盒结果
          return result;
        } else {
          // ⚠️ 执行失败，捕获报错信息，准备让 LLM Debug
          print('❌ 执行报错: ${result.stderr}');

          // 将报错信息追加到对话历史中，让 LLM 知道它刚才错在哪了
          conversation.add(Message(role: 'assistant', content: llmResponse));
          conversation.add(
            Message(
              role: 'user',
              content:
                  '你的代码报错了，请修复。错误日志如下:\n${result.stderr}\n请只输出修复后的代码，不要解释。',
            ),
          );
        }
      } catch (e) {
        return ExecutionResult.error('系统严重异常: $e');
      }
    }

    // 超过最大重试次数
    return ExecutionResult.error('任务失败，已达到最大重试次数 ($maxRetries)。最后一次报错请查看日志。');
  }

  /// 构建极其严格的沙盒系统提示词 (System Prompt)
  /// 决定了 Agent 输出代码的质量和安全性
  String _buildSystemPrompt() {
    return '''
你是一个运行在移动端沙盒中的高级 JavaScript (ES6) 数据分析专家。
你的任务是将用户的自然语言需求转化为 JS 代码并自动执行。

【环境限制 - 极度重要】
1. 你不在浏览器里，也不在 Node.js 里！没有 `window`, `document`, `DOM`，也没有 `require` 或 `import`。
2. 你只能使用原生 ES6 语法。
3. 如果你需要返回最终结果，请使用全局函数 `Claw.finish(result)`。如果不调用此函数，系统将无法获取你的执行结果。
4. 你可以使用以下预先注入的全局桥接函数 (Bridge Methods)：
   - `Claw.httpGet(url)`: 发起 GET 请求，返回字符串。
   - `Claw.readVFS(path)`: 读取本地虚拟文件系统的数据。

【输出规范】
请始终将你的代码包裹在 markdown 的 js 代码块中，例如：
```javascript
const data = Claw.readVFS('/data.csv');
// 处理逻辑...
Claw.finish(result);
    ''';
  }

  /// 从 LLM 的 Markdown 回复中提取代码块
  String _extractJSCode(String text) {
    final RegExp codeBlockRegex = RegExp(r'javascript|js)?\n([\s\S]*?)```');
    final match = codeBlockRegex.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!.trim();
    }
    // 如果 LLM 不听话没有用 markdown 包裹，尝试直接返回原文
    return text.trim();
  }
}
