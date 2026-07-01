// INTENTIONALLY BROKEN — this file exists to prove diagnostics reach Claude Code.
//
// Opening it should surface several diagnostics, e.g.:
//   - type error:        a String assigned to an int
//   - undefined name:    a call to a function that does not exist
//   - syntax error:      a missing semicolon
//   - import error:      importing a package that isn't declared/resolved
//
// To confirm the plugin's LSP wiring: open this file in Claude Code and check
// that these errors are reported. Then fix them and confirm they clear.

import 'package:does_not_exist/missing.dart'; // unresolved import

void main() {
  int count = 'not an int'; // invalid_assignment: String -> int
  undefinedFunction();       // undefined_function
  print(count)               // expected_token: missing ';'
}
