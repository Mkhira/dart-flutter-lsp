# Smoke test for dart-flutter-lsp

A tiny, dependency-free Dart package to verify the plugin end to end.

- `lib/calculator.dart` — a **clean** file. Opening it should produce **no**
  diagnostics; use it to try hover, go-to-definition, and find-references.
- `lib/diagnostics_demo.dart` — **intentionally broken**. Opening it should
  surface several diagnostics (type error, undefined name, missing semicolon,
  unresolved import).

## Run it

```bash
# 1. Resolve packages (creates .dart_tool/package_config.json)
dart pub get

# 2. Confirm the environment is healthy
../../bin/dart-lsp-healthcheck        # run from this smoke_test/ directory

# 3. Open this folder as the project root in Claude Code, then open the two
#    .dart files and confirm diagnostics behave as described above.
```

> **Before vs. after `pub get`** — try opening `lib/calculator.dart` *before*
> running `dart pub get`: analysis is degraded and imports/resolution may be
> noisy. After `dart pub get`, `.dart_tool/package_config.json` exists and
> analysis is accurate. This is why `pub get` is a hard requirement.

> The unresolved `package:does_not_exist/...` import in `diagnostics_demo.dart`
> stays broken on purpose — it demonstrates an import-resolution diagnostic.
