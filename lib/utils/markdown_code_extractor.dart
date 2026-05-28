/// Streaming extractor that strips out the contents of a markdown
/// ```javascript fenced code block as text chunks arrive.
///
/// Designed for the LLM streaming path where we want to forward only the
/// inner code to a JS sandbox.  Lifecycle per stream:
///
/// ```dart
/// final ex = MarkdownCodeExtractor();
/// await for (final delta in llm.streamChat(...)) {
///   final code = ex.feed(delta);
///   if (code.isNotEmpty) splitter.feed(code);
/// }
/// final tail = ex.drainFallback();  // if the LLM forgot the fence
/// if (tail.isNotEmpty) splitter.feed(tail);
/// ```
class MarkdownCodeExtractor {
  bool _inside = false;
  final StringBuffer _seek = StringBuffer();

  /// Feed an incremental chunk.  Returns the portion of [chunk] that is
  /// inside the code fence (may be empty if we haven't found the opening
  /// fence yet or we're past the closing fence).
  String feed(String chunk) {
    if (_inside) {
      final close = chunk.indexOf('```');
      if (close == -1) return chunk;
      _inside = false;
      return chunk.substring(0, close);
    }

    _seek.write(chunk);
    final text = _seek.toString();
    // Match \`\`\`(optional lang)\n
    final open = RegExp(r'```(?:javascript|js)?[ \t]*\r?\n');
    final m = open.firstMatch(text);
    if (m == null) {
      // Maybe a partial fence at the end (e.g. we've only got '``' so far).
      // Keep the tail in _seek; nothing to emit yet.
      return '';
    }

    _inside = true;
    final after = text.substring(m.end);
    _seek.clear();

    // The same chunk might also contain a closing fence.
    final close = after.indexOf('```');
    if (close != -1) {
      _inside = false;
      return after.substring(0, close);
    }
    return after;
  }

  /// Called at end of stream.  If the LLM never used a fence at all (raw
  /// code response), return the buffered text so the splitter still gets
  /// a chance to parse it.
  String drainFallback() {
    if (_inside) {
      // We're inside an unfinished block; flush nothing extra (the inside
      // content was already forwarded chunk-by-chunk).
      return '';
    }
    final t = _seek.toString();
    _seek.clear();
    return t;
  }
}
