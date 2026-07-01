// lsp_selftest.dart — end-to-end integration probe for the dart-flutter-lsp
// plugin. It launches the sibling `dart-lsp` launcher exactly the way Claude
// Code does (stdio LSP transport), then verifies two things against a real
// project:
//
//   1. Handshake  — the Dart Analysis Server completes `initialize` and reports
//                   the capabilities the plugin depends on.
//   2. Diagnostics — opening a Dart file with a deliberate type error produces
//                    a `textDocument/publishDiagnostics` notification.
//
// This is NOT part of the LSP transport itself, so it is free to print to
// stdout. It is normally invoked through the `bin/dart-lsp-selftest` wrapper,
// which discovers a Dart SDK to run this script with; the launcher it spawns
// then does its own SDK discovery for the server process.
//
// Exit code 0 = all checks passed, 1 = a check failed, 2 = could not start.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _probeRelPath = 'lib/__dart_flutter_lsp_probe__.dart';
// A snippet with exactly one hard error (type mismatch) so a passing analyzer
// MUST report at least one diagnostic. Kept in memory — never written to disk.
const _probeSource = '''
void main() {
  int probe = 'dart-flutter-lsp selftest expects a type error here';
  print(probe);
}
''';

// ANSI colours when stdout is a TTY.
final bool _tty = stdout.hasTerminal;
String _g(String s) => _tty ? '[32m$s[0m' : s;
String _r(String s) => _tty ? '[31m$s[0m' : s;
String _y(String s) => _tty ? '[33m$s[0m' : s;
String _b(String s) => _tty ? '[1m$s[0m' : s;
void _ok(String s) => print('  ${_g('✓')} $s');
void _bad(String s) => print('  ${_r('✗')} $s');
void _info(String s) => print('    $s');

Future<void> main(List<String> args) async {
  exitCode = await _run(args);
}

Future<int> _run(List<String> args) async {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final launcher = '${scriptDir.path}/dart-lsp';
  final project = args.isNotEmpty
      ? Directory(args[0]).absolute.path
      : Directory.current.path;

  print(_b('dart-flutter-lsp — self test'));
  print('launcher   : $launcher');
  print('project    : $project');

  if (!File(launcher).existsSync()) {
    _bad('launcher not found at $launcher');
    return 2;
  }
  if (!File('$project/pubspec.yaml').existsSync()) {
    print('');
    _bad('no pubspec.yaml in "$project"');
    _info('Pass a Dart/Flutter project root, e.g.:');
    _info('  dart-lsp-selftest /path/to/your/flutter/project');
    return 2;
  }
  if (!File('$project/.dart_tool/package_config.json').existsSync()) {
    _y(
      '  ! .dart_tool/package_config.json missing — run '
      "'flutter pub get' first for accurate results",
    );
  }

  final client = _LspClient(launcher, project);
  try {
    await client.start();
  } catch (e) {
    _bad('failed to start launcher: $e');
    return 2;
  }

  var passed = true;

  // --- Check 1: handshake ---------------------------------------------------
  print('');
  print(_b('Handshake'));
  Map<String, dynamic> initResult;
  try {
    initResult = await client.initialize().timeout(const Duration(seconds: 30));
  } on TimeoutException {
    _bad('initialize timed out (30s) — analysis server never responded');
    await client.dispose();
    return 1;
  }
  final info = (initResult['serverInfo'] as Map?) ?? const {};
  final caps = (initResult['capabilities'] as Map?) ?? const {};
  _ok('server: ${info['name'] ?? 'unknown'} ${info['version'] ?? ''}'.trim());

  const required = {
    'diagnostics (textDocumentSync)': 'textDocumentSync',
    'hover': 'hoverProvider',
    'go-to-definition': 'definitionProvider',
    'go-to-implementation': 'implementationProvider',
    'find-references': 'referencesProvider',
    'document symbols': 'documentSymbolProvider',
    'workspace symbols': 'workspaceSymbolProvider',
    'call hierarchy': 'callHierarchyProvider',
  };
  final missing = <String>[];
  required.forEach((label, key) {
    if (caps.containsKey(key)) {
      _ok('capability: $label');
    } else {
      _bad('missing capability: $label ($key)');
      missing.add(label);
    }
  });
  if (missing.isNotEmpty) passed = false;

  // --- Check 2: diagnostics flow -------------------------------------------
  print('');
  print(_b('Diagnostics'));
  await client.sendInitialized();
  List<dynamic> diags;
  try {
    diags = await client
        .openAndAwaitDiagnostics(_probeRelPath, _probeSource)
        .timeout(const Duration(seconds: 30));
  } on TimeoutException {
    _bad('no publishDiagnostics received within 30s for the probe file');
    _info('The server started but never analysed the opened file.');
    await client.dispose();
    return 1;
  }

  if (diags.isEmpty) {
    _bad(
      'analyzer returned an empty diagnostic set for a file with a type error',
    );
    passed = false;
  } else {
    _ok('analyzer reported ${diags.length} diagnostic(s) on the probe file:');
    for (final d in diags) {
      final m = d as Map<String, dynamic>;
      final start = (m['range']?['start'] ?? const {}) as Map;
      final line = (start['line'] as int? ?? 0) + 1;
      final col = (start['character'] as int? ?? 0) + 1;
      final code = m['code'] ?? '?';
      final msg = (m['message'] as String? ?? '').split('\n').first;
      _info('line $line:$col  [$code] $msg');
    }
  }

  await client.dispose();

  print('');
  if (passed) {
    print(
      _g(_b('SELFTEST PASSED')) +
          ' — launcher, SDK discovery, handshake, and diagnostics all work.',
    );
    print(
      'This project will get live diagnostics once you restart Claude Code '
      'inside it with the plugin enabled.',
    );
    return 0;
  }
  print(
    _r(_b('SELFTEST FAILED')) +
        ' — see the ${_r('✗')} lines above. Run dart-lsp-healthcheck for details.',
  );
  return 1;
}

/// Minimal LSP-over-stdio client speaking to the plugin launcher.
class _LspClient {
  _LspClient(this._launcher, this._project);

  final String _launcher;
  final String _project;
  late final Process _proc;
  final _buffer = <int>[];
  int _nextId = 1;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _diagWaiters = <String, Completer<List<dynamic>>>{};

  Future<void> start() async {
    _proc = await Process.start(
      _launcher,
      const [],
      workingDirectory: _project,
    );
    _proc.stdout.listen(_onData);
    // Drain stderr so the child never blocks; surface it only in debug mode.
    final debug = Platform.environment['DART_FLUTTER_LSP_DEBUG'] == '1';
    _proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        if (debug) stderr.writeln(line);
      },
    );
  }

  Future<Map<String, dynamic>> initialize() {
    final rootUri = Uri.file(_project).toString();
    return _request('initialize', {
      'processId': pid,
      'rootUri': rootUri,
      'capabilities': {
        'textDocument': {
          'publishDiagnostics': {'relatedInformation': true},
        },
      },
      'workspaceFolders': [
        {'uri': rootUri, 'name': 'selftest'},
      ],
    });
  }

  Future<void> sendInitialized() async {
    _notify('initialized', const {});
  }

  /// Opens [relPath] (under the project root) with [text] and completes when
  /// diagnostics for that document arrive.
  Future<List<dynamic>> openAndAwaitDiagnostics(String relPath, String text) {
    final uri = Uri.file('$_project/$relPath').toString();
    final completer = Completer<List<dynamic>>();
    _diagWaiters[uri] = completer;
    _notify('textDocument/didOpen', {
      'textDocument': {
        'uri': uri,
        'languageId': 'dart',
        'version': 1,
        'text': text,
      },
    });
    return completer.future;
  }

  Future<void> dispose() async {
    try {
      _notify('exit', const {});
    } catch (_) {}
    try {
      _proc.kill();
    } catch (_) {}
  }

  // --- transport ------------------------------------------------------------

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> params,
  ) {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _send({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    return completer.future;
  }

  void _notify(String method, Map<String, dynamic> params) {
    _send({'jsonrpc': '2.0', 'method': method, 'params': params});
  }

  void _send(Map<String, dynamic> msg) {
    final body = utf8.encode(jsonEncode(msg));
    _proc.stdin.add(utf8.encode('Content-Length: ${body.length}\r\n\r\n'));
    _proc.stdin.add(body);
  }

  void _onData(List<int> chunk) {
    _buffer.addAll(chunk);
    while (true) {
      final headerEnd = _indexOfHeaderEnd();
      if (headerEnd < 0) return;
      final header = utf8.decode(_buffer.sublist(0, headerEnd));
      final match = RegExp(
        r'Content-Length:\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(header);
      if (match == null) {
        _buffer.removeRange(0, headerEnd + 4);
        continue;
      }
      final length = int.parse(match.group(1)!);
      final bodyStart = headerEnd + 4;
      if (_buffer.length < bodyStart + length) return; // wait for more bytes
      final body = _buffer.sublist(bodyStart, bodyStart + length);
      _buffer.removeRange(0, bodyStart + length);
      _dispatch(jsonDecode(utf8.decode(body)) as Map<String, dynamic>);
    }
  }

  int _indexOfHeaderEnd() {
    for (var i = 0; i + 3 < _buffer.length; i++) {
      if (_buffer[i] == 13 &&
          _buffer[i + 1] == 10 &&
          _buffer[i + 2] == 13 &&
          _buffer[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  void _dispatch(Map<String, dynamic> msg) {
    if (msg.containsKey('id') && msg.containsKey('result')) {
      final completer = _pending.remove(msg['id']);
      completer?.complete((msg['result'] as Map).cast<String, dynamic>());
      return;
    }
    if (msg['method'] == 'textDocument/publishDiagnostics') {
      final params = (msg['params'] as Map).cast<String, dynamic>();
      final uri = params['uri'] as String?;
      final diags = (params['diagnostics'] as List?) ?? const [];
      if (uri != null && diags.isNotEmpty) {
        _diagWaiters.remove(uri)?.complete(diags);
      }
    }
    // Server->client requests (e.g. workDoneProgress/create) are ignored;
    // the analysis server does not block startup waiting on them.
  }
}
