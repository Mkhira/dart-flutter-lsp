# Dart & Flutter LSP Plugin Build Brief

## Role

Act as a senior Language Server Protocol and Claude Code plugin developer.

Build a Claude Code plugin that connects Claude Code to the official Dart Analysis Server LSP. Do not implement a new Dart parser, analyzer, type checker, Flutter analyzer, formatter, or custom language server.

The goal is integration, reliability, and clear developer ergonomics.

## Core Decision

This plugin is not a new "Flutter LSP".

Flutter code is Dart code using the Flutter framework. The official Dart Analysis Server already provides LSP support for Dart and Flutter projects. The plugin must launch and connect Claude Code to:

```bash
dart language-server
```

Claude Code should use that server for `.dart` files.

## Primary Outcome

After installation, when Claude Code opens a Dart or Flutter project, it should be able to receive LSP-powered code intelligence for Dart files:

- diagnostics
- hover/type information
- go to definition
- find references
- document symbols
- workspace symbols where supported
- code actions where supported

## Required Plugin Scope

Build a local Claude Code plugin named:

```text
dart-flutter-lsp
```

The plugin should include:

- plugin manifest
- LSP configuration
- SDK discovery wrapper
- health check script
- README with setup, troubleshooting, and testing instructions

## Loading Strategy

Build this first as a local development plugin, not as a marketplace-distributed plugin.

Preferred local development path:

```bash
claude plugin init dart-flutter-lsp --with lsp
```

This creates a skills-directory plugin under `~/.claude/skills/dart-flutter-lsp/` and loads it as:

```text
dart-flutter-lsp@skills-dir
```

For development from a checked-out plugin folder, document testing with:

```bash
claude --plugin-dir ./dart-flutter-lsp
```

For distribution later, add a marketplace entry and validate the marketplace install flow separately. Do not mix marketplace packaging into the first local-dev build unless explicitly requested.

## Recommended File Structure

Use this structure unless Claude Code plugin conventions require a small adjustment:

```text
dart-flutter-lsp/
  .claude-plugin/
    plugin.json
  .lsp.json
  bin/
    dart-lsp
    dart-lsp-healthcheck
  README.md
```

If the local Claude Code plugin schema differs, adapt to the current official schema but keep the same conceptual pieces.

## Manifest Requirements

The plugin manifest should identify the plugin clearly.

Example intent:

```json
{
  "name": "dart-flutter-lsp",
  "displayName": "Dart & Flutter LSP",
  "version": "0.1.0",
  "description": "Connects Claude Code to the official Dart Analysis Server LSP for Dart and Flutter projects.",
  "lspServers": "./.lsp.json"
}
```

Verify field names against the current Claude Code plugin documentation before finalizing.

Notes:

- `.lsp.json` at the plugin root is auto-discovered by Claude Code.
- Keeping `"lspServers": "./.lsp.json"` is acceptable but redundant.
- `displayName` requires Claude Code v2.1.143 or later; older versions fall back to `name`.

## LSP Configuration Requirements

The LSP configuration should map `.dart` files to the Dart language server.

Preferred production config:

```json
{
  "dart": {
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/dart-lsp",
    "args": [],
    "extensionToLanguage": {
      ".dart": "dart"
    },
    "startupTimeout": 30000,
    "maxRestarts": 5,
    "diagnostics": true,
    "initializationOptions": {
      "onlyAnalyzeProjectsWithOpenFiles": false,
      "suggestFromUnimportedLibraries": true,
      "closingLabels": true,
      "outline": true,
      "flutterOutline": true
    }
  }
}
```

Claude Code supports `${CLAUDE_PLUGIN_ROOT}` in MCP and LSP server configs. Use it for bundled launchers so marketplace cache paths and local `--plugin-dir` paths both resolve correctly.

Treat `initializationOptions` as tunable. For very large monorepos, consider changing `onlyAnalyzeProjectsWithOpenFiles` to `true` if full-workspace analysis is too expensive.

## SDK Discovery Wrapper

Create `bin/dart-lsp`.

Its job is to locate a usable Dart executable and then `exec` the official LSP server.

Discovery order:

1. If `DART_SDK` is set and `$DART_SDK/bin/dart` exists, use it.
2. If `FLUTTER_ROOT` is set and `$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart` exists, use it.
3. If `dart` exists on `PATH`, use it.
4. If `flutter` exists on `PATH`, resolve the Flutter SDK root and use its bundled Dart SDK.
5. Optionally check common Flutter install locations on macOS/Linux if appropriate.
6. If no Dart executable is found, print a clear failure message to stderr and exit non-zero.

Important LSP rule:

- stdout is reserved for LSP protocol messages.
- all logs, debug output, and errors must go to stderr.

The wrapper should start:

```bash
dart language-server --client-id claude-code.dart-flutter-lsp --client-version 0.1.0
```

Use `exec` so the Dart process becomes the LSP process.

The wrapper file must be executable on POSIX systems:

```bash
chmod +x bin/dart-lsp
```

Document this in the README and verify it in the health check.

## Windows Support

Do not assume every Flutter developer is on macOS or Linux.

Choose one of these approaches:

1. Provide POSIX and Windows launchers:
   - `bin/dart-lsp`
   - `bin/dart-lsp.cmd` or `bin/dart-lsp.ps1`
2. Prefer a cross-platform launcher if Claude Code can invoke it reliably.

If using a shell wrapper for v0.1, explicitly document that Windows support is pending. For a production-quality plugin, add a Windows launcher or replace shell-specific logic with a cross-platform implementation.

Make sure the `.lsp.json` command strategy matches the Windows strategy. An absolute POSIX command such as `${CLAUDE_PLUGIN_ROOT}/bin/dart-lsp` will not automatically select `dart-lsp.cmd` on Windows. If Windows is in scope, verify the exact command resolution behavior in Claude Code on Windows before declaring support.

## Debug Mode

Support:

```bash
DART_FLUTTER_LSP_DEBUG=1
```

When enabled, log to stderr:

- selected Dart executable
- selected Flutter SDK root if applicable
- current working directory
- command being executed
- discovery attempts

Never log debug output to stdout.

## Health Check Script

Create `bin/dart-lsp-healthcheck`.

It should verify and print a human-readable report:

- whether `DART_SDK` is set
- whether `FLUTTER_ROOT` is set
- whether `dart` is found on `PATH`
- whether `flutter` is found on `PATH`
- selected Dart executable
- `dart --version`
- selected Flutter executable/root if available
- `flutter --version` if available
- whether `bin/dart-lsp` exists
- whether `bin/dart-lsp` is executable on POSIX systems
- whether current directory contains `pubspec.yaml`
- whether `.dart_tool/package_config.json` exists
- whether `analysis_options.yaml` exists
- whether `dart language-server` appears startable

The health check can use stdout because it is not an LSP transport process.

Name the command `dart-lsp-healthcheck`, not `healthcheck`, because files in plugin `bin/` are added to the Bash tool `PATH` while the plugin is enabled. Generic command names create collision risk.

## Pub Get Requirement

Document this prominently in the README:

```bash
dart pub get
```

or for Flutter projects:

```bash
flutter pub get
```

The Dart analyzer depends on `.dart_tool/package_config.json` for package resolution. Without it, imports and diagnostics may be noisy or wrong.

## Project Root Expectations

Document that Claude Code should open the Dart or Flutter project root, usually the folder containing:

```text
pubspec.yaml
analysis_options.yaml
lib/
test/
```

For monorepos, document that each Dart package may have its own `pubspec.yaml`, and analysis quality depends on opening the correct workspace root.

## Generated Code Guidance

The plugin must not generate code itself.

README should explain that many Flutter/Dart projects depend on generated files such as:

```text
*.g.dart
*.freezed.dart
*.gr.dart
*.config.dart
```

Recommend running the project's existing generator command when diagnostics show missing generated symbols, commonly:

```bash
dart run build_runner build
flutter pub run build_runner build
```

Do not hard-code these commands into the LSP wrapper.

## MCP Note

Mention that LSP and MCP are different:

```text
LSP = code intelligence
MCP = agent tools/actions
```

This plugin should focus on LSP.

Optionally document that Dart/Flutter MCP can be installed separately for actions such as package/tooling workflows, but do not make MCP required for the LSP plugin.

## Do Not Build

Do not build:

- a custom Dart parser
- a custom Flutter analyzer
- a custom type checker
- a custom formatter
- a custom completion engine
- a daemon that proxies and mutates LSP messages unless absolutely necessary
- generated-code builders
- project-specific Riverpod/Bloc/Freezed logic

Use Dart Analysis Server as the source of truth.

## Acceptance Criteria

The plugin is acceptable when:

1. Claude Code recognizes the plugin.
2. The README explains local loading through `claude --plugin-dir ./dart-flutter-lsp` or the skills-directory flow created by `claude plugin init`.
3. Opening a `.dart` file causes the Dart LSP server to start.
4. The wrapper correctly finds Dart from standalone Dart SDK or Flutter SDK.
5. POSIX launcher files in `bin/` are executable.
6. Windows support is implemented or explicitly documented as pending.
7. Diagnostics appear for obvious Dart errors.
8. Hover/go-to-definition/find-references work where Claude Code exposes those LSP features.
9. Failure to find Dart produces a clear stderr message.
10. Debug mode logs discovery details only to stderr.
11. `dart-lsp-healthcheck` gives a useful report.
12. README explains installation, usage, troubleshooting, `pub get`, generated code, Windows caveats, and monorepo caveats.
13. No custom Dart analysis logic is implemented.

## Suggested Build Order

1. Verify current Claude Code plugin schema for LSP plugins.
2. Decide local loading path:
   - `claude plugin init dart-flutter-lsp --with lsp`, or
   - manual plugin folder tested with `claude --plugin-dir ./dart-flutter-lsp`.
3. Add minimal manifest.
4. Add `.lsp.json` using direct `dart` command.
5. Test with a simple Dart project after running `dart pub get`.
6. Replace direct command with `bin/dart-lsp` wrapper.
7. Add SDK discovery.
8. Add debug mode.
9. Add `bin/dart-lsp-healthcheck`.
10. Set executable bits:
    - `chmod +x bin/dart-lsp`
    - `chmod +x bin/dart-lsp-healthcheck`
11. Add Windows launcher or document Windows as pending.
12. Test with:
    - standalone Dart project
    - Flutter project
    - missing Dart/Flutter environment
    - project before and after `pub get`
13. Write README.
14. Validate plugin packaging with `claude plugin validate`.

## Reference Docs To Check

- Claude Code plugins reference: https://code.claude.com/docs/en/plugins-reference
- Dart tools: https://dart.dev/tools
- Dart LSP README: https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server/tool/lsp_spec/README.md
- Dart and Flutter MCP server: https://dart.dev/tools/mcp-server

## Final Engineering Principle

Keep the plugin thin.

The intelligence belongs to Dart Analysis Server. The plugin's value is making that official server easy, reliable, and debuggable inside Claude Code.
