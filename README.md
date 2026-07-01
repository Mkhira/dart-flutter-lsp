<div align="center">

# 🎯 Dart & Flutter LSP for Claude Code

### Real Dart & Flutter code intelligence for Claude Code — powered by the official Dart Analysis Server, not guesswork.

[![Validate](https://github.com/Mkhira/dart-flutter-lsp/actions/workflows/validate.yml/badge.svg)](https://github.com/Mkhira/dart-flutter-lsp/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
![Version](https://img.shields.io/badge/version-0.1.0-informational)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Type](https://img.shields.io/badge/Claude%20Code-LSP%20plugin-6E56CF)

**[Install](#-install) · [Why](#-why-youll-want-this) · [Features](#-what-you-get) · [Use cases](#-use-cases) · [How it works](#-how-it-works) · [Full docs »](./dart-flutter-lsp/README.md)**

</div>

---

A thin [Claude Code](https://code.claude.com) plugin that plugs Claude Code into the
**official Dart Analysis Server** — the same engine behind Dart support in VS Code and
Android Studio. When you work on a `.dart` file, Claude Code stops treating your code as
plain text and starts seeing the **actual program**: types, errors, definitions, references.

It implements **no** parser, analyzer, type checker, or formatter of its own. It discovers
your Dart/Flutter SDK, launches `dart language-server`, and gets out of the way. All the
intelligence is Dart's; the plugin is just the reliable wire between it and Claude Code.

## 🤔 Why you'll want this

A headless AI agent, on its own, only sees your code as **text**. That's where the
plausible‑but‑wrong edits come from — invented APIs, fixes that don't compile, refactors
that miss call sites. This plugin closes that gap by feeding Claude Code **ground truth**:

<table>
<tr><th>Without the plugin</th><th>With the plugin</th></tr>
<tr>
<td>

- Guesses types from surrounding text
- "Fixes" errors it can't actually see
- Finds usages with `grep` (misses/overshoots)
- Can't confirm a symbol resolves
</td>
<td>

- Reads **real analyzer diagnostics**
- Fixes the exact errors, by line & code
- **Find‑references** & **go‑to‑definition** from the type model
- Self‑corrects after each edit (re‑analysis)
</td>
</tr>
</table>

## ✨ What you get

Opening a Dart/Flutter project gives Claude Code:

| | Capability | Detail |
|---|---|---|
| 🔎 | **Diagnostics** | errors, warnings & lints — **pushed into context automatically** after each edit |
| 🧠 | **Hover** | types and docs at a position |
| ↪️ | **Go to definition / implementation** | jump to where a symbol is defined or implemented |
| 🔗 | **Find references** | every usage of a symbol, semantically |
| 🗂️ | **Symbols** | document outline + workspace‑wide symbol search |
| 📞 | **Call hierarchy** | incoming & outgoing calls |

> [!NOTE]
> These are the nine operations Claude Code exposes via its built‑in `LSP` tool, plus
> auto‑diagnostics. The Dart server *also* supports **rename**, **code actions**, and
> **signature help**, but Claude Code doesn't surface those yet
> ([claude-code#40282](https://github.com/anthropics/claude-code/issues/40282)) — the plugin
> gains them for free once it does. Until then, Claude fixes errors from diagnostics and does
> renames via find‑references + edits.

## 🚀 Install

### 1 · Prerequisites

- **[Claude Code](https://code.claude.com)** installed
- A **Dart** or **Flutter** SDK on your machine (the plugin auto‑discovers it) —
  [Get Dart](https://dart.dev/get-dart) · [Get Flutter](https://docs.flutter.dev/get-started/install)

There is **no** language server to install separately — `dart language-server` ships inside
the Dart SDK.

### 2 · Add the marketplace and install the plugin

```bash
claude plugin marketplace add Mkhira/dart-flutter-lsp
claude plugin install dart-flutter-lsp@dart-flutter-marketplace
```

The plugin installs at **user scope** and is enabled immediately. Confirm it:

```bash
claude plugin list          # → dart-flutter-lsp@dart-flutter-marketplace  ✔ enabled
```

### 3 · Prepare your project

```bash
dart pub get                # or: flutter pub get   (required — resolves packages)
```

### 4 · Use it

Open the **project root** (the folder containing `pubspec.yaml`) in Claude Code, then open or
edit a `.dart` file — code intelligence turns on automatically. No configuration needed.

Verify your environment anytime with the bundled tools:

```bash
dart-lsp-healthcheck                       # checks your setup (SDK, PATH, project files)
dart-lsp-selftest /path/to/flutter/project # proves it end-to-end: real handshake + diagnostics
```

Both are bare commands once the plugin is enabled. The self test is the surest confirmation a
project will get live diagnostics — it drives the launcher through a real LSP handshake and a
diagnostics round‑trip before you even restart Claude Code.

> [!TIP]
> The language server starts on `.dart` **file activity**, not when the session opens. Touch a
> `.dart` file to warm it up; until then Claude Code may fall back to text search.

<details>
<summary>💻 Alternative — run without installing (from a clone)</summary>

```bash
git clone https://github.com/Mkhira/dart-flutter-lsp.git
claude --plugin-dir ./dart-flutter-lsp/dart-flutter-lsp
```
Loads the plugin for one session directly from the folder. Edits take effect after
`/reload-plugins` — handy for hacking on it.
</details>

<details>
<summary>🔧 Manage / update / uninstall</summary>

```bash
claude plugin list                                              # status
claude plugin marketplace update dart-flutter-marketplace       # pull the latest
claude plugin uninstall dart-flutter-lsp@dart-flutter-marketplace
claude plugin marketplace remove dart-flutter-marketplace
```
</details>

## 💡 Use cases

| You ask Claude Code… | What happens |
| --- | --- |
| *"Fix the errors in this widget."* | Reads the **auto‑injected diagnostics** (exact line + code) and fixes precisely those — no guessing. |
| *"Rename `UserRepository` everywhere."* | Uses **find‑references** to locate every usage (even doc‑comments), then edits each — semantic accuracy, not a fragile grep. |
| *"Where does `context.read<CartBloc>()` resolve to?"* | **Hover** + **go‑to‑definition** answer from resolved types. |
| *"Who calls `processPayment()`, and what does it call?"* | **Call hierarchy** maps the call graph both directions. |
| *"Why are my imports red?"* | Sees the real `uri_does_not_exist` diagnostic → tells you to run `pub get` instead of rewriting working code. |

## ⚙️ How it works

```text
   ┌─────────────┐   LSP / stdio    ┌──────────────┐   exec    ┌──────────────────────┐
   │ Claude Code │ ───────────────▶ │  bin/dart-lsp │ ────────▶ │ dart language-server │
   └─────────────┘  diagnostics &   └──────────────┘  becomes  └──────────────────────┘
                    9 LSP operations        │          the LSP     (official Dart
                                            │          process      Analysis Server)
                                 discovers a usable Dart SDK
                                 (DART_SDK → FLUTTER_ROOT → PATH
                                  → Flutter's bundled Dart → common dirs)
```

The launcher's whole job is to **find Dart and start the official server**, keeping the LSP
transport clean (stdout = protocol only, logs → stderr). Nothing is bundled, compiled, or
downloaded at runtime.

## 📋 Requirements

- **Claude Code** (any current version)
- A **Dart SDK** or **Flutter SDK** (Flutter bundles Dart) — auto‑discovered
  - [Get Dart](https://dart.dev/get-dart) · [Get Flutter](https://docs.flutter.dev/get-started/install)

Run `dart-lsp-healthcheck` from your project root anytime to confirm your setup.

## 📚 Documentation

The **[plugin README](./dart-flutter-lsp/README.md)** covers everything in depth:
setup & installation options, `pub get`, generated code (`*.g.dart` / `*.freezed.dart`),
framework lints via `custom_lint`, configuration & debug mode, the health check, a
ready‑made [smoke‑test project](./dart-flutter-lsp/examples/smoke_test/), troubleshooting,
monorepos, and Windows caveats.

## 🗂️ Repository layout

```text
.
├── .claude-plugin/
│   └── marketplace.json          # marketplace catalog → ./dart-flutter-lsp
├── .github/workflows/validate.yml # CI: manifest/JSON/shellcheck/exec-bit checks
└── dart-flutter-lsp/             # the plugin
    ├── .claude-plugin/plugin.json
    ├── .lsp.json                 # maps .dart → dart language server
    ├── bin/                      # dart-lsp launcher · healthcheck · selftest · Windows .cmd
    ├── examples/smoke_test/      # ready-made verification project
    └── README.md                 # full documentation
```

## 🔌 LSP vs MCP

**LSP** = code intelligence (this plugin). **MCP** = agent tools/actions. This plugin is
LSP‑only and needs no MCP. If you want Claude Code to *run* Dart/Flutter commands (pub, tests,
hot reload), use the first‑party [Dart & Flutter MCP server](https://dart.dev/tools/mcp-server) —
it's separate and optional.

## 🧭 Scope

The Dart Analysis Server is the single source of truth. This plugin deliberately does **not**
ship a parser, analyzer, formatter, completion engine, lint rules, compiled binary, or remote
installer. Its value is making the official server easy, reliable, and debuggable inside
Claude Code.

## 📄 License

[MIT](./LICENSE) © 2026 Mohamed khira

<div align="center">
<sub>Built as a thin, honest wrapper — the intelligence belongs to the Dart Analysis Server.</sub>
</div>
