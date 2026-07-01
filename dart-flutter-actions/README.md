# Dart & Flutter Actions (MCP)

> Optional, **opt-in** companion to [`dart-flutter-lsp`](../dart-flutter-lsp). Lets Claude
> Code *run* common Dart/Flutter maintenance commands — it does **not** analyze code.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
![Version](https://img.shields.io/badge/version-0.1.0-informational)
![Type](https://img.shields.io/badge/Claude%20Code-MCP%20plugin-6E56CF)

This is the **MCP** half of the LSP/MCP split:

```text
LSP  = code intelligence   → dart-flutter-lsp   (diagnostics, hover, navigation)
MCP  = agent actions       → dart-flutter-actions (run pub get, build_runner, …)
```

It exposes a **small, explicit** set of tools that are **thin passthroughs to official
tooling**. There is no analysis logic, no bundled lint rules, no custom language server — it
only shells out to `dart` / `flutter` / `melos`.

## Why it's separate and opt-in

Actions can **run commands and modify files**, which is a bigger trust surface than the
read-only LSP plugin. So it ships as its **own** plugin with `defaultEnabled: false` — it
installs **disabled**, and you turn it on deliberately. Install the LSP plugin alone if you
only want code intelligence.

## Tools

| Tool | Runs | Modifies files? |
| --- | --- | --- |
| `dart_pub_get` | `dart pub get` (or `flutter pub get` for Flutter projects) | writes `.dart_tool/`, `pubspec.lock` |
| `build_runner_build` | `dart run build_runner build --delete-conflicting-outputs` | **yes** — regenerates `*.g.dart` etc. |
| `dart_fix` | `dart fix --dry-run` by default; `dart fix --apply` when `apply: true` | only with `apply: true` |
| `melos_run` | `melos run <script>` (only if `melos.yaml` exists) | depends on the script |

**Safety defaults:** mutating actions are never automatic. `dart_fix` is **dry-run unless you
pass `apply: true`**, and every tool description states plainly what it does. Each call is an
explicit, deliberate action.

Each tool accepts an optional `directory` (defaults to the current working directory) and runs
the command in that project root.

## Requirements

- A **Dart SDK** or **Flutter SDK** — auto-discovered with the same logic as the LSP plugin
  (`DART_SDK` → `FLUTTER_ROOT` → `dart`/`flutter` on `PATH` → common install locations).
- For `melos_run`: `melos` available (on `PATH`, or as a dev-dependency runnable via
  `dart run melos`).

No language runtime beyond the Dart SDK is needed — the MCP server is a single core-library
Dart script run via `dart` (no `pub get`, no compiled binary, no remote installer).

## Install

Requires Claude Code **v2.1.154+** for `defaultEnabled` to take effect (older versions install
it enabled).

```bash
claude plugin marketplace add Mkhira/dart-flutter-lsp
claude plugin install dart-flutter-actions@dart-flutter-marketplace
claude plugin enable dart-flutter-actions@dart-flutter-marketplace   # opt in
```

## How it works

```text
Claude Code ──MCP/stdio──▶ bin/dart-actions-mcp ──exec──▶ dart server/dart_actions_server.dart
                                  │                                    │
                                  └─ discovers dart + flutter,          └─ exposes tools that
                                     passes them via DART_BIN/             Process.run official
                                     FLUTTER_BIN env vars                   dart/flutter/melos cmds
```

- **`bin/dart-actions-mcp`** — POSIX launcher: SDK discovery, then runs the server. Sets
  `DART_BIN` / `FLUTTER_BIN` so discovery lives in one place.
- **`bin/dart-actions-mcp.cmd`** — Windows launcher (best-effort for v0.1; see the LSP plugin's
  Windows note).
- **`server/dart_actions_server.dart`** — dependency-free MCP server (newline-delimited
  JSON-RPC 2.0 over stdio; protocol `2025-06-18`).

> **Transport rule:** `stdout` carries MCP protocol messages only. All logs go to `stderr`.
> Set `DART_FLUTTER_ACTIONS_DEBUG=1` for verbose discovery/execution logging on stderr.

## Scope — what it does *not* do

- no Dart analysis, parsing, type-checking, or completion (that's the LSP plugin's server)
- no bundled or hand-written lint rules
- no compiled binary distribution, no `curl | bash` installer
- no automatic/implicit mutations — every file-changing action is explicit per call

The Dart Analysis Server remains the source of truth for code intelligence; this plugin only
wires official *commands* into Claude Code.

## License

[MIT](../LICENSE) © 2026 Mohamed khira
