import 'dart:convert';
import 'bridge_registry.dart';
import '../sandbox/vfs_manager.dart';

/// 本地存储插件
/// 允许 JS 沙盒安全地读写 VFS 工作区内的文件
class StoragePlugin extends ClawBridgePlugin {
  final VFSManager vfsManager;

  StoragePlugin(this.vfsManager);

  @override
  String get namespace => 'vfs';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'read': _readFile,
    'write': _writeFile,
    'delete': _deleteFile,
    'list': _listFiles,
  };

  /// JS 端调用: const content = Claw.vfs_read('data.csv');
  /// 注意：文件读写在 Dart 中也是异步的。为了简化 JS 端的调用，
  /// 对于小的本地文件读取，我们可以使用一种“伪同步”或者强制等待的模式。
  /// 但由于 QuickJS 的 bridge 限制，这里我们采用与 NetworkPlugin 类似的
  /// 异步任务分配 + 轮询获取结果的模式，以保证 Flutter 主线程的绝对流畅。
  dynamic _readFile(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing file path"}';
    final path = args[0].toString();

    final taskId = 'vfs_read_${DateTime.now().millisecondsSinceEpoch}';
    _vfsCache[taskId] = '{"status": "pending"}';

    _executeRead(taskId, path);
    return taskId;
  }

  Future<void> _executeRead(String taskId, String path) async {
    try {
      final content = await vfsManager.readFile(path);
      _vfsCache[taskId] = jsonEncode({
        'status': 'success',
        'data': content,
      });
    } catch (e) {
      _vfsCache[taskId] = jsonEncode({
        'status': 'error',
        'message': e.toString(),
      });
    }
  }

  /// JS 端调用: const taskId = Claw.vfs_write('output.json', '{"key":"value"}');
  dynamic _writeFile(List<dynamic> args) {
    if (args.length < 2) return '{"error": "Missing path or content"}';
    final path = args[0].toString();
    final content = args[1].toString();

    final taskId = 'vfs_write_${DateTime.now().millisecondsSinceEpoch}';
    _vfsCache[taskId] = '{"status": "pending"}';

    _executeWrite(taskId, path, content);
    return taskId;
  }

  Future<void> _executeWrite(String taskId, String path, String content) async {
    try {
      await vfsManager.writeFile(path, content);
      _vfsCache[taskId] = jsonEncode({'status': 'success'});
    } catch (e) {
      _vfsCache[taskId] = jsonEncode({
        'status': 'error',
        'message': e.toString(),
      });
    }
  }

  /// JS 端调用: const taskId = Claw.vfs_delete('temp.txt');
  dynamic _deleteFile(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing file path"}';
    final path = args[0].toString();

    final taskId = 'vfs_del_${DateTime.now().millisecondsSinceEpoch}';
    _vfsCache[taskId] = '{"status": "pending"}';

    _executeDelete(taskId, path);
    return taskId;
  }

  Future<void> _executeDelete(String taskId, String path) async {
    try {
      await vfsManager.deleteFile(path);
      _vfsCache[taskId] = jsonEncode({'status': 'success'});
    } catch (e) {
      _vfsCache[taskId] = jsonEncode({
        'status': 'error',
        'message': e.toString(),
      });
    }
  }

  /// JS 端调用: const taskId = Claw.vfs_list();
  dynamic _listFiles(List<dynamic> args) {
    final taskId = 'vfs_list_${DateTime.now().millisecondsSinceEpoch}';
    _vfsCache[taskId] = '{"status": "pending"}';

    _executeList(taskId);
    return taskId;
  }

  Future<void> _executeList(String taskId) async {
    try {
      final files = await vfsManager.listFiles();
      _vfsCache[taskId] = jsonEncode({
        'status': 'success',
        'files': files,
      });
    } catch (e) {
      _vfsCache[taskId] = jsonEncode({
        'status': 'error',
        'message': e.toString(),
      });
    }
  }

  // --- 统一的结果轮询接口 ---
  // 用于缓存 VFS 异步操作的结果
  final Map<String, String> _vfsCache = {};

  /// JS 端轮询获取结果，供大模型通过 while 循环获取真实读写状态
  /// 统一调用: const result = Claw.vfs_getResult(taskId);
  dynamic _getResult(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing taskId"}';
    final taskId = args[0].toString();

    if (!_vfsCache.containsKey(taskId)) {
      return '{"status": "error", "message": "Unknown taskId: $taskId"}';
    }

    final resultStr = _vfsCache[taskId]!;
    final resultMap = jsonDecode(resultStr);

    if (resultMap['status'] != 'pending') {
      _vfsCache.remove(taskId);
    }
    return resultStr;
  }

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'read': _readFile,
    'write': _writeFile,
    'delete': _deleteFile,
    'list': _listFiles,
    'getResult': _getResult, // 将获取结果的方法暴露出去
  };
}