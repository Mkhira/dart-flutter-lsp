// dart_actions_server.dart
//
// A tiny, dependency-free MCP (Model Context Protocol) server that exposes a
// SMALL, EXPLICIT set of Dart/Flutter maintenance actions. Every tool is a thin
// passthrough that shells out to official tooling (dart / flutter / melos).
// There is NO analysis logic, NO bundled rules, NO custom language server here.
//
// Transport: MCP stdio — newline-delimited JSON-RPC 2.0.
//   * stdout is reserved for MCP protocol messages ONLY.
//   * all logs/errors go to stderr.
//   * set DART_FLUTTER_ACTIONS_DEBUG=1 for verbose stderr logging.
//
// SDK paths are provided by the launcher (bin/dart-actions-mcp) via the
// DART_BIN and FLUTTER_BIN environment variables, so SDK discovery lives in one
// place and mirrors the LSP plugin's discipline.
//
// Uses only dart:io / dart:convert / dart:async — runnable via `dart <file>`
// with no pub get and no third-party packages.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String kServerName = 'dart-flutter-actions';
const String kServerVersion = '0.1.0';
const String kDefaultProtocol = '2025-06-18';

final bool debugEnabled =
    Platform.environment['DART_FLUTTER_ACTIONS_DEBUG'] == '1';

void logDebug(String msg) {
  if (debugEnabled) stderr.writeln('[dart-actions][debug] $msg');
}

void logError(String msg) => stderr.writeln('[dart-actions] $msg');

/// The dart executable to shell out with. Prefer the launcher-provided
/// DART_BIN; fall back to the dart running this script.
String get dartBin =>
    Platform.environment['DART_BIN']?.trim().isNotEmpty == true
        ? Platform.environment['DART_BIN']!.trim()
        : Platform.resolvedExecutable;

/// The flutter executable, if the launcher found one ('' when unavailable).
String get flutterBin => Platform.environment['FLUTTER_BIN']?.trim() ?? '';

void main() {
  logDebug('server starting (dart=$dartBin, flutter=${flutterBin.isEmpty ? '<none>' : flutterBin})');
  stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(handleLine, onError: (Object e) {
    logError('stdin error: $e');
  }, onDone: () {
    logDebug('stdin closed; exiting');
    exit(0);
  });
}

void handleLine(String line) {
  final String trimmed = line.trim();
  if (trimmed.isEmpty) return;
  Map<String, dynamic> msg;
  try {
    msg = jsonDecode(trimmed) as Map<String, dynamic>;
  } catch (e) {
    logError('failed to parse JSON-RPC line: $e');
    return;
  }
  // Dispatch asynchronously so long-running commands don't block the reader.
  dispatch(msg);
}

Future<void> dispatch(Map<String, dynamic> msg) async {
  final Object? id = msg['id'];
  final String? method = msg['method'] as String?;
  final bool isRequest = id != null && method != null;

  if (method == null) {
    // A response to something we sent (we send none that expect replies) — ignore.
    return;
  }

  logDebug('-> $method${isRequest ? ' (id=$id)' : ' (notification)'}');

  try {
    switch (method) {
      case 'initialize':
        final params = (msg['params'] as Map?)?.cast<String, dynamic>() ?? {};
        final String protocol =
            (params['protocolVersion'] as String?) ?? kDefaultProtocol;
        sendResult(id, {
          'protocolVersion': protocol,
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {'name': kServerName, 'version': kServerVersion},
        });
        break;

      case 'notifications/initialized':
      case 'initialized':
        // Notification — no response.
        break;

      case 'ping':
        if (isRequest) sendResult(id, {});
        break;

      case 'tools/list':
        sendResult(id, {'tools': toolDefinitions});
        break;

      case 'tools/call':
        final params = (msg['params'] as Map?)?.cast<String, dynamic>() ?? {};
        await handleToolCall(id, params);
        break;

      case 'notifications/cancelled':
        break; // best-effort: nothing to cancel synchronously

      default:
        if (isRequest) {
          sendError(id, -32601, 'Method not found: $method');
        } else {
          logDebug('ignoring unknown notification: $method');
        }
    }
  } catch (e, st) {
    logError('error handling $method: $e');
    logDebug('$st');
    if (isRequest) sendError(id, -32603, 'Internal error: $e');
  }
}

// ---------------------------------------------------------------------------
// Tool definitions
// ---------------------------------------------------------------------------

const Map<String, dynamic> _dirProp = {
  'directory': {
    'type': 'string',
    'description':
        'Absolute path to the project root (folder with pubspec.yaml). '
            'Defaults to the current working directory.',
  },
};

final List<Map<String, dynamic>> toolDefinitions = [
  {
    'name': 'dart_pub_get',
    'description':
        'Resolve project dependencies by running `dart pub get` (or '
            '`flutter pub get` when the project is a Flutter app). Reads/writes '
            '.dart_tool/package_config.json and pubspec.lock. Run this after '
            'changing pubspec.yaml. Passthrough to official tooling.',
    'inputSchema': {
      'type': 'object',
      'properties': {..._dirProp},
    },
  },
  {
    'name': 'build_runner_build',
    'description':
        'Run code generation: `dart run build_runner build '
            '--delete-conflicting-outputs`. MUTATES FILES — it regenerates '
            '*.g.dart / *.freezed.dart / etc. and deletes conflicting outputs. '
            'Only call this when the user wants generated code (re)built.',
    'inputSchema': {
      'type': 'object',
      'properties': {..._dirProp},
    },
  },
  {
    'name': 'dart_fix',
    'description':
        'Apply automated fixes from the Dart analyzer. SAFE BY DEFAULT: runs '
            '`dart fix --dry-run` and only reports what would change. Pass '
            '`apply: true` to actually MODIFY files with `dart fix --apply`.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        ..._dirProp,
        'apply': {
          'type': 'boolean',
          'description':
              'When true, runs `dart fix --apply` and MODIFIES source files. '
                  'When false/omitted, runs `dart fix --dry-run` (no changes).',
          'default': false,
        },
      },
    },
  },
  {
    'name': 'melos_run',
    'description':
        'Run a named script from a Melos monorepo: `melos run <script>`. Only '
            'available when melos.yaml exists in the target directory. '
            'Passthrough — the script itself is defined by the project.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        ..._dirProp,
        'script': {
          'type': 'string',
          'description': 'The melos script name to run (from melos.yaml).',
        },
      },
      'required': ['script'],
    },
  },
];

// ---------------------------------------------------------------------------
// Tool execution
// ---------------------------------------------------------------------------

Future<void> handleToolCall(Object? id, Map<String, dynamic> params) async {
  final String name = (params['name'] as String?) ?? '';
  final Map<String, dynamic> args =
      (params['arguments'] as Map?)?.cast<String, dynamic>() ?? {};
  final String dir = resolveDir(args);

  logDebug('tools/call name=$name dir=$dir args=$args');

  if (!Directory(dir).existsSync()) {
    sendToolError(id, 'Directory does not exist: $dir');
    return;
  }

  switch (name) {
    case 'dart_pub_get':
      await _dartPubGet(id, dir);
      break;
    case 'build_runner_build':
      await _buildRunnerBuild(id, dir);
      break;
    case 'dart_fix':
      await _dartFix(id, dir, args['apply'] == true);
      break;
    case 'melos_run':
      await _melosRun(id, dir, (args['script'] as String?)?.trim() ?? '');
      break;
    default:
      sendError(id, -32602, 'Unknown tool: $name');
  }
}

Future<void> _dartPubGet(Object? id, String dir) async {
  final bool flutter = isFlutterProject(dir);
  if (flutter && flutterBin.isNotEmpty) {
    await runAndReply(id, flutterBin, ['pub', 'get'], dir,
        header: 'flutter pub get');
  } else {
    if (flutter && flutterBin.isEmpty) {
      logDebug('Flutter project but no flutter executable; using dart pub get');
    }
    await runAndReply(id, dartBin, ['pub', 'get'], dir, header: 'dart pub get');
  }
}

Future<void> _buildRunnerBuild(Object? id, String dir) async {
  await runAndReply(
    id,
    dartBin,
    ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    dir,
    header: 'dart run build_runner build --delete-conflicting-outputs',
  );
}

Future<void> _dartFix(Object? id, String dir, bool apply) async {
  final List<String> args = ['fix', apply ? '--apply' : '--dry-run'];
  await runAndReply(id, dartBin, args, dir,
      header: 'dart ${args.join(' ')}${apply ? '  (MODIFIES FILES)' : '  (dry run)'}');
}

Future<void> _melosRun(Object? id, String dir, String script) async {
  if (script.isEmpty) {
    sendToolError(id, "Missing required 'script' argument for melos_run.");
    return;
  }
  if (!File('$dir/melos.yaml').existsSync()) {
    sendToolError(id, 'No melos.yaml found in $dir — melos_run is unavailable here.');
    return;
  }
  // Prefer `melos` on PATH; fall back to `dart run melos` (dev-dependency).
  try {
    await runAndReply(id, 'melos', ['run', script], dir,
        header: 'melos run $script');
  } on ProcessException {
    logDebug('melos not on PATH; falling back to `dart run melos`');
    await runAndReply(id, dartBin, ['run', 'melos', 'run', script], dir,
        header: 'dart run melos run $script');
  }
}

/// Detects a Flutter project by inspecting pubspec.yaml for `sdk: flutter`.
bool isFlutterProject(String dir) {
  final File pubspec = File('$dir/pubspec.yaml');
  if (!pubspec.existsSync()) return false;
  try {
    return pubspec.readAsStringSync().contains('sdk: flutter');
  } catch (_) {
    return false;
  }
}

String resolveDir(Map<String, dynamic> args) {
  final String? d = (args['directory'] as String?)?.trim();
  if (d != null && d.isNotEmpty) return d;
  return Directory.current.path;
}

/// Runs [exe] [args] in [dir], then replies with combined output and status.
Future<void> runAndReply(
  Object? id,
  String exe,
  List<String> args,
  String dir, {
  required String header,
}) async {
  logDebug('exec: $exe ${args.join(' ')}  (cwd=$dir)');
  final ProcessResult result = await Process.run(
    exe,
    args,
    workingDirectory: dir,
    runInShell: false,
  );
  final String out = (result.stdout as String? ?? '').trimRight();
  final String err = (result.stderr as String? ?? '').trimRight();
  final int code = result.exitCode;

  final StringBuffer buf = StringBuffer()
    ..writeln('\$ $header')
    ..writeln('(cwd: $dir)')
    ..writeln('exit code: $code');
  if (out.isNotEmpty) buf..writeln('\n--- stdout ---')..writeln(out);
  if (err.isNotEmpty) buf..writeln('\n--- stderr ---')..writeln(err);

  sendToolText(id, buf.toString(), isError: code != 0);
}

// ---------------------------------------------------------------------------
// JSON-RPC output helpers (stdout — protocol only)
// ---------------------------------------------------------------------------

void sendResult(Object? id, Map<String, dynamic> result) {
  _write({'jsonrpc': '2.0', 'id': id, 'result': result});
}

void sendError(Object? id, int code, String message) {
  _write({
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  });
}

void sendToolText(Object? id, String text, {bool isError = false}) {
  sendResult(id, {
    'content': [
      {'type': 'text', 'text': text},
    ],
    'isError': isError,
  });
}

void sendToolError(Object? id, String message) =>
    sendToolText(id, message, isError: true);

void _write(Map<String, dynamic> message) {
  // Compact single-line JSON followed by a newline. Never contains embedded
  // newlines, per the MCP stdio framing rules.
  stdout.write('${jsonEncode(message)}\n');
}
