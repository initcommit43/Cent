import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/cent_icons.dart';
import '../../core/theme/cent_theme.dart';
import '../../core/theme/cent_tokens.dart';
import '../../core/theme/cent_typography.dart';
import '../../core/widgets/cent_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/list_parts.dart';
import '../../core/widgets/search_field.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../transactions/widgets/entry_row.dart';
import 'activity_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(searchResultsProvider(_query)).value ?? const [];
    final now = ref.watch(clockProvider)();
    final margin = CentSpace.margin(MediaQuery.sizeOf(context).width);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                margin,
                CentSpace.sm,
                4,
                CentSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CentSearchField(
                      hint: l10n.searchTransactions,
                      controller: _controller,
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      l10n.cancel,
                      style: CentType.body.copyWith(color: c.primaryText),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: CentSpace.xl),
                      child: Text(
                        l10n.searchTip,
                        style: CentType.footnote.copyWith(color: c.mute),
                      ),
                    )
                  : results.isEmpty
                  ? Center(
                      child: EmptyState(
                        icon: CentIcons.search,
                        title: l10n.noMatchesFor(_query.trim()),
                        body: l10n.noMatchesBody,
                      ),
                    )
                  : ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        margin,
                        CentSpace.lg,
                        margin,
                        40,
                      ),
                      children: [
                        SectionHeader(title: l10n.resultsCount(results.length)),
                        CentGroup(
                          children: [
                            for (var i = 0; i < results.length; i++)
                              EntryRow(
                                view: results[i],
                                now: now,
                                subtitle: EntrySubtitle.date,
                                showDivider: i < results.length - 1,
                                onTap: () => context.push(
                                  Routes.activityEntry(results[i].entry.id),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
