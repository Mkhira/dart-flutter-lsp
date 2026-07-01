/// A clean, correct file. Use it to exercise the "happy path" LSP features:
///
///   - hover over [Calculator] or [add] to see type information / docs
///   - go-to-definition on [Operation] or [describe]
///   - find-references on [add]
///
/// Opening this file should produce NO diagnostics.
library;

/// A basic arithmetic operation.
enum Operation { add, subtract, multiply, divide }

/// A tiny calculator used to verify go-to-definition, hover, and references.
class Calculator {
  /// Running total.
  double value;

  Calculator([this.value = 0]);

  /// Adds [n] to the running [value] and returns the new total.
  double add(double n) => value += n;

  /// Subtracts [n] from the running [value] and returns the new total.
  double subtract(double n) => value -= n;

  /// Applies [op] to the current [value] and [operand].
  double apply(Operation op, double operand) {
    switch (op) {
      case Operation.add:
        return add(operand);
      case Operation.subtract:
        return subtract(operand);
      case Operation.multiply:
        return value *= operand;
      case Operation.divide:
        return value /= operand;
    }
  }
}

/// Returns a human-readable description of [op].
String describe(Operation op) => 'Operation: ${op.name}';

void main() {
  final calc = Calculator();
  calc.add(10);
  calc.apply(Operation.multiply, 2);
  // ignore: avoid_print
  print('${describe(Operation.multiply)} => ${calc.value}');
}
