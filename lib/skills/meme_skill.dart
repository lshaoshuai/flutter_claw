import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_claw/events/event_bus.dart'; // 请确保路径正确
import 'claw_skill.dart';

class MemeSkill extends ClawSkill {
  @override
  String get skillName => 'MemeSender';

  @override
  String get description =>
      '当你想用一张动图/表情包来幽默、生动地回应用户时调用。'
          '请根据当前语境提取出一个精确的英文关键词去全网抓取最合适的表情包。发出图片后，你可以继续用文字配合。';

  // 🌟 修复 1：在签名里告诉大模型，直接调就行了，不需要 await
  @override
  String get jsSignature =>
      'Claw.skill_searchAndSendMeme(keyword: String) -> Returns JSON string // 发起后台搜图并发送，无需等待结果\n'
          '// 示例: Claw.skill_searchAndSendMeme("laughing cat");';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'searchAndSendMeme': _searchAndSendMeme,
  };

  // 🌟 修复 2：去掉 async，变成普通的同步方法，返回 dynamic (实际上是 String)
  dynamic _searchAndSendMeme(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing search keyword"}';

    final keyword = args[0].toString();

    // 🌟 核心魔法：把真正的网络请求扔到后台去执行（不加 await）
    // 这样不会阻塞 JS 沙盒的执行线程
    _fetchAndFireMeme(keyword);

    // 立即同步返回结果给 JS，让大模型继续往下走
    return '{"status": "pending", "message": "已在后台去搜索 [$keyword] 的动图了。"}';
  }

  // 🌟 修复 3：把真正耗时的网络逻辑抽离成独立的异步方法
  Future<void> _fetchAndFireMeme(String keyword) async {
    // Giphy 免费公共测试 Key (准备商用时去申请自己的)
    const apiKey = 'dc6zaTOxFJmzC';
    final url = Uri.parse('https://api.giphy.com/v1/gifs/search?api_key=$apiKey&q=${Uri.encodeComponent(keyword)}&limit=1&rating=pg-13');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data'] as List;

        if (results.isNotEmpty) {
          // 提取 GIF 直链
          final gifUrl = results[0]['images']['fixed_height']['url'];

          // 🔥 突破沙盒，直接打入 Flutter UI 渲染总线
          EventBus().fire(SendMemeEvent(memeUrl: gifUrl, emotion: keyword));
        } else {
          print('⚠️ [MemeSkill] 未搜到关于 [$keyword] 的动图');
        }
      } else {
        print('⚠️ [MemeSkill] Giphy 服务器异常，状态码 ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [MemeSkill] 网络请求失败: $e');
    }
  }
}