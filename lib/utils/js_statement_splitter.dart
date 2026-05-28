/// Streaming JS source splitter.
///
/// Feed it incremental text chunks (e.g. SSE deltas from an LLM) and it
/// returns any *complete* top-level statements as soon as their trailing
/// `;` is seen.  Handles strings (', ", `), single-line // and block /* */
/// comments, and nested parens / brackets / braces.
///
/// Used by `ManagerAgent.streamProcess` to dispatch each statement to the
/// sandbox the moment it's syntactically complete — enabling micro-
/// expression updates *while* the LLM is still typing the rest.
class JSStatementSplitter {
  final StringBuffer _buf = StringBuffer();
  int _depthParen = 0;
  int _depthBrace = 0;
  int _depthBracket = 0;
  bool _inString = false;
  String _stringQuote = '';
  bool _escaped = false;
  bool _inLineComment = false;
  bool _inBlockComment = false;
  String _lastChar = ' ';

  /// Feed a chunk; returns zero or more *complete* statements in order.
  /// Each returned statement includes its trailing `;`.
  List<String> feed(String text) {
    final out = <String>[];
    for (int i = 0; i < text.length; i++) {
      final c = text[i];

      // —— comment handling ——
      if (_inLineComment) {
        _buf.write(c);
        if (c == '\n') _inLineComment = false;
        _lastChar = c;
        continue;
      }
      if (_inBlockComment) {
        _buf.write(c);
        if (c == '/' && _lastChar == '*') _inBlockComment = false;
        _lastChar = c;
        continue;
      }

      // —— string handling ——
      if (_inString) {
        _buf.write(c);
        if (_escaped) {
          _escaped = false;
        } else if (c == '\\') {
          _escaped = true;
        } else if (c == _stringQuote) {
          _inString = false;
        }
        _lastChar = c;
        continue;
      }

      // Detect comment start (only when not in string)
      if (c == '/' && i + 1 < text.length) {
        final next = text[i + 1];
        if (next == '/') {
          _buf.write(c);
          _buf.write(next);
          _inLineComment = true;
          _lastChar = next;
          i++;
          continue;
        }
        if (next == '*') {
          _buf.write(c);
          _buf.write(next);
          _inBlockComment = true;
          _lastChar = next;
          i++;
          continue;
        }
      }

      // Detect string start
      if (c == "'" || c == '"' || c == '`') {
        _buf.write(c);
        _inString = true;
        _stringQuote = c;
        _lastChar = c;
        continue;
      }

      _buf.write(c);

      switch (c) {
        case '(':
          _depthParen++;
          break;
        case ')':
          _depthParen--;
          break;
        case '[':
          _depthBracket++;
          break;
        case ']':
          _depthBracket--;
          break;
        case '{':
          _depthBrace++;
          break;
        case '}':
          _depthBrace--;
          break;
        case ';':
          if (_depthParen == 0 &&
              _depthBracket == 0 &&
              _depthBrace == 0) {
            final stmt = _buf.toString().trim();
            if (stmt.isNotEmpty) out.add(stmt);
            _buf.clear();
          }
          break;
      }
      _lastChar = c;
    }
    return out;
  }

  /// Flush any remaining text as a last statement.  Call at end-of-stream
  /// for the trailing statement (e.g. `Claw.finish('...')`) when the LLM
  /// forgot a closing `;`.
  String drain() {
    final s = _buf.toString().trim();
    _buf.clear();
    _depthParen = _depthBrace = _depthBracket = 0;
    _inString = _inLineComment = _inBlockComment = _escaped = false;
    _stringQuote = '';
    _lastChar = ' ';
    return s;
  }
}
