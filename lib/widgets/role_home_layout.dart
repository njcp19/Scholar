import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'widgets.dart';

class RoleHomeLayout extends StatelessWidget {
  final String headerName;
  final String headerInitials;
  final String headerSubtitle;
  final int notificationCount;
  final VoidCallback onNotifications;
  final Widget Function(BuildContext, bool)? headerActions;
  final String heroLabel;
  final String heroValue;
  final String heroSupportingLine;
  final Color? heroColor;
  final IconData? heroActionIcon;
  final String? heroActionTooltip;
  final VoidCallback? onHeroAction;
  final Widget? infoChip;
  final Widget? mainCard;
  final List<Widget> summaryCards;
  final String? summaryTitle;
  final int summaryColumns;
  final String quickAccessTitle;
  final List<Widget> quickAccessTiles;
  final String? listTitle;
  final Widget? listTrailing;
  final List<Widget> listRows;
  final Widget? listEmptyState;
  final bool showListEmptyState;
  final Widget? noticeCard;
  final bool loading;
  final String? errorMessage;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRefresh;
  final List<HomeNavigationItem> navigationItems;
  final int navigationIndex;
  final ValueChanged<int> onNavigationTap;

  const RoleHomeLayout({
    super.key,
    required this.headerName,
    required this.headerInitials,
    required this.headerSubtitle,
    required this.notificationCount,
    required this.onNotifications,
    this.headerActions,
    required this.heroLabel,
    required this.heroValue,
    required this.heroSupportingLine,
    this.heroColor,
    this.heroActionIcon,
    this.heroActionTooltip,
    this.onHeroAction,
    this.infoChip,
    this.mainCard,
    this.summaryCards = const [],
    this.summaryTitle,
    this.summaryColumns = 2,
    required this.quickAccessTitle,
    required this.quickAccessTiles,
    this.listTitle,
    this.listTrailing,
    this.listRows = const [],
    this.listEmptyState,
    this.showListEmptyState = false,
    this.noticeCard,
    required this.loading,
    this.errorMessage,
    required this.onRetry,
    required this.onRefresh,
    required this.navigationItems,
    required this.navigationIndex,
    required this.onNavigationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          AppHeader(
            name: headerName,
            initials: headerInitials,
            subtitle: headerSubtitle,
            notificationCount: notificationCount,
            onNotifications: onNotifications,
            moreActionBuilder: headerActions,
          ),
          Expanded(
            child: ClipRect(
              child: ScrollConfiguration(
                behavior: const _NoStretchScrollBehavior(),
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  edgeOffset: 0,
                  child: ContentWidth(
                    child: ListView(
                      physics: const ClampingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        AppSkeletonizer(
                          enabled: loading,
                          child: _hero(context),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          ErrorCard(
                            message: errorMessage!,
                            onRetry: onRetry,
                          ),
                        ],
                        if (infoChip != null) ...[
                          const SizedBox(height: 16),
                          AppSkeletonizer(enabled: loading, child: infoChip!),
                        ],
                        if (mainCard != null) ...[
                          const SizedBox(height: 16),
                          AppSkeletonizer(enabled: loading, child: mainCard!),
                        ],
                        if (summaryCards.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          SectionLabel(
                            summaryTitle ?? '',
                            labelColor: context.colors.textBody,
                          ),
                          const SizedBox(height: 8),
                          AppSkeletonizer(
                            enabled: loading,
                            child: _tileGrid(
                              summaryCards,
                              columns: summaryColumns,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SectionLabel(
                          quickAccessTitle,
                          labelColor: context.colors.textBody,
                        ),
                        const SizedBox(height: 8),
                        AppSkeletonizer(
                          enabled: loading,
                          child: _tileGrid(quickAccessTiles),
                        ),
                        if (listTitle != null) ...[
                          const SizedBox(height: 24),
                          SectionLabel(
                            listTitle!,
                            labelColor: context.colors.textBody,
                            trailing: listTrailing,
                          ),
                          const SizedBox(height: 8),
                          if (showListEmptyState)
                            listEmptyState ??
                                const EmptyStateCard(
                                  icon: AppIcons.receipt,
                                  message: 'Nothing here yet.',
                                ),
                          if (listRows.isNotEmpty)
                            AppSkeletonizer(
                              enabled: loading,
                              child: Column(
                                children: [
                                  for (var i = 0; i < listRows.length; i++) ...[
                                    if (i > 0) const SizedBox(height: 8),
                                    listRows[i],
                                  ],
                                ],
                              ),
                            ),
                        ],
                        if (noticeCard != null) ...[
                          const SizedBox(height: 16),
                          noticeCard!,
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ScholarBottomNavigation(
        currentIndex: navigationIndex,
        items: navigationItems,
        onTap: onNavigationTap,
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: heroColor ?? context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  heroLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (onHeroAction != null)
                IconButton(
                  tooltip: heroActionTooltip,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: onHeroAction,
                  icon: Icon(
                    heroActionIcon ?? AppIcons.edit,
                    color: context.colors.textBody,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              heroValue,
              maxLines: 1,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            heroSupportingLine,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileGrid(List<Widget> tiles, {int columns = 3}) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var start = 0; start < tiles.length; start += columns) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      final end =
          (start + columns < tiles.length) ? start + columns : tiles.length;
      final rowTiles = tiles.sublist(start, end);
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rowTiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: rowTiles[i]),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
