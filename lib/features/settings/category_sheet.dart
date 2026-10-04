import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_button.dart';
import '../../core/widgets/cent_text_field.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/sheet.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../activity/activity_providers.dart';

const _icons = [
  'shopping-cart', 'utensils', 'coffee', 'bus', 'car', 'shirt', 'house', //
  'smartphone', 'heart-pulse', 'film', 'music', 'plane', 'graduation-cap',
  'dumbbell', 'gift', 'zap', 'baby', 'heart', 'briefcase', 'piggy-bank',
  'receipt', 'ellipsis',
];

/// Create a category, or edit [existing].
Future<void> showCategorySheet(BuildContext context, {Category? existing}) =>
    showCentSheet<void>(
      context,
      grouped: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _CategorySheet(existing: existing),
      ),
    );

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.existing});

  final Category? existing;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late String _icon = widget.existing?.icon ?? 'shopping-cart';
  late CentTint _tint = widget.existing == null
      ? CentTint.copper
      : CentTint.parse(widget.existing!.tint);
  late CategoryKind _kind = widget.existing?.kind ?? CategoryKind.expense;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(categoriesRepositoryProvider);
    if (widget.existing == null) {
      await repo.create(
        name: _name.text.trim(),
        icon: _icon,
        tint: _tint.name,
        kind: _kind,
      );
    } else {
      await repo.edit(
        widget.existing!.id,
        name: _name.text.trim(),
        icon: _icon,
        tint: _tint.name,
      );
    }
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) Navigator.of(context).pop();
  }

  /// Where an archived category's transactions go: "Other" of the same
  /// kind if it exists, otherwise the first remaining category.
  Category? _fallback() {
    final others = (ref.read(categoriesProvider).value ?? const [])
        .where((c) => c.kind == _kind && c.id != widget.existing!.id)
        .toList();
    return others.where((c) => c.icon == 'ellipsis').firstOrNull ??
        others.firstOrNull;
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final fallback = _fallback();
    if (fallback == null) return;
    final confirmed = await confirmDestructive(
      context,
      message: l10n.deleteCategoryConfirm(widget.existing!.name, fallback.name),
      action: l10n.deleteCategory,
    );
    if (!confirmed) return;
    await ref
        .read(categoriesRepositoryProvider)
        .archive(widget.existing!.id, fallbackId: fallback.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);
    final editing = widget.existing != null;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: CentType.footnote.copyWith(color: c.secondary)),
    );

    return Column(
      children: [
        SheetHeader(
          title: editing ? l10n.editCategory : l10n.newCategory,
          cancelLabel: l10n.cancel,
          actionLabel: l10n.save,
          onAction: _name.text.trim().isEmpty ? null : () => unawaited(_save()),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(margin, CentSpace.md, margin, 32),
            children: [
              Center(
                child: CategoryTile(
                  icon: CentIcons.named(_icon),
                  tint: _tint,
                  size: 72,
                ),
              ),
              const SizedBox(height: CentSpace.md),
              Text(
                _name.text.trim().isEmpty ? ' ' : _name.text.trim(),
                textAlign: TextAlign.center,
                style: CentType.title2.copyWith(color: c.ink),
              ),
              if (!editing) ...[
                const SizedBox(height: CentSpace.lg),
                CupertinoSlidingSegmentedControl<CategoryKind>(
                  groupValue: _kind,
                  backgroundColor: c.hairline,
                  thumbColor: c.canvas,
                  children: {
                    for (final (k, text) in [
                      (CategoryKind.expense, l10n.expense),
                      (CategoryKind.income, l10n.income),
                    ])
                      k: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          text,
                          style: CentType.subheadline.copyWith(color: c.ink),
                        ),
                      ),
                  },
                  onValueChanged: (k) => setState(() => _kind = k ?? _kind),
                ),
              ],
              const SizedBox(height: CentSpace.lg),
              CentTextField(
                label: l10n.fieldName,
                hint: l10n.categoryNameHint,
                controller: _name,
                autofocus: !editing,
                capitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              label(l10n.color),
              Row(
                children: [
                  for (final tint in CentTint.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Semantics(
                        button: true,
                        selected: tint == _tint,
                        label: tint.name,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _tint = tint);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: tint.foreground(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tint == _tint
                                    ? c.ink
                                    : Colors.transparent,
                                width: 2.5,
                                strokeAlign: BorderSide.strokeAlignOutside,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label(l10n.icon),
              LayoutBuilder(
                builder: (context, constraints) {
                  const columns = 6;
                  const gap = 10.0;
                  final size =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final icon in _icons)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _icon = icon);
                          },
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: icon == _icon
                                  ? _tint.background(c)
                                  : c.canvas,
                              borderRadius: BorderRadius.circular(14),
                              border: icon == _icon
                                  ? Border.all(color: c.primary, width: 2)
                                  : null,
                            ),
                            child: Icon(
                              CentIcons.named(icon),
                              size: 22,
                              color: icon == _icon
                                  ? _tint.foreground(c)
                                  : c.ink,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (editing) ...[
                const SizedBox(height: CentSpace.xxl),
                CentButton(
                  label: l10n.deleteCategory,
                  style: CentButtonStyle.destructive,
                  expand: true,
                  onPressed: () => unawaited(_delete()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
