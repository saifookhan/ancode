import 'package:characters/characters.dart';
import 'package:flutter/services.dart';

/// Uppercases the first grapheme of the field (typing and paste), without
/// changing the rest of the string.
class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  const CapitalizeFirstLetterFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    final first = t.characters.first;
    final upper = first.toUpperCase();
    if (first == upper) return newValue;
    final rest = t.characters.skip(1).toString();
    return TextEditingValue(
      text: '$upper$rest',
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
