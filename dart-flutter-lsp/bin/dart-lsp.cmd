@echo off
REM ==========================================================================
REM dart-lsp.cmd - Windows launcher for the Dart Analysis Server (LSP/stdio).
REM
REM LSP transport rule: stdout is reserved for LSP protocol messages only.
REM All logging goes to stderr (>&2). Set DART_FLUTTER_LSP_DEBUG=1 for details.
REM
REM NOTE: Claude Code's .lsp.json "command" points at bin/dart-lsp (no .cmd
REM extension). On Windows, verify command resolution picks up this .cmd file;
REM see the README "Windows caveats" section. Windows support is best-effort
REM for v0.1.
REM ==========================================================================
setlocal enabledelayedexpansion

set "CLIENT_ID=claude-code.dart-flutter-lsp"
set "CLIENT_VERSION=0.1.0"
set "DART_BIN="
set "FLUTTER_SDK_ROOT="

REM 1. Explicit standalone Dart SDK.
if defined DART_SDK (
  if exist "%DART_SDK%\bin\dart.exe" (
    set "DART_BIN=%DART_SDK%\bin\dart.exe"
    goto :found
  )
)

REM 2. Explicit Flutter SDK root -> bundled Dart SDK.
if defined FLUTTER_ROOT (
  if exist "%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe" (
    set "DART_BIN=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe"
    set "FLUTTER_SDK_ROOT=%FLUTTER_ROOT%"
    goto :found
  )
  if exist "%FLUTTER_ROOT%\bin\dart.bat" (
    set "DART_BIN=%FLUTTER_ROOT%\bin\dart.bat"
    set "FLUTTER_SDK_ROOT=%FLUTTER_ROOT%"
    goto :found
  )
)

REM 3. dart on PATH.
for %%I in (dart.exe) do if not "%%~$PATH:I"=="" (
  set "DART_BIN=%%~$PATH:I"
  goto :found
)
for %%I in (dart.bat) do if not "%%~$PATH:I"=="" (
  set "DART_BIN=%%~$PATH:I"
  goto :found
)

REM 4. flutter on PATH -> bundled Dart SDK.
for %%I in (flutter.bat) do if not "%%~$PATH:I"=="" (
  set "FLUTTER_BIN=%%~$PATH:I"
  for %%J in ("!FLUTTER_BIN!") do set "FLUTTER_BIN_DIR=%%~dpJ"
  for %%K in ("!FLUTTER_BIN_DIR!..") do set "FLUTTER_SDK_ROOT=%%~fK"
  if exist "!FLUTTER_SDK_ROOT!\bin\cache\dart-sdk\bin\dart.exe" (
    set "DART_BIN=!FLUTTER_SDK_ROOT!\bin\cache\dart-sdk\bin\dart.exe"
    goto :found
  )
)

REM Not found.
echo [dart-lsp] ERROR: No usable Dart SDK found.>&2
echo [dart-lsp] Set DART_SDK or FLUTTER_ROOT, or add 'dart' to your PATH.>&2
echo [dart-lsp] Install: https://dart.dev/get-dart or https://docs.flutter.dev/get-started/install>&2
exit /b 1

:found
if "%DART_FLUTTER_LSP_DEBUG%"=="1" (
  echo [dart-lsp][debug] selected dart executable : %DART_BIN%>&2
  echo [dart-lsp][debug] selected flutter sdk root: %FLUTTER_SDK_ROOT%>&2
  echo [dart-lsp][debug] current working directory: %CD%>&2
  echo [dart-lsp][debug] command: %DART_BIN% language-server --client-id %CLIENT_ID% --client-version %CLIENT_VERSION%>&2
)

"%DART_BIN%" language-server --client-id "%CLIENT_ID%" --client-version "%CLIENT_VERSION%"
exit /b %ERRORLEVEL%
