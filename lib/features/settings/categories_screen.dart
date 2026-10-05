import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/format/dates.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/large_title_scaffold.dart';
import '../../core/widgets/list_parts.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../activity/activity_providers.dart';
import 'category_sheet.dart';

/// How many transactions each category has this month.
final _usageProvider = StreamProvider.autoDispose<Map<int, int>>((ref) {
  final now = ref.watch(clockProvider)();
  return ref
      .watch(transactionsRepositoryProvider)
      .watchRange(monthStart(now), nextMonthStart(now))
      .map((entries) {
        final counts = <int, int>{};
        for (final e in entries) {
          final id = e.entry.categoryId;
          if (id != null) counts[id] = (counts[id] ?? 0) + 1;
        }
        return counts;
      });
});

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(categoriesProvider).value ?? const [];
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return InlineScaffold(
      title: l10n.categories,
      backLabel: l10n.settings,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => unawaited(showCategorySheet(context)),
        child: Text(l10n.add),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, CentSpace.sm, margin, 40),
        children: [
          for (final (kind, title) in [
            (CategoryKind.expense, l10n.expenses),
            (CategoryKind.income, l10n.income),
          ]) ...[
            const SizedBox(height: CentSpace.lg),
            SectionHeader(title: title),
            _ReorderableGroup(
              categories: all.where((c) => c.kind == kind).toList(),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CentSpace.lg,
              8,
              CentSpace.lg,
              0,
            ),
            child: Text(
              l10n.categoriesReorderFooter,
              style: CentType.footnote.copyWith(color: context.colors.mute),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderableGroup extends ConsumerWidget {
  const _ReorderableGroup({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final usage = ref.watch(_usageProvider).value ?? const {};

    return ClipRRect(
      borderRadius: BorderRadius.circular(CentRadius.xl),
      child: ColoredBox(
        color: c.canvas,
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: categories.length,
          proxyDecorator: (child, _, _) => Material(
            color: c.elevated,
            elevation: 6,
            shadowColor: const Color(0x3310302B),
            child: child,
          ),
          onReorderItem: (from, to) {
            HapticFeedback.selectionClick();
            final ids = categories.map((cat) => cat.id).toList();
            ids.insert(to, ids.removeAt(from));
            unawaited(ref.read(categoriesRepositoryProvider).reorder(ids));
          },
          itemBuilder: (context, i) {
            final cat = categories[i];
            return InkWell(
              key: ValueKey(cat.id),
              onTap: () => unawaited(showCategorySheet(context, existing: cat)),
              highlightColor: c.hairline.withValues(alpha: 0.6),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: CentSpace.lg),
                    child: Row(
                      children: [
                        CategoryTile(
                          icon: CentIcons.named(cat.icon),
                          tint: CentTint.parse(cat.tint),
                          size: 32,
                        ),
                        const SizedBox(width: CentSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.name,
                                style: CentType.body.copyWith(color: c.ink),
                              ),
                              Text(
                                l10n.categoryUsage(usage[cat.id] ?? 0),
                                style: CentType.footnote.copyWith(
                                  color: c.mute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: Semantics(
                            label: l10n.reorderHandle(cat.name),
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: Icon(
                                CentIcons.grip,
                                size: 20,
                                color: c.mute,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < categories.length - 1) const InsetDivider(indent: 60),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
