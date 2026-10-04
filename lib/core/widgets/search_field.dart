import 'package:flutter/cupertino.dart';

import '../theme/cent_icons.dart';
import '../theme/cent_theme.dart';
import '../theme/cent_tokens.dart';
import '../theme/cent_typography.dart';

/// iOS search field with Cent's colors and Lucide icons. The default icons
/// come from the Cupertino icon font, which the app doesn't ship.
class CentSearchField extends StatelessWidget {
  const CentSearchField({
    super.key,
    required this.placeholder,
    required this.controller,
    required this.onChanged,
    this.focusNode,
  });

  final String placeholder;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CupertinoSearchTextField(
      controller: controller,
      focusNode: focusNode,
      // In a searchable navigation bar the resting copy of the field can't
      // take focus; the copy shown once search is active focuses itself.
      autofocus: true,
      onChanged: onChanged,
      placeholder: placeholder,
      backgroundColor: c.canvas,
      borderRadius: BorderRadius.circular(CentRadius.lg),
      style: CentType.body.copyWith(color: c.ink),
      placeholderStyle: CentType.body.copyWith(color: c.placeholder),
      itemColor: c.mute,
      itemSize: 18,
      prefixIcon: const Icon(CentIcons.search),
      suffixIcon: const Icon(CentIcons.clear),
      cursorColor: c.primary,
    );
  }
}
