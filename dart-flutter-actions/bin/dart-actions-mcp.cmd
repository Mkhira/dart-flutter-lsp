@echo off
REM ==========================================================================
REM dart-actions-mcp.cmd - Windows launcher for the dart-flutter-actions MCP
REM server. Mirrors the POSIX launcher's SDK discovery, then runs the Dart
REM MCP server (stdio JSON-RPC).
REM
REM MCP transport rule: stdout is for protocol messages only; logs go to stderr.
REM Set DART_FLUTTER_ACTIONS_DEBUG=1 for stderr debug output.
REM Windows support is best-effort for v0.1 (see README).
REM ==========================================================================
setlocal enabledelayedexpansion

set "DART_BIN="
set "FLUTTER_BIN="

REM --- Dart discovery ---
if defined DART_SDK if exist "%DART_SDK%\bin\dart.exe" set "DART_BIN=%DART_SDK%\bin\dart.exe"
if not defined DART_BIN if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe" set "DART_BIN=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe"
if not defined DART_BIN for %%I in (dart.exe) do if not "%%~$PATH:I"=="" set "DART_BIN=%%~$PATH:I"
if not defined DART_BIN for %%I in (dart.bat) do if not "%%~$PATH:I"=="" set "DART_BIN=%%~$PATH:I"

if not defined DART_BIN (
  echo [dart-actions] ERROR: No usable Dart SDK found.>&2
  echo [dart-actions] Set DART_SDK/FLUTTER_ROOT or add 'dart' to PATH.>&2
  exit /b 1
)

REM --- Flutter discovery (optional) ---
if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\flutter.bat" set "FLUTTER_BIN=%FLUTTER_ROOT%\bin\flutter.bat"
if not defined FLUTTER_BIN for %%I in (flutter.bat) do if not "%%~$PATH:I"=="" set "FLUTTER_BIN=%%~$PATH:I"

set "PLUGIN_ROOT=%~dp0.."
set "SERVER=%PLUGIN_ROOT%\server\dart_actions_server.dart"

if not exist "%SERVER%" (
  echo [dart-actions] ERROR: MCP server script not found: %SERVER%>&2
  exit /b 1
)

if "%DART_FLUTTER_ACTIONS_DEBUG%"=="1" (
  echo [dart-actions][debug] dart executable : %DART_BIN%>&2
  echo [dart-actions][debug] flutter executable: %FLUTTER_BIN%>&2
  echo [dart-actions][debug] server script   : %SERVER%>&2
)

"%DART_BIN%" "%SERVER%" %*
exit /b %ERRORLEVEL%
