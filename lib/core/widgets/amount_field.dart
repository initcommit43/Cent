import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money/currency.dart';
import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';

/// Parses typed amounts like "1200", "-312.4" or "1,200.50" into minor
/// units. Empty text is zero; anything else invalid is null.
int? parseAmountMinor(
  String text,
  Currency currency, {
  bool allowNegative = false,
}) {
  final clean = text.replaceAll(',', '').trim();
  if (clean.isEmpty) return 0;
  final match = RegExp(r'^(-)?(\d+)(?:\.(\d{1,2}))?$').firstMatch(clean);
  if (match == null) return null;
  if (match.group(1) != null && !allowNegative) return null;
  final whole = int.parse(match.group(2)!);
  final minor = currency.decimals == 0
      ? whole
      : whole * 100 + int.parse((match.group(3) ?? '').padRight(2, '0'));
  return match.group(1) == null ? minor : -minor;
}

/// Plain text for an existing amount, for prefilling [AmountField].
String formatAmountInput(int minor, Currency currency) {
  final sign = minor < 0 ? '-' : '';
  final abs = minor.abs();
  if (currency.decimals == 0) return '$sign$abs';
  final cents = abs % 100;
  final fraction = cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}';
  return '$sign${abs ~/ 100}$fraction';
}

/// Large amount input with the currency symbol in front; red border while
/// the text can't be parsed.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.currency,
    required this.onChanged,
    this.allowNegative = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final Currency currency;
  final ValueChanged<String> onChanged;
  final bool allowNegative;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final valid =
        parseAmountMinor(
          controller.text,
          currency,
          allowNegative: allowNegative,
        ) !=
        null;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(CentRadius.lg),
      borderSide: BorderSide(color: color, width: width),
    );

    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(
        signed: allowNegative,
        decimal: currency.decimals > 0,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(allowNegative ? '[-0-9.,]' : '[0-9.,]'),
        ),
      ],
      onChanged: onChanged,
      cursorColor: c.primary,
      style: CentType.title1.copyWith(
        color: c.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: CentType.title1.copyWith(color: c.placeholder),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Text(
            currency.symbol,
            style: CentType.title2.copyWith(color: c.mute),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(),
        filled: true,
        fillColor: c.canvas,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: border(valid ? c.input : c.negative, 1),
        focusedBorder: border(valid ? c.primary : c.negative, 1.5),
      ),
    );
  }
}
