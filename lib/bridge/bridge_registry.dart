import '../sandbox/js_runtime.dart';
import '../models/task_config.dart';
import '../utils/logger.dart';

/// Base abstract class for bridge plugins
/// Any native capability (e.g., Network, Storage, Bluetooth) intended to be
/// exposed to the JS sandbox must extend this class.
abstract class ClawBridgePlugin {
  /// The plugin's namespace, used as a prefix in JS, e.g., 'network' -> Claw.network.xxx
  String get namespace;

  /// A map of all methods provided by this plugin
  /// Key: Method name called from the JS side, Value: The handling logic in the Dart layer
  Map<String, dynamic Function(List<dynamic>)> get methods;
}

/// Core Bridge Registry
/// Responsible for injecting methods from multiple plugins into the QuickJS engine
class BridgeRegistry {
  final ClawJSRuntime jsRuntime;

  BridgeRegistry(this.jsRuntime);

  /// Registers a single plugin
  void registerPlugin(ClawBridgePlugin plugin) {
    plugin.methods.forEach((methodName, handler) {
      // Combines namespace and methodName to prevent naming conflicts.
      // Final JS call format: Claw.network_get(...) or directly Claw.network_get(...)
      final fullMethodName = '${plugin.namespace}_$methodName';
      jsRuntime.registerBridgeMethod(fullMethodName, handler);
    });
  }

  /// Registers default system-level plugins based on [TaskConfig] authorization
  void registerDefaultPlugins(TaskConfig config) {
    if (config.requireNetwork) {
      registerPlugin(NetworkPlugin());
    }

    if (config.requireStorage) {
      registerPlugin(StoragePlugin());
    }

    // Always register basic system info if needed
    // registerPlugin(SystemPlugin());
  }
}

// ============================================================================
// Examples of pre-set Core Plugins below
// ============================================================================

/// Network Request Plugin Example
/// Allows the JS sandbox to initiate HTTP GET requests to fetch data
class NetworkPlugin extends ClawBridgePlugin {
  @override
  String get namespace => 'network';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {'get': _httpGet};

  /// JS Side Call: Claw.network_get('https://api.example.com/data')
  dynamic _httpGet(List<dynamic> args) {
    if (args.isEmpty) {
      return '{"error": "Missing URL parameter"}';
    }

    final url = args[0].toString();
    Log.i('🌐 [Bridge] JS initiating HTTP GET request: $url');

    // Note: For the sake of simplicity in this example, Dio or the http package
    // are not used for real asynchronous requests.
    // In a real flutter_claw implementation, you would initiate a real HTTP request here.
    // Since Dart calls returning to JS need to be synchronous strings (or returned
    // asynchronously via another message channel), we usually recommend that this
    // just initiates the request and returns a Task ID for JS to poll or await a callback.
    //
    // For a simple synchronous bridge demo, we return some mock data:
    return '{"status": 200, "data": "Mock network response data from $url"}';
  }
}

/// Storage/Read Plugin Example (integrated with VFS)
class StoragePlugin extends ClawBridgePlugin {
  // Assume a vfsManager instance is injected
  // final VFSManager vfsManager;
  // StoragePlugin(this.vfsManager);

  @override
  String get namespace => 'vfs';

  @override
  Map<String, dynamic Function(List<dynamic>)> get methods => {
    'read': _readFile,
  };

  /// JS Side Call: Claw.vfs_read('data.csv')
  dynamic _readFile(List<dynamic> args) {
    if (args.isEmpty) return '{"error": "Missing file path"}';
    final path = args[0].toString();
    Log.i('📂 [Bridge] JS requesting to read file: $path');

    // In a real implementation, call vfsManager.readFile(path)
    return 'Mock file content, e.g., id,name\n1,Alice\n2,Bob';
  }
}
