import 'dart:convert';
import 'bridge_registry.dart';
import '../sandbox/vfs_manager.dart';

/// Local Storage Plugin
/// Allows the JS sandbox to safely read and write files within the VFS workspace.
class StoragePlugin extends ClawBridgePlugin {
  final VFSManager vfsManager;

  // --- Unified Result Polling Cache ---
  // Caches results of asynchronous VFS operations
  // Moved to the top for better class structure readability
  final Map<String, String> _vfsCache = {};

  StoragePlugin(this.vfsManager);

  @override
  String get namespace => 'vfs';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'read': _readFile,
    'write': _writeFile,
    'delete': _deleteFile,
    'list': _listFiles,
    'getResult': _getResult, // Expose the method to retrieve task results
  };

  // ============================================================================
  // 🌟 核心优化：提供极其详尽的 API 签名和 JS 文件读写轮询范例
  // ============================================================================
  @override
  List<String> get jsSignatures => [
    'Claw.vfs_read(path: String) -> Returns String (taskId) // 异步读取文件内容',
    'Claw.vfs_write(path: String, content: String) -> Returns String (taskId) // 异步写入文件内容',
    'Claw.vfs_delete(path: String) -> Returns String (taskId) // 异步删除文件',
    'Claw.vfs_list() -> Returns String (taskId) // 异步获取当前目录下的所有文件名',
    '''Claw.vfs_getResult(taskId: String) -> Returns JSON String // 轮询获取 VFS 异步操作的结果。
// JS 调用范例 (请务必使用 while 循环轮询):
// const writeTaskId = Claw.vfs_write("test.txt", "Hello Claw!");
// let writeResult;
// while(true) { 
//   writeResult = JSON.parse(Claw.vfs_getResult(writeTaskId));
//   if(writeResult.status !== "pending") break;
// }
//
// const readTaskId = Claw.vfs_read("test.txt");
// let readResult;
// while(true) { 
//   readResult = JSON.parse(Claw.vfs_getResult(readTaskId));
//   if(readResult.status !== "pending") break;
// }
// return readResult.data;'''
  ];

  /// JS Side Call: const taskId = Claw.vfs_read('data.csv');
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

  /// JS Side Call: const taskId = Claw.vfs_write('output.json', '{"key":"value"}');
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

  /// JS Side Call: const taskId = Claw.vfs_delete('temp.txt');
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

  /// JS Side Call: const taskId = Claw.vfs_list();
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

  /// JS side polling for results. Used by the LLM to retrieve
  /// actual read/write status through a while loop.
  /// Unified call: const result = Claw.vfs_getResult(taskId);
  dynamic _getResult(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing taskId"}';
    final taskId = args[0].toString();

    if (!_vfsCache.containsKey(taskId)) {
      return '{"status": "error", "message": "Unknown taskId: $taskId"}';
    }

    final resultStr = _vfsCache[taskId]!;
    final resultMap = jsonDecode(resultStr);

    // If the task is no longer 'pending' (completed/failed),
    // remove it from cache after reading to prevent memory leaks.
    if (resultMap['status'] != 'pending') {
      _vfsCache.remove(taskId);
    }
    return resultStr;
  }
}