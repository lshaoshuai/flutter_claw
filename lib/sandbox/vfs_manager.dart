import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 虚拟文件系统 (VFS) 管理器
/// 负责为 Agent 提供一个安全的、隔离的本地工作目录。
/// 严格防止路径越权 (Path Traversal) 攻击。
class VFSManager {
  late Directory _workspaceDir;
  bool _isInitialized = false;

  /// 初始化 VFS
  /// 在 App 的文档目录下创建一个专属的 Agent 工作区
  /// [workspaceName] 可以根据任务 ID 动态指定，实现多任务隔离
  Future<void> initialize({String workspaceName = 'agent_workspace'}) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _workspaceDir = Directory(p.join(appDocDir.path, workspaceName));

    if (!await _workspaceDir.exists()) {
      await _workspaceDir.create(recursive: true);
    }
    _isInitialized = true;
    print('📁 VFS 工作区初始化完成: ${_workspaceDir.path}');
  }

  /// 核心安全护城河：将 Agent 传入的相对路径解析为安全的绝对路径
  /// 如果发现越权尝试，抛出异常阻断执行
  String _getSafeAbsolutePath(String relativePath) {
    if (!_isInitialized) throw Exception('VFS 未初始化');

    // 清理路径中的非法字符 (如合并多个 /, 解析 ..)
    final normalizedPath = p.normalize(relativePath);

    // 拼接成完整的手机绝对路径
    final absolutePath = p.join(_workspaceDir.path, normalizedPath);

    // ⚠️ 极度重要的安全检查 ⚠️
    // 确认最终解析的路径仍然在分配给它的工作区内部。
    // 如果 Agent 企图读取 "/data/user/0/com.app/databases/user.db"，isWithin 会返回 false
    if (!p.isWithin(_workspaceDir.path, absolutePath)) {
      throw Exception('安全拦截: 拒绝非法的路径越权访问 -> $relativePath');
    }

    return absolutePath;
  }

  /// 读取文件内容
  Future<String> readFile(String relativePath) async {
    final safePath = _getSafeAbsolutePath(relativePath);
    final file = File(safePath);

    if (!await file.exists()) {
      throw Exception('文件不存在: $relativePath');
    }
    return await file.readAsString();
  }

  /// 写入文件内容 (覆盖)
  /// 如果由于路径嵌套导致父文件夹不存在，会自动递归创建
  Future<void> writeFile(String relativePath, String content) async {
    final safePath = _getSafeAbsolutePath(relativePath);
    final file = File(safePath);

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(content);
  }

  /// 删除文件
  Future<void> deleteFile(String relativePath) async {
    final safePath = _getSafeAbsolutePath(relativePath);
    final file = File(safePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 列出工作区内的所有文件
  /// (让 Manager Agent 知道当前沙盒里有哪些报表或数据可用)
  Future<List<String>> listFiles() async {
    if (!_isInitialized) throw Exception('VFS 未初始化');

    List<String> files = [];
    // 递归遍历工作区
    await for (var entity in _workspaceDir.list(recursive: true)) {
      if (entity is File) {
        // 安全起见，只把相对于工作区的相对路径返回给 Agent
        // 绝对不要让 Agent 知道它在宿主机上的真实绝对路径
        files.add(p.relative(entity.path, from: _workspaceDir.path));
      }
    }
    return files;
  }

  /// 清空整个沙盒工作区
  /// 建议在 Agent 任务彻底完成并返回结果后调用，销毁痕迹释放存储
  Future<void> clearWorkspace() async {
    if (!_isInitialized) return;
    if (await _workspaceDir.exists()) {
      await _workspaceDir.delete(recursive: true);
      await _workspaceDir.create(recursive: true);
    }
    print('🧹 VFS 工作区已清空，临时文件已销毁。');
  }
}