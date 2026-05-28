import 'dart:typed_data';

/// Pluggable neural-TTS backend for [TTSPlugin].
///
/// flutter_claw ships its own supertonic_flutter implementation as the
/// historical default.  Host apps that want a different engine (e.g. the
/// sherpa-onnx Supertonic 3 stack used by weclaw) register their impl on
/// [TTSEngineRegistry.current] before any [TTSPlugin] is constructed; the
/// plugin then routes warm-up + synthesis through it instead of the
/// built-in path.
///
/// Kept intentionally narrow — language detection, lip-sync envelope, and
/// playback all stay in [TTSPlugin].  Engines only have to:
///   1. download / load their own model
///   2. take text → return 16-bit PCM WAV bytes
abstract class TTSEngine {
  /// One-time download + load.  Idempotent — calling twice after success
  /// should be a no-op.  Reports a 0..1 fraction via [onProgress] when
  /// download is in flight; pass a `null` fraction (or skip the call) when
  /// progress is unknown.
  ///
  /// Returns true iff the engine is ready to synthesize.
  Future<bool> warmUp({TTSEngineWarmupProgress? onProgress});

  /// Synthesize [text] into a complete 16-bit PCM WAV byte stream.  The
  /// caller (TTSPlugin) writes it to a temp file and hands it to
  /// audioplayers — the engine doesn't need to know about playback.
  ///
  /// [language] is a hint (`en`, `zh`, `ko`, etc.) for engines that need
  /// it; multilingual engines (Supertonic 3) usually ignore it because
  /// the text itself reveals the script.  [voice] is an opaque engine-
  /// specific identifier (sid number, speaker name, etc.) — null = default.
  Future<Uint8List> synthesizeToWav(
    String text, {
    String? language,
    String? voice,
  });

  /// True once [warmUp] has succeeded; cheap to call.
  bool get isReady;
}

/// Single-double progress callback.  Optional `phase` lets the engine
/// surface a coarse stage label (e.g. "downloading", "extracting", "loading")
/// when the fraction alone is misleading (extraction can take 5–10 s while
/// the fraction sits at 1.0).
typedef TTSEngineWarmupProgress = void Function(
  double fraction, {
  String? phase,
});

/// Process-global registry.  Set [current] **before** constructing any
/// [TTSPlugin] (which happens whenever an AgentRuntime gets built).  Use
/// a plain static field rather than a DI container so flutter_claw stays
/// free of any host-app DI dependency.
class TTSEngineRegistry {
  static TTSEngine? _current;

  /// The engine TTSPlugin will use.  Null = fall back to the legacy
  /// supertonic_flutter built-in path.
  static TTSEngine? get current => _current;
  static set current(TTSEngine? engine) => _current = engine;
}
