import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/cent_theme.dart';

/// Top-level screen with an iOS large title that collapses to an inline
/// title on scroll.
class LargeTitleScaffold extends StatelessWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    this.trailing,
    this.slivers = const [],
  });

  final String title;
  final Widget? trailing;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            trailing: trailing,
            backgroundColor: c.material,
            border: Border(bottom: BorderSide(color: c.hairline, width: 0)),
            stretch: true,
          ),
          ...slivers,
          // Keeps the last item clear of the translucent tab bar.
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 80,
            ),
          ),
        ],
      ),
    );
  }
}
