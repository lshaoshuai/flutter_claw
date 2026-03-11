import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// 向量记忆单元数据模型
class VectorMemory {
  final String id;
  final String text; // 记忆的原始文本
  final List<double> vector; // 文本对应的多维向量
  final int timestamp;

  VectorMemory({
    required this.id,
    required this.text,
    required this.vector,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'vector': vector,
    'timestamp': timestamp,
  };

  factory VectorMemory.fromJson(Map<String, dynamic> json) {
    return VectorMemory(
      id: json['id'],
      text: json['text'],
      vector: List<double>.from(json['vector'].map((x) => x.toDouble())),
      timestamp: json['timestamp'],
    );
  }
}

/// 纯 Dart 实现的轻量级本地向量数据库
class VectorStore {
  static final VectorStore _instance = VectorStore._internal();
  factory VectorStore() => _instance;
  VectorStore._internal();

  static const String _prefsKey = 'agent_vector_memories';
  List<VectorMemory> _memories = [];
  bool _isInitialized = false;

  /// 🌟 1. 初始化并加载本地硬盘中的向量数据
  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_prefsKey);

    if (jsonString != null) {
      final List<dynamic> decodedList = json.decode(jsonString);
      _memories = decodedList.map((item) => VectorMemory.fromJson(item)).toList();
    }

    _isInitialized = true;
    Log.i('🌌 [VectorStore] 向量数据库已挂载，当前包含 ${_memories.length} 条高维记忆片段。');
  }

  /// 🌟 2. 存储新的记忆向量
  Future<void> addMemory(String text, List<double> vector) async {
    final newMemory = VectorMemory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      vector: vector,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _memories.add(newMemory);
    await _saveToDisk();
    Log.i('💾 [VectorStore] 写入新的向量记忆: $text');
  }

  /// 🌟 3. 语义搜索 (核心 RAG 逻辑：找到最相似的 Top-K 记忆)
  List<String> search(List<double> queryVector, {int topK = 3}) {
    if (_memories.isEmpty) return [];

    // 计算所有记忆与当前 Query 向量的相似度得分
    List<Map<String, dynamic>> scoredMemories = [];
    for (var memory in _memories) {
      double score = _cosineSimilarity(queryVector, memory.vector);
      scoredMemories.add({
        'text': memory.text,
        'score': score,
      });
    }

    // 按相似度从高到低排序
    scoredMemories.sort((a, b) => b['score'].compareTo(a['score']));

    // 提取 Top K，且只返回相似度大于一定阈值的记忆 (比如 0.7)
    List<String> results = [];
    for (int i = 0; i < min(topK, scoredMemories.length); i++) {
      if (scoredMemories[i]['score'] > 0.70) {
        results.add(scoredMemories[i]['text']);
      }
    }

    return results;
  }

  /// 🌟 4. 纯 Dart 实现的数学引擎：余弦相似度计算
  /// 公式: A·B / (||A|| * ||B||)
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += pow(a[i], 2);
      normB += pow(b[i], 2);
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// 将内存中的向量数组刷入磁盘
  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(_memories.map((m) => m.toJson()).toList());
    await prefs.setString(_prefsKey, jsonString);
  }

  /// 清空记忆库
  Future<void> clearAll() async {
    _memories.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    Log.i('🧹 [VectorStore] 向量记忆库已被物理清空');
  }
}