import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import 'app_icons.dart';

final _php = NumberFormat('#,##0.00', 'en_PH');
String fmtPhp(double v) => _php.format(v.abs());

class AppSkeletonizer extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const AppSkeletonizer({
    super.key,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: enabled,
      effect: ShimmerEffect(
        baseColor: context.colors.borderSoft,
        highlightColor: context.colors.surface,
      ),
      child: child,
    );
  }
}

class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool shadow;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.shadow = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.colors.borderSoft),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: context.colors.cardShadow,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class ListRowCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool shadow;
  final Color? backgroundColor;
  final Color? borderColor;

  const ListRowCard({
    super.key,
    required this.child,
    this.onTap,
    this.minHeight = 76,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.radius = 16,
    this.shadow = false,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? context.colors.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? context.colors.borderSoft),
            boxShadow: shadow
                ? [
                    BoxShadow(
                      color: context.colors.cardShadow,
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final int maxLines;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.brandTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.brand, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          prefixIcon: Icon(AppIcons.search, color: context.colors.hint),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 48, minHeight: 48),
          filled: true,
          fillColor: context.colors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.colors.borderSoft),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.colors.borderSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.colors.brand),
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const AppTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class FilterChipItem {
  final String value;
  final String label;
  final int count;

  const FilterChipItem({
    required this.value,
    required this.label,
    required this.count,
  });
}

class FilterChipsRow extends StatelessWidget {
  final List<FilterChipItem> items;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  const FilterChipsRow({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _FilterChip(
              item: items[index],
              selected: items[index].value == selectedValue,
              onTap: () => onSelected(items[index].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final FilterChipItem item;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.brand : context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? context.colors.brand : context.colors.border,
            ),
          ),
          child: Text(
            '${item.label} (${item.count})',
            maxLines: 1,
            style: TextStyle(
              color:
                  selected ? context.colors.onHeader : context.colors.textBody,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colors.brandTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: context.colors.hint, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textBody, fontSize: 13),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.error, color: context.colors.danger, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: context.colors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(AppIcons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;
  final bool loading;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.danger = false,
    this.loading = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        danger: danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surface,
      title: Text(
        title,
        style: TextStyle(color: context.colors.textPrimary),
      ),
      content: Text(
        message,
        style: TextStyle(color: context.colors.textBody),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: loading ? null : () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor:
                danger ? context.colors.danger : context.colors.brand,
            foregroundColor: context.colors.onHeader,
          ),
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.onHeader,
                  ),
                )
              : Text(confirmLabel),
        ),
      ],
    );
  }
}

class AppHeader extends StatelessWidget {
  final String name;
  final String initials;
  final String subtitle;
  final int notificationCount;
  final VoidCallback onNotifications;
  final Widget Function(BuildContext context, bool compact)? moreActionBuilder;
  final bool showLogout;
  final bool softBackground;
  final bool scaleHeightForText;

  const AppHeader({
    super.key,
    required this.name,
    required this.initials,
    required this.subtitle,
    required this.notificationCount,
    required this.onNotifications,
    this.moreActionBuilder,
    this.showLogout = true,
    this.softBackground = false,
    this.scaleHeightForText = false,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textScaler = MediaQuery.textScalerOf(context);
    final contentHeight = scaleHeightForText
        ? (textScaler.scale(26) + 16).clamp(72.0, 120.0).toDouble()
        : 72.0;
    final headerTextColor =
        softBackground ? context.colors.textPrimary : context.colors.onHeader;
    final actionColor =
        softBackground ? context.colors.brand : context.colors.onHeader;

    return Container(
      width: double.infinity,
      height: topInset + contentHeight,
      color: softBackground ? context.colors.background : context.colors.header,
      child: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: SizedBox(
            width: double.infinity,
            height: contentHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: context.colors.avatarBackground,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: isDark
                            ? context.colors.textPrimary
                            : context.colors.onGold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: headerTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: softBackground
                                ? context.colors.textBody
                                : context.colors.onHeader
                                    .withValues(alpha: .75),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ThemeToggleButton(
                    color: actionColor,
                    pill: true,
                    pillBackground:
                        softBackground ? context.colors.surface : null,
                    outlinedPill: softBackground,
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Notifications',
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: softBackground
                          ? BoxDecoration(
                              color: context.colors.surface,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: context.colors.borderSoft),
                            )
                          : null,
                      child: IconButton(
                        onPressed: onNotifications,
                        icon: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              AppIcons.bell,
                              color: actionColor,
                              size: 22,
                            ),
                            if (notificationCount > 0)
                              Positioned(
                                top: 3,
                                right: 3,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: context.colors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Text(
                                        '$notificationCount',
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: softBackground
                                              ? context.colors.onHeader
                                              : context.colors.background,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (showLogout) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Log out',
                      child: IconButton(
                        onPressed: () => confirmLogout(context),
                        icon: Icon(
                          AppIcons.logout,
                          color: actionColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                  if (moreActionBuilder != null) ...[
                    const SizedBox(width: 8),
                    moreActionBuilder!(context, compact),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeNavigationItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;

  const HomeNavigationItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });
}

class ScholarBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<HomeNavigationItem> items;
  final double height;
  final bool selectedIconPill;
  final bool scaleHeightForText;

  const ScholarBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = const [
      HomeNavigationItem(
          label: 'Home', icon: AppIcons.homeOutline, activeIcon: AppIcons.home),
      HomeNavigationItem(label: 'Transactions', icon: AppIcons.chart),
      HomeNavigationItem(
          label: 'My Payouts',
          icon: AppIcons.payouts,
          activeIcon: AppIcons.payouts),
      HomeNavigationItem(label: 'Profile', icon: AppIcons.user),
    ],
    this.height = 56,
    this.selectedIconPill = false,
    this.scaleHeightForText = false,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = scaleHeightForText
        ? height
            .clamp(
              MediaQuery.textScalerOf(context).scale(12) + 39,
              double.infinity,
            )
            .toDouble()
        : height;
    return SafeArea(
      top: false,
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(
            top: BorderSide(color: context.colors.borderSoft),
          ),
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _ScholarNavigationItem(
                  label: items[index].label,
                  icon: currentIndex == index
                      ? (items[index].activeIcon ?? items[index].icon)
                      : items[index].icon,
                  selected: currentIndex == index,
                  selectedIconPill: selectedIconPill,
                  onTap: () => onTap(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScholarNavigationItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool selectedIconPill;
  final VoidCallback onTap;

  const _ScholarNavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedIconPill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colors.brand : context.colors.textBody;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected && selectedIconPill)
              Container(
                width: 54,
                height: 34,
                decoration: BoxDecoration(
                  color: context.colors.brandTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: color),
              )
            else
              Icon(icon, size: 20, color: color),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 18,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? context.colors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Balance summary card.
class BalanceCard extends StatelessWidget {
  final double balance;
  final Color? backgroundColor;
  final String label;
  final String subtitle;
  final IconData actionIcon;
  final String actionTooltip;
  final VoidCallback? onAction;

  const BalanceCard({
    super.key,
    required this.balance,
    this.backgroundColor,
    this.label = 'CURRENT BALANCE',
    this.subtitle = 'Money received and verified by QR',
    this.actionIcon = AppIcons.copy,
    this.actionTooltip = 'Copy balance',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final amount = 'PHP ${fmtPhp(balance)}';
    Future<void> copyBalance() async {
      await Clipboard.setData(ClipboardData(text: amount));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balance copied')),
        );
      }
    }

    final action = onAction ?? copyBalance;

    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textBody,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            IconButton(
              tooltip: actionTooltip,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(
                actionIcon,
                color: context.colors.textBody,
                size: 18,
              ),
              onPressed: action,
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            maxLines: 1,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: context.colors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textBody,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: child,
    );
  }
}

enum AllowanceCardState { waiting, received, cancelled, notReleased }

class MonthlyAllowanceCard extends StatelessWidget {
  final String title;
  final double amount;
  final AllowanceCardState state;
  final String? issuedDate;
  final String? receivedDate;
  final DateTime? distributionDate;
  final DateTime? expectedReleaseDate;
  final String? academicPeriod;
  final VoidCallback? onPrimaryAction;
  final int waitingCount;
  final double? waitingTotal;
  final bool statusOnRight;

  const MonthlyAllowanceCard({
    super.key,
    required this.title,
    required this.amount,
    required this.state,
    this.issuedDate,
    this.receivedDate,
    this.distributionDate,
    this.expectedReleaseDate,
    this.academicPeriod,
    this.onPrimaryAction,
    this.waitingCount = 1,
    this.waitingTotal,
    this.statusOnRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = state == AllowanceCardState.waiting;
    final received = state == AllowanceCardState.received;
    final cancelled = state == AllowanceCardState.cancelled;
    final today = DateTime.now();
    final expectedDate = expectedReleaseDate;
    final releaseDate = expectedDate == null
        ? null
        : DateTime(
            expectedDate.year,
            expectedDate.month,
            expectedDate.day,
          );
    final daysUntilRelease = releaseDate
        ?.difference(DateTime(today.year, today.month, today.day))
        .inDays;

    final statusLabel = waiting
        ? 'Waiting for scan'
        : received
            ? 'Received'
            : 'Cancelled';
    final statusColor = waiting
        ? context.colors.warningText
        : received
            ? context.colors.successText
            : context.colors.dangerText;
    final statusBackground = waiting
        ? context.colors.warningBg
        : received
            ? context.colors.successBg
            : context.colors.dangerBg;

    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.brandTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(AppIcons.calendar,
                    color: context.colors.brand, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTHLY ALLOWANCE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textBody,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (statusOnRight)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (waiting || received || cancelled)
                            StatusChip(
                              statusLabel,
                              color: statusColor,
                              bg: statusBackground,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (statusOnRight && (waiting || received || cancelled)) ...[
                const SizedBox(width: 8),
                StatusChip(
                  statusLabel,
                  color: statusColor,
                  bg: statusBackground,
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'PHP ${fmtPhp(amount)}',
                maxLines: 1,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (received && (issuedDate != null || receivedDate != null)) ...[
            Divider(height: 1, color: context.colors.borderSoft),
            const SizedBox(height: 12),
            Row(
              children: [
                if (issuedDate != null)
                  Expanded(
                    child: _AllowanceDateColumn(
                      label: 'Released',
                      date: issuedDate!,
                    ),
                  ),
                if (issuedDate != null && receivedDate != null)
                  const SizedBox(width: 12),
                if (receivedDate != null)
                  Expanded(
                    child: _AllowanceDateColumn(
                      label: 'Received',
                      date: receivedDate!,
                    ),
                  ),
              ],
            ),
          ] else if (waiting) ...[
            if (issuedDate != null)
              _AllowanceDateRow(label: 'Released', date: issuedDate),
            if (waitingCount > 1) ...[
              const SizedBox(height: 6),
              Text(
                '$waitingCount payouts waiting • Total PHP '
                '${fmtPhp(waitingTotal ?? amount)}',
                style: TextStyle(
                  color: context.colors.textBody,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Scan the QR from the admin to receive it.',
              style: TextStyle(color: context.colors.textBody, fontSize: 12),
            ),
          ] else if (cancelled) ...[
            Text(
              'Cancelled by the administrator.',
              style: TextStyle(color: context.colors.textBody, fontSize: 12),
            ),
          ] else ...[
            Text(
              'No allowance released yet. You will be notified when it is released.',
              style: TextStyle(color: context.colors.textBody, fontSize: 12),
            ),
          ],
          if (!waiting && releaseDate != null) ...[
            const SizedBox(height: 12),
            _AllowanceDateRow(
              label: 'Expected release',
              date: DateFormat('MMM d, yyyy').format(releaseDate),
              demoData: true,
              trailing: releaseDate
                      .isBefore(DateTime(today.year, today.month, today.day))
                  ? StatusChip(
                      'Release pending',
                      color: context.colors.warningText,
                      bg: context.colors.warningBg,
                    )
                  : StatusChip(
                      'in ${daysUntilRelease!} '
                      '${daysUntilRelease == 1 ? 'day' : 'days'}',
                      color: daysUntilRelease <= 7
                          ? context.colors.warningText
                          : context.colors.textBody,
                      bg: daysUntilRelease <= 7
                          ? context.colors.warningBg
                          : context.colors.borderSoft,
                    ),
            ),
          ],
          if (academicPeriod != null && academicPeriod!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(
                  academicPeriod!,
                  color: context.colors.textPrimary,
                  bg: context.colors.brandTint,
                ),
                StatusChip(
                  'Demo data',
                  color: context.colors.textBody,
                  bg: context.colors.borderSoft,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AllowanceDateColumn extends StatelessWidget {
  final String label;
  final String date;

  const _AllowanceDateColumn({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: context.colors.textBody, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          date,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AllowanceDateRow extends StatelessWidget {
  final String label;
  final String? date;
  final bool demoData;
  final Widget? trailing;

  const _AllowanceDateRow({
    required this.label,
    required this.date,
    this.demoData = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 12,
            ),
          ),
          Text(
            date ?? 'Date unavailable',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (demoData)
            StatusChip(
              'Demo data',
              color: context.colors.textBody,
              bg: context.colors.borderSoft,
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Fingerprint registration status + call to action.
class BiometricStatusCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool highlighted;

  const BiometricStatusCard({
    super.key,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              highlighted ? context.colors.warningBg : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlighted
                ? context.colors.warning.withValues(alpha: .38)
                : context.colors.borderSoft,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.cardShadow,
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: highlighted
                    ? context.colors.warning.withValues(alpha: .2)
                    : context.colors.brandTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                highlighted ? AppIcons.shieldCheck : AppIcons.fingerprint,
                color:
                    highlighted ? context.colors.warning : context.colors.brand,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable device biometrics',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Required to confirm allowance payouts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, color: context.colors.textBody),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, color: context.colors.textBody),
          ],
        ),
      ),
    );
  }
}

/// Quick-access icon button.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tileColor;
  final Color? iconColor;
  final String? description;
  final int? badge;

  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tileColor,
    this.iconColor,
    this.description,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.borderSoft),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tileColor ?? context.colors.brandTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: iconColor ?? context.colors.brand, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textBody,
                    ),
                  ),
                ],
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.colors.dangerBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$badge',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? backgroundColor;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ??
          (isDark ? context.colors.header : context.colors.brand),
      foregroundColor: context.colors.onHeader,
      minimumSize: const Size.fromHeight(52),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.onHeader,
            ),
          )
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.onHeader,
              fontWeight: FontWeight.w700,
            ),
          );
    if (icon == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: style,
            child: child,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: style,
          child: loading
              ? child
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: context.colors.onHeader),
                    const SizedBox(width: 8),
                    Flexible(child: child),
                  ],
                ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool danger;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.danger : context.colors.textPrimary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(
              color: danger ? context.colors.danger : context.colors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.brandTint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: context.colors.brand, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textBody),
          ),
        ],
      ),
    );
  }
}

class DashboardStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tileColor;
  final Color iconColor;
  final String? detail;
  final VoidCallback onTap;

  const DashboardStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tileColor,
    required this.iconColor,
    required this.onTap,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.borderSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textBody,
                        fontSize: 12,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.textBody,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: context.colors.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Transaction list tile used on Home and History.
class TxTile extends StatelessWidget {
  final WalletTransaction tx;
  const TxTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == TxType.credit;
    final isReceipt =
        '${tx.title} ${tx.subtitle}'.toLowerCase().contains('receipt');
    final amountColor =
        isCredit ? AppTheme.successGreen : context.colors.textPrimary;
    final secondaryTextColor = context.colors.hint;
    final bg = isReceipt
        ? context.colors.brandTint
        : isCredit
            ? context.colors.successBg
            : context.colors.dangerBg;
    final child = Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: bg,
          child: Icon(
            isReceipt
                ? AppIcons.receipt
                : isCredit
                    ? AppIcons.plus
                    : AppIcons.minus,
            color: context.colors.brand,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: context.colors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                tx.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: secondaryTextColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: Text(
            tx.status == TxStatus.pending
                ? 'Pending'
                : '${isCredit ? '+' : '-'}${fmtPhp(tx.amount)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: tx.status == TxStatus.pending ? 11 : 14,
              fontWeight: FontWeight.w700,
              color: tx.status == TxStatus.pending
                  ? secondaryTextColor
                  : amountColor,
            ),
          ),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: child,
    );
  }
}

class HomeActivityRow extends StatelessWidget {
  final WalletTransaction transaction;
  final String friendlyDate;
  final String? statusLabel;
  final bool inCard;

  const HomeActivityRow({
    super.key,
    required this.transaction,
    required this.friendlyDate,
    this.statusLabel,
    this.inCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == TxType.credit;
    final row = Padding(
      padding: inCard
          ? const EdgeInsets.symmetric(vertical: 14)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  isCredit ? context.colors.successBg : context.colors.dangerBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isCredit ? AppIcons.plus : AppIcons.minus,
              color: isCredit ? context.colors.success : context.colors.danger,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel == null
                      ? friendlyDate
                      : '$friendlyDate • $statusLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${isCredit ? '+' : '-'}PHP ${fmtPhp(transaction.amount)}',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: isCredit
                      ? context.colors.success
                      : context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (inCard) return row;
    return ListRowCard(
      minHeight: 72,
      child: row,
    );
  }
}

class HomeNotificationsCard extends StatelessWidget {
  final int count;
  final String latestMessage;
  final String? friendlyTime;
  final VoidCallback onViewAll;

  const HomeNotificationsCard({
    super.key,
    required this.count,
    required this.latestMessage,
    this.friendlyTime,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.brandTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.bell, color: context.colors.brand, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.dangerBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  color: context.colors.brand,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  latestMessage,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (friendlyTime != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                friendlyTime!,
                style: TextStyle(
                  color: context.colors.textBody,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small colored status chip.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bg;
  const StatusChip(this.label,
      {super.key, this.color = AppTheme.successGreen, this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg ?? context.colors.successBg,
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
              color: color)),
    );
  }
}

/// Renders the single-use QR for one allowance claim.
class ClaimQrPanel extends StatelessWidget {
  final AllowanceClaim claim;
  final double size;
  const ClaimQrPanel({super.key, required this.claim, this.size = 190});

  @override
  Widget build(BuildContext context) {
    final received = claim.isReceived;
    final voided = claim.isVoided;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(
        children: [
          Opacity(
            opacity: (received || voided) ? .25 : 1,
            child: SizedBox(
              width: size,
              height: size,
              child: QrImageView(
                data: claim.qrPayload,
                version: QrVersions.auto,
                size: size,
                gapless: true,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1A2530),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A2530),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            claim.token,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10,
                letterSpacing: .5,
                color: AppTheme.textMuted,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

/// Snackbar helper.
void showMsg(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppTheme.dangerRed : AppTheme.successGreen,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Shows a confirmation dialog before signing out.
void confirmLogout(BuildContext context) {
  final navigator = Navigator.of(context);
  final state = context.read<AppState>();

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      var isBusy = false;
      String? errorMessage;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final colors = context.colors;
          final errorColor = Theme.of(context).colorScheme.error;

          return PopScope(
            canPop: !isBusy,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.dangerBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(AppIcons.logout, color: context.colors.textPrimary),
              ),
              title: Text(
                'Log out?',
                style: TextStyle(color: colors.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to log out of Scholar Wallet?',
                    style: TextStyle(color: colors.textBody),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: TextStyle(color: errorColor),
                    ),
                  ],
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.border),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isBusy
                            ? null
                            : () async {
                                setDialogState(() {
                                  isBusy = true;
                                  errorMessage = null;
                                });
                                try {
                                  await state.logout();
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).pop();
                                  navigator.popUntil((route) => route.isFirst);
                                } catch (error) {
                                  if (!dialogContext.mounted) return;
                                  setDialogState(() {
                                    isBusy = false;
                                    errorMessage = 'Could not log out: $error';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: errorColor,
                          foregroundColor:
                              Theme.of(context).colorScheme.onError,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isBusy
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.colors.onHeader,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Log out'),
                                ],
                              )
                            : const Text('Log out'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// App-bar / header button that flips between light and dark mode.
class ThemeToggleButton extends StatelessWidget {
  final Color? color;
  final bool pill;
  final Color? pillBackground;
  final bool outlinedPill;
  const ThemeToggleButton({
    super.key,
    this.color,
    this.pill = false,
    this.pillBackground,
    this.outlinedPill = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    void toggleTheme() {
      context
          .read<AppState>()
          .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
    }

    if (!pill) {
      return IconButton(
        tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        icon: Icon(
          isDark ? AppIcons.sun : AppIcons.moon,
          color: color ?? context.colors.textPrimary,
          size: 22,
        ),
        onPressed: toggleTheme,
      );
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final label = isDark ? 'Switch to light mode' : 'Switch to dark mode';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: toggleTheme,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 56,
              height: 44,
              decoration: BoxDecoration(
                color: pillBackground ??
                    context.colors.onHeader.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(22),
                border: outlinedPill
                    ? Border.all(color: context.colors.borderSoft)
                    : null,
              ),
              child: Center(
                child: AnimatedAlign(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment:
                      isDark ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isDark ? AppIcons.moon : AppIcons.sun,
                        size: 18,
                        color: context.colors.brand,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scholar: shows the Payout QR issued to them. They can screenshot it and
/// later choose the image from the gallery inside the scanner. The QR alone
/// is not proof of identity: the server still checks the signed-in scholar,
/// the payout status, and that the QR was not used before.
Future<void> showPayoutQrSheet(BuildContext context, AllowanceClaim claim,
    {VoidCallback? onScan}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Allowance ready: PHP ${fmtPhp(claim.amount)}',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(claim.batchTitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 14),
            ClaimQrPanel(claim: claim, size: 220),
            const SizedBox(height: 12),
            const Text(
              'Take a screenshot of this QR, then tap Scan and choose it from your gallery. It can only be used once.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            if (onScan != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onScan();
                  },
                  icon: Icon(
                    AppIcons.qrScan,
                    size: 18,
                    color: context.colors.onHeader,
                  ),
                  label: const Text('Scan to receive'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
