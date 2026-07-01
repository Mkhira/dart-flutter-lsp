# Dart & Flutter LSP — Claude Code plugin

This repository is a [Claude Code](https://code.claude.com) **plugin marketplace** that
ships one plugin: **[`dart-flutter-lsp`](./dart-flutter-lsp)**, which connects Claude Code
to the **official Dart Analysis Server** over LSP for Dart and Flutter projects.

It does not implement any Dart/Flutter analysis itself — it launches
`dart language-server` and wires it into Claude Code. All the intelligence comes from
Dart's own server; this plugin is the thin, reliable adapter.

## Install

```bash
# Register this repo as a marketplace, then install the plugin:
claude plugin marketplace add Mkhira/dart-flutter-lsp
claude plugin install dart-flutter-lsp@dart-flutter-marketplace
```

Or try it without installing, straight from a checkout:

```bash
git clone https://github.com/Mkhira/dart-flutter-lsp.git
claude --plugin-dir ./dart-flutter-lsp/dart-flutter-lsp
```

Then run `dart pub get` (or `flutter pub get`) in your project, open the project root, and
open a `.dart` file. See the [plugin README](./dart-flutter-lsp/README.md) for setup,
troubleshooting, `pub get`, generated-code, Windows, and monorepo notes.

## What you get

Diagnostics, hover/type info, go-to-definition, find-references, document & workspace
symbols, code actions (quick-fixes), and rename — all powered by the official Dart
Analysis Server.

## Layout

```text
.
├── .claude-plugin/
│   └── marketplace.json     # marketplace catalog -> ./dart-flutter-lsp
└── dart-flutter-lsp/        # the plugin
    ├── .claude-plugin/plugin.json
    ├── .lsp.json
    ├── bin/                 # dart-lsp launcher, healthcheck, Windows .cmd
    ├── examples/smoke_test/ # ready-made test project
    └── README.md
```

## License

MIT
