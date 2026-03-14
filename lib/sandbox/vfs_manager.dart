import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';

/// Virtual File System (VFS) Manager
/// Responsible for providing a secure, isolated local working directory for the Agent.
/// Strictly prevents Path Traversal attacks.
class VFSManager {
  late Directory _workspaceDir;
  bool _isInitialized = false;

  /// Initializes the VFS
  /// Creates a dedicated Agent workspace within the App's documents directory.
  /// [workspaceName] can be dynamically specified based on a Task ID to achieve multi-task isolation.
  Future<void> initialize({String workspaceName = 'agent_workspace'}) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _workspaceDir = Directory(join(appDocDir.path, workspaceName));

    if (!await _workspaceDir.exists()) {
      await _workspaceDir.create(recursive: true);
    }
    _isInitialized = true;
    Log.i('📁 VFS Workspace initialization complete: ${_workspaceDir.path}');
  }

  /// Core Security Moat: Resolves the relative path provided by the Agent into a secure absolute path.
  /// If an unauthorized access attempt is detected, an exception is thrown to block execution.
  String _getSafeAbsolutePath(String relativePath) {
    if (!_isInitialized) throw Exception('VFS not initialized');

    // Clean illegal characters in the path (e.g., merging multiple '/', resolving '..')
    final normalizedPath = normalize(relativePath);

    // Concatenate into a full absolute path for the mobile device
    final absolutePath = join(_workspaceDir.path, normalizedPath);

    // ⚠️ CRITICAL SECURITY CHECK ⚠️
    // Confirm that the final resolved path remains inside the assigned workspace.
    // If an Agent attempts to read "/data/user/0/com.app/databases/user.db", 'isWithin' will return false.
    if (!isWithin(_workspaceDir.path, absolutePath)) {
      throw Exception('Security Interception: Denied illegal path traversal access -> $relativePath');
    }

    return absolutePath;
  }

  /// Reads file content
  Future<String> readFile(String relativePath) async {
    final safePath = _getSafeAbsolutePath(relativePath);
    final file = File(safePath);

    if (!await file.exists()) {
      throw Exception('File does not exist: $relativePath');
    }
    return await file.readAsString();
  }

  /// Writes file content (overwrite)
  /// If parent directories do not exist due to path nesting, they will be created recursively.
  Future<void> writeFile(String relativePath, String content) async {
    final safePath = _getSafeAbsolutePath(relativePath);
    final file = File(safePath);

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(content);
  }

  /// Deletes a file
  Future<void> deleteFile(String relativePath) async {
    final safePath = _getSafeAbsolutePath(relativePath);
    final file = File(safePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Lists all files within the workspace
  /// (Allows the Manager Agent to know which reports or data files are available in the sandbox)
  Future<List<String>> listFiles() async {
    if (!_isInitialized) throw Exception('VFS not initialized');

    List<String> files = [];
    // Recursively traverse the workspace
    await for (var entity in _workspaceDir.list(recursive: true)) {
      if (entity is File) {
        // For security reasons, only return paths relative to the workspace to the Agent.
        // Never let the Agent know its actual absolute path on the host machine.
        files.add(relative(entity.path, from: _workspaceDir.path));
      }
    }
    return files;
  }

  /// Clears the entire sandbox workspace
  /// Recommended to call this after an Agent task is fully completed and results are returned,
  /// destroying traces and releasing storage space.
  Future<void> clearWorkspace() async {
    if (!_isInitialized) return;
    if (await _workspaceDir.exists()) {
      await _workspaceDir.delete(recursive: true);
      await _workspaceDir.create(recursive: true);
    }
    Log.i('🧹 VFS Workspace cleared; temporary files destroyed.');
  }
}