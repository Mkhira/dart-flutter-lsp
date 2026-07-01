# Dart & Flutter LSP for Claude Code

> Give [Claude Code](https://code.claude.com) real code intelligence for Dart & Flutter — powered by the **official Dart Analysis Server**, not guesswork.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
![Version](https://img.shields.io/badge/version-0.1.0-informational)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Type](https://img.shields.io/badge/Claude%20Code-LSP%20plugin-6E56CF)

When you work on a `.dart` file, this plugin lets Claude Code consult the same analyzer that
powers Dart support in VS Code and Android Studio. Instead of treating your code as text and
pattern‑matching, Claude Code sees the **actual program** — types, errors, definitions,
references — and edits it precisely.

It's intentionally **thin**: it discovers your Dart/Flutter SDK and launches the official
server (`dart language-server`). It implements **no** parser, analyzer, type checker,
formatter, or completion engine of its own — the Dart Analysis Server is the single source
of truth.

---

## Table of contents

- [Why use it](#why-use-it)
- [What you get](#what-you-get)
- [Quick start](#quick-start)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [How it works](#how-it-works)
- [Configuration](#configuration)
- [Health check & testing](#health-check--testing)
- [Troubleshooting](#troubleshooting)
- [Monorepos](#monorepos)
- [Windows support](#windows-support)
- [Scope — what it does *not* do](#scope--what-it-does-not-do)
- [Reference](#reference)

---

## Why use it

A headless AI agent, on its own, only sees your Dart code as **text**. That leads to
plausible‑but‑wrong edits: invented APIs, fixes that don't compile, refactors that miss call
sites. This plugin closes that gap by feeding Claude Code **ground truth** from the analyzer.

Real things it makes possible:

| You ask… | What the plugin enables |
| --- | --- |
| *"Fix the errors in this widget."* | Claude reads the **auto‑injected analyzer diagnostics** (exact line, code, message) and fixes precisely those — no guessing. |
| *"Rename `UserRepository` to `AccountRepository`."* | Claude uses **find‑references** to locate every usage (including doc‑comment references), then edits each site — semantic accuracy instead of a fragile grep. |
| *"Where does `context.read<CartBloc>()` resolve to?"* | **Hover** and **go‑to‑definition** answer from resolved types, not from how Bloc "usually" works. |
| *"Is `calculateTotal()` used anywhere before I change it?"* | **Find‑references** lists every real call site so the change stays consistent. |
| *"Who calls `processPayment()`, and what does it call?"* | **Call hierarchy** (incoming/outgoing calls) maps the call graph in both directions. |
| *"Why are my imports red?"* | Claude sees the real `uri_does_not_exist` diagnostic and tells you the cause (*run `pub get`*) instead of rewriting working code. |

The theme: Claude Code's edits become **accurate and self‑correcting** — after each change the
server re‑analyzes, so a mistake surfaces and gets fixed in the same turn, before you ever run
the app.

## What you get

Once enabled, opening a Dart/Flutter project gives Claude Code exactly this surface:

- 🔎 **Diagnostics** — errors, warnings, and lints, **pushed into context automatically**
  after each edit (this is not an `LSP` operation — it arrives without a tool call)
- 🧠 **Hover** (`hover`) — types and docs at a position
- ↪️ **Go to definition** (`goToDefinition`) and **go to implementation** (`goToImplementation`)
- 🔗 **Find references** (`findReferences`) — every usage of a symbol
- 🗂️ **Document symbols** (`documentSymbol`) and **workspace symbol** search (`workspaceSymbol`)
- 📞 **Call hierarchy** (`prepareCallHierarchy`, `incomingCalls`, `outgoingCalls`)

Those are the **nine** operations Claude Code's built‑in `LSP` tool exposes; diagnostics
are delivered automatically on top.

> **What Claude Code doesn't expose (yet).** The Dart server *also* supports **rename**,
> **code actions / quick‑fixes**, and **signature help**, but Claude Code's `LSP` tool
> doesn't surface those operations today (tracked in
> [claude-code#40282](https://github.com/anthropics/claude-code/issues/40282)). This is a
> Claude Code client limitation, **not** a limitation of this plugin or the Dart server —
> when Claude Code exposes more operations, this plugin gains them for free. In the
> meantime Claude still fixes errors from the auto‑injected diagnostics by editing
> directly, and performs symbol‑wide renames by combining **find references** with edits.

> **LSP vs MCP** — LSP is *code intelligence*; MCP is *agent tools/actions*. This plugin is
> **LSP‑only** and needs no MCP. Dart/Flutter also offer a separate, optional
> [MCP server](https://dart.dev/tools/mcp-server) for tooling/package workflows.

## Quick start

```bash
# 1. Install the plugin
claude plugin marketplace add Mkhira/dart-flutter-lsp
claude plugin install dart-flutter-lsp@dart-flutter-marketplace

# 2. In your Dart/Flutter project
dart pub get          # or: flutter pub get

# 3. Open the project root in Claude Code, then open any .dart file — done.
```

That's it. No language server to install separately (it ships inside the Dart SDK), and no
configuration required.

## Requirements

- **Claude Code** — any current version (`displayName` shows in the UI on v2.1.143+).
- A **Dart SDK** *or* a **Flutter SDK** (Flutter bundles Dart) — auto‑discovered.
  - Standalone Dart: <https://dart.dev/get-dart>
  - Flutter: <https://docs.flutter.dev/get-started/install>
- A recent stable SDK (verified against Dart 3.12 / Flutter 3.44).

Run `dart-lsp-healthcheck` anytime to confirm your setup (see [Testing](#health-check--testing)).

## Installation

### Recommended — from the marketplace

```bash
claude plugin marketplace add Mkhira/dart-flutter-lsp
claude plugin install dart-flutter-lsp@dart-flutter-marketplace
```

The plugin installs at **user scope** and is enabled immediately. Manage it with:

```bash
claude plugin list                                          # status
claude plugin uninstall dart-flutter-lsp@dart-flutter-marketplace
claude plugin marketplace remove dart-flutter-marketplace
```

### Try it without installing (from a clone)

```bash
git clone https://github.com/Mkhira/dart-flutter-lsp.git
claude --plugin-dir ./dart-flutter-lsp/dart-flutter-lsp
```

This loads the plugin for a single session directly from the folder — handy for evaluating
or developing it. Edits to the folder take effect after `/reload-plugins`.

> On macOS/Linux the launchers in `bin/` must stay executable. They ship with the correct
> bits; if a copy strips them, run
> `chmod +x bin/dart-lsp bin/dart-lsp-healthcheck bin/dart-lsp-selftest` — the health check
> will flag this.

## Usage

1. **Run `pub get`** in your project first — this is required:
   ```bash
   dart pub get      # pure-Dart project
   flutter pub get   # Flutter project
   ```
2. **Open the project root** in Claude Code — the folder containing `pubspec.yaml` (usually
   next to `analysis_options.yaml`, `lib/`, `test/`).
3. **Open or edit a `.dart` file.** That file activity is what starts the Dart Analysis
   Server through `bin/dart-lsp`. The first analysis on a large project can take a few seconds.

> **When code intelligence turns on.** The language server starts on `.dart` **file
> activity** — not the moment the session opens. Until it's running, Claude Code has no LSP
> results yet and may fall back to plain text search (grep) for navigation. Opening or
> editing a `.dart` file warms it up; after that, diagnostics arrive automatically and the
> `LSP` operations (hover, definition, references, symbols, call hierarchy) work. This is
> Claude Code behavior, not a plugin setting — if navigation seems to "miss," touch a
> `.dart` file first.

### `pub get` is required

The analyzer resolves packages through `.dart_tool/package_config.json`, generated by
`pub get`. **Without it, imports and diagnostics are noisy or wrong.** Re‑run it after
changing dependencies in `pubspec.yaml`.

### Generated code (`*.g.dart`, `*.freezed.dart`, …)

Many projects depend on generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`,
`*.config.dart`). This plugin **does not generate code**. If diagnostics report missing
generated symbols, run your project's existing generator, e.g.:

```bash
dart run build_runner build
```

Use whatever command your project already uses.

## How it works

```text
Claude Code  ──LSP/stdio──▶  bin/dart-lsp  ──exec──▶  dart language-server
                                  │
                                  └─ finds a usable Dart SDK, then hands the
                                     process over to the Dart Analysis Server
```

- **`.claude-plugin/plugin.json`** — the manifest; points `lspServers` at `.lsp.json`.
- **`.lsp.json`** — maps `.dart` files to the `dart` language server, launched via
  `${CLAUDE_PLUGIN_ROOT}/bin/dart-lsp`.
- **`bin/dart-lsp`** — POSIX launcher: discovers a Dart SDK, then `exec`s
  `dart language-server` so the Dart process *becomes* the LSP process.
- **`bin/dart-lsp.cmd`** — Windows launcher (see [Windows](#windows-support)).
- **`bin/dart-lsp-healthcheck`** — prints a diagnostic report (safe to run anytime).
- **`bin/dart-lsp-selftest`** + **`bin/lsp_selftest.dart`** — end‑to‑end integration probe:
  drives the launcher through a real LSP handshake **and** a diagnostics round‑trip against a
  project (see [Self test](#self-test)).

### SDK discovery order

`bin/dart-lsp` uses the first Dart executable it finds, in this order:

1. `$DART_SDK/bin/dart` (if `DART_SDK` is set)
2. `$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart` (if `FLUTTER_ROOT` is set)
3. `dart` on `PATH`
4. `flutter` on `PATH` → its bundled Dart SDK
5. Common install locations (`~/flutter`, `~/development/flutter`, `~/src/flutter`,
   `~/fvm/default`, `/opt/flutter`, `/usr/local/flutter`, …)

If none are found, it prints a clear message **to stderr** and exits non‑zero.

> **LSP transport rule:** `stdout` is reserved for LSP protocol messages only. Every log,
> debug line, and error from the launcher goes to `stderr`.

## Configuration

The plugin works with **zero configuration**. If you want to tune it, `.lsp.json` passes a
few Dart‑specific `initializationOptions`:

```jsonc
"initializationOptions": {
  // These two actually change analysis behavior in Claude Code:
  "onlyAnalyzeProjectsWithOpenFiles": false, // false = full-workspace analysis
  "suggestFromUnimportedLibraries": true,    // completions from unimported libs

  // The three below only ask the server to emit extra UI notifications
  // (dart/textDocument/publishClosingLabels, publishOutline, publishFlutterOutline).
  // They are INERT unless the LSP *client* renders them — Claude Code does not,
  // so these are no-ops today. Kept true for forward-compat with clients that do.
  "closingLabels": true,
  "outline": true,
  "flutterOutline": true
}
```

For **very large monorepos**, set `onlyAnalyzeProjectsWithOpenFiles` to `true` if
full‑workspace analysis is too expensive.

### Debug mode

Set `DART_FLUTTER_LSP_DEBUG=1` to log discovery details **to stderr** (never stdout): the
selected Dart executable, the Flutter SDK root, the working directory, the exact command run,
and each discovery attempt.

```bash
DART_FLUTTER_LSP_DEBUG=1 ./bin/dart-lsp < /dev/null
# -> [dart-lsp][debug] … lines on stderr
```

## Health check & testing

### Health check

Run from your **project root**:

```bash
./bin/dart-lsp-healthcheck
# or, when the plugin is enabled, as a bare command from any Bash tool call:
dart-lsp-healthcheck
```

It reports: whether `DART_SDK`/`FLUTTER_ROOT` are set; whether `dart`/`flutter` are on
`PATH`; the selected Dart executable and `dart --version`; the Flutter root/version;
whether `bin/dart-lsp` exists and is executable; whether the cwd has `pubspec.yaml`,
`.dart_tool/package_config.json`, `analysis_options.yaml`; and whether `dart language-server`
is startable.

> The command is deliberately named `dart-lsp-healthcheck` (not `healthcheck`): plugin `bin/`
> files are added to the Bash tool's `PATH` while the plugin is enabled, so a generic name
> would risk collisions.

### Self test

Where the health check inspects your *setup*, the self test proves the plugin actually
**works end‑to‑end** — it launches the real `bin/dart-lsp` over LSP stdio (exactly as Claude
Code does) and checks two things against a project you point it at:

1. **Handshake** — the Dart Analysis Server completes `initialize` and advertises the
   capabilities the plugin relies on (diagnostics, hover, definition, implementation,
   references, document/workspace symbols, call hierarchy).
2. **Diagnostics** — it opens an in‑memory Dart file containing a deliberate type error and
   confirms the server pushes back `publishDiagnostics`. Nothing is written to your project.

```bash
# point it at a real Dart/Flutter project (defaults to the current directory):
dart-lsp-selftest /path/to/your/flutter/project
# or from inside the project:
cd /path/to/your/flutter/project && dart-lsp-selftest
```

Exit codes: `0` = all checks passed, `1` = a check failed, `2` = couldn't start (no SDK, or
the target isn't a project). It only needs a Dart SDK to *run* the probe; the launcher it
spawns does its own SDK discovery for the server. This is the fastest way to confirm a
project will get live diagnostics **before** restarting Claude Code with the plugin enabled.

### Ready-made smoke test

A tiny project lives in [`examples/smoke_test/`](examples/smoke_test/):

```bash
cd examples/smoke_test
dart pub get
../../bin/dart-lsp-healthcheck
```

Open that folder as the project root in Claude Code:

- `lib/calculator.dart` — **clean**: no diagnostics; try hover / go‑to‑definition / references.
- `lib/diagnostics_demo.dart` — **intentionally broken**: expect several diagnostics
  (type error, undefined name, missing `;`, unresolved import, plus a lint).

See [`examples/smoke_test/README.md`](examples/smoke_test/README.md) for a before/after
`pub get` comparison.

### Validate the plugin

```bash
claude plugin validate ./dart-flutter-lsp   # add --strict to fail on warnings
```

## Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| "No usable Dart SDK found" on stderr | Dart/Flutter not installed or not discoverable. Install one, or set `DART_SDK`/`FLUTTER_ROOT`, or add `dart` to `PATH`. Re‑run the health check. |
| Noisy/incorrect import errors | Run `dart pub get` / `flutter pub get`; ensure `.dart_tool/package_config.json` exists. |
| "Undefined" errors for generated symbols | Run your generator, e.g. `dart run build_runner build`. |
| No diagnostics at all | You may have opened a subfolder instead of the project root (the folder with `pubspec.yaml`). Reopen the correct root. |
| LSP handshake looks corrupted | Something wrote to stdout. Only the Dart server may write to stdout; keep all custom logging on stderr. |
| Launcher "permission denied" | `chmod +x bin/dart-lsp bin/dart-lsp-healthcheck`. |
| Flutter installed but Dart not found | Run `flutter doctor` once so Flutter populates `bin/cache/dart-sdk`. |
| Changes to plugin files not taking effect | Run `/reload-plugins` or restart Claude Code. |

Enable `DART_FLUTTER_LSP_DEBUG=1` and re‑run to see the discovery trace on stderr.

## Monorepos

Each Dart package typically has its own `pubspec.yaml`. Analysis quality depends on opening
the **correct package root** for what you're editing, and running `pub get` in each package
you work in. For very large workspaces, consider `onlyAnalyzeProjectsWithOpenFiles: true` in
`.lsp.json` (see [Configuration](#configuration)).

## Framework lints (BLoC, Riverpod, Provider, …)

Want framework‑specific lints — Riverpod, BLoC, or metrics like `dart_code_metrics`?
**You don't add them here.** This plugin ships **no** lint rules of its own — baking them in
would duplicate official packages, drift as they evolve, and add maintenance the thin‑wrapper
design avoids. Use the idiomatic Dart path instead, and the lints flow through this plugin's
existing LSP wiring with **zero changes**:

1. Add the tooling to your project's `dev_dependencies`:
   ```yaml
   dev_dependencies:
     custom_lint:
     riverpod_lint:      # or bloc_lint, dart_code_metrics, etc.
   ```
2. Enable the `custom_lint` analyzer plugin in `analysis_options.yaml`:
   ```yaml
   analyzer:
     plugins:
       - custom_lint
   ```
3. Run `dart pub get`.

The **official Dart Analysis Server** loads `custom_lint` automatically, so those rules show
up as ordinary diagnostics — which this plugin already forwards into Claude Code. Nothing to
configure on the plugin side.

> **Out of scope, on purpose.** In‑plugin framework lint rules are explicitly not something
> this plugin does. The Dart Analysis Server stays the single source of truth for what counts
> as a lint; your project's `analysis_options.yaml` + `custom_lint` decides the rules.

## Windows support

Windows is **best‑effort for v0.1**.

- A `bin/dart-lsp.cmd` launcher is provided with the same SDK discovery logic.
- **Caveat:** `.lsp.json` sets `command` to `${CLAUDE_PLUGIN_ROOT}/bin/dart-lsp` (no
  extension). Whether Claude Code on Windows resolves that to `dart-lsp.cmd` depends on the
  platform's command resolution. Verify that opening a `.dart` file actually starts the server
  on Windows; if it doesn't, point `command` at `bin/dart-lsp.cmd` in your local copy.

Contributions to harden Windows support are welcome.

## Scope — what it does *not* do

By design, it does **not** include:

- a custom Dart parser, analyzer, type checker, formatter, or completion engine
- a daemon that proxies/mutates LSP messages
- code/asset generators (`build_runner`, etc.)
- project‑specific Riverpod/Bloc/Freezed logic

The Dart Analysis Server is the single source of truth. The plugin's only job is to make that
official server **easy, reliable, and debuggable** inside Claude Code.

## File structure

```text
dart-flutter-lsp/
  .claude-plugin/
    plugin.json          # manifest (name, displayName, version, lspServers)
  .lsp.json              # LSP config: .dart -> dart language server
  bin/
    dart-lsp             # POSIX launcher (SDK discovery + exec)
    dart-lsp.cmd         # Windows launcher
    dart-lsp-healthcheck # diagnostic report
  examples/
    smoke_test/          # ready-made verification project
  README.md
```

## Reference

- Claude Code plugins — <https://code.claude.com/docs/en/plugins-reference>
- Dart tools — <https://dart.dev/tools>
- Dart LSP (analysis server) — <https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server/tool/lsp_spec/README.md>
- Dart & Flutter MCP server — <https://dart.dev/tools/mcp-server>

## License

[MIT](../LICENSE) © 2026 Mohamed khira
