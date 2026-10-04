import 'package:flutter/material.dart';

import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';

/// Label above a 48pt field; copper border while focused.
class CentTextField extends StatelessWidget {
  const CentTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.capitalization = TextCapitalization.sentences,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputAction textInputAction;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(CentRadius.lg),
      borderSide: BorderSide(color: color, width: width),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CentType.footnote.copyWith(color: c.secondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          autofocus: autofocus,
          textInputAction: textInputAction,
          textCapitalization: capitalization,
          cursorColor: c.primary,
          style: CentType.body.copyWith(color: c.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: CentType.body.copyWith(color: c.placeholder),
            filled: true,
            fillColor: c.canvas,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: CentSpace.lg,
              vertical: 13,
            ),
            enabledBorder: border(c.input, 1),
            focusedBorder: border(c.primary, 1.5),
          ),
        ),
      ],
    );
  }
}
