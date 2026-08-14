/// Number formatting for display, in the Venezuelan convention: `.` groups
/// thousands and `,` separates decimals.
///
/// Lives outside the widgets so the display, the dialogs and the history list
/// all format the same way.
class NumberFormatter {
  const NumberFormatter._();

  static const Set<String> _errorValues = <String>{
    'Error',
    'División por cero',
  };

  static bool isErrorValue(String value) => _errorValues.contains(value);

  /// Formats a single number. Input uses `.` as the decimal separator.
  static String amount(String value) {
    if (value.isEmpty || isErrorValue(value)) return value;

    String v = value.trim();
    final bool isNegative = v.startsWith('-');
    if (isNegative) {
      v = v.substring(1);
    }

    String integerPart = v;
    String decimalPart = '';
    final int dotIndex = v.indexOf('.');
    if (dotIndex != -1) {
      integerPart = v.substring(0, dotIndex);
      decimalPart = v.substring(dotIndex + 1);
    }

    final StringBuffer sb = StringBuffer();
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      sb.write(integerPart[i]);
      count++;
      if (count == 3 && i != 0) {
        sb.write('.');
        count = 0;
      }
    }
    final String formattedInt = sb.toString().split('').reversed.join();

    String result = formattedInt;
    if (decimalPart.isNotEmpty) {
      result += ',$decimalPart';
    } else if (dotIndex != -1) {
      // The user just pressed the decimal key. Keep the separator visible —
      // dropping it made the keypress look like it did nothing.
      result += ',';
    }

    return isNegative ? '-$result' : result;
  }

  /// Formats every number inside an expression, leaving operators untouched.
  static String expression(String input) {
    if (input.isEmpty) return '';

    final StringBuffer out = StringBuffer();
    final StringBuffer currentNumber = StringBuffer();
    final RegExp numberChar = RegExp(r'[0-9.]');

    void flushNumber() {
      if (currentNumber.isEmpty) return;
      out.write(amount(currentNumber.toString()));
      currentNumber.clear();
    }

    for (int i = 0; i < input.length; i++) {
      final String ch = input[i];
      if (numberChar.hasMatch(ch)) {
        currentNumber.write(ch);
      } else {
        flushNumber();
        out.write(ch);
      }
    }

    flushNumber();
    return out.toString();
  }
}
