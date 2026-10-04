import 'package:flutter/material.dart';

import '../theme/cent_icons.dart';
import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';

class CentSearchField extends StatelessWidget {
  const CentSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onTap,
    this.autofocus = false,
    this.readOnly = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool autofocus;

  /// Read-only fields act as a button that opens the search screen.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(CentRadius.lg),
      borderSide: BorderSide(color: color, width: width),
    );

    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        autofocus: autofocus,
        readOnly: readOnly,
        textInputAction: TextInputAction.search,
        cursorColor: c.primary,
        style: CentType.body.copyWith(color: c.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: CentType.body.copyWith(color: c.placeholder),
          filled: true,
          fillColor: c.canvas,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: Icon(CentIcons.search, size: 18, color: c.mute),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: controller == null
              ? null
              : ListenableBuilder(
                  listenable: controller!,
                  builder: (context, _) => controller!.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .deleteButtonTooltip,
                          icon: Icon(CentIcons.clear, size: 16, color: c.mute),
                          onPressed: () {
                            controller!.clear();
                            onChanged?.call('');
                          },
                        ),
                ),
          enabledBorder: border(c.hairline, 1),
          focusedBorder: border(c.primary, 1.5),
        ),
      ),
    );
  }
}
