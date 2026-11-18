import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import 'app_icons.dart';

final _php = NumberFormat('#,##0.00', 'en_PH');
String fmtPhp(double v) => _php.format(v.abs());

class AppSkeletonizer extends StatelessWidget {
  final bool enabled;
  final Widget child;
  final bool? reduceMotion;
  final Color? baseColor;
  final Color? highlightColor;

  const AppSkeletonizer({
    super.key,
    required this.enabled,
    required this.child,
    this.reduceMotion,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final static = reduceMotion ?? MediaQuery.disableAnimationsOf(context);
    final base = baseColor ?? context.colors.skeletonBase;
    final highlight = highlightColor ?? context.colors.skeletonHighlight;
    return Skeletonizer(
      enabled: enabled,
      effect: static
          ? SolidColorEffect(color: base)
          : ShimmerEffect(
              baseColor: base,
              highlightColor: highlight,
              duration: const Duration(milliseconds: 1400),
            ),
      child: enabled
          ? Semantics(
              container: true,
              liveRegion: true,
              label: 'Loading',
              child: ExcludeSemantics(child: child),
            )
          : child,
    );
  }
}

class AppInitialLoadView extends StatefulWidget {
  final bool firstLoadPending;
  final Widget skeleton;
  final Widget child;

  const AppInitialLoadView({
    super.key,
    required this.firstLoadPending,
    required this.skeleton,
    required this.child,
  });

  @override
  State<AppInitialLoadView> createState() => _AppInitialLoadViewState();
}

class _AppInitialLoadViewState extends State<AppInitialLoadView> {
  static const _showDelay = Duration(milliseconds: 150);
  static const _minimumVisible = Duration(milliseconds: 400);

  Timer? _showTimer;
  Timer? _minimumTimer;
  bool _skeletonVisible = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _finished = !widget.firstLoadPending;
    if (!_finished) _scheduleSkeleton();
  }

  @override
  void didUpdateWidget(covariant AppInitialLoadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_finished || oldWidget.firstLoadPending == widget.firstLoadPending) {
      return;
    }
    if (widget.firstLoadPending) {
      _scheduleSkeleton();
      return;
    }
    _showTimer?.cancel();
    if (!_skeletonVisible || _minimumTimer == null) {
      _finish();
    }
  }

  void _scheduleSkeleton() {
    _showTimer?.cancel();
    _showTimer = Timer(_showDelay, () {
      if (!mounted || _finished) return;
      setState(() {
        _skeletonVisible = true;
      });
      _minimumTimer = Timer(_minimumVisible, () {
        _minimumTimer = null;
        if (!widget.firstLoadPending) _finish();
      });
    });
  }

  void _finish() {
    if (!mounted || _finished) return;
    _showTimer?.cancel();
    _minimumTimer?.cancel();
    setState(() => _finished = true);
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _minimumTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;
    if (!_skeletonVisible) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: 'Loading',
          child: const CircularProgressIndicator(),
        ),
      );
    }
    return AppSkeletonizer(enabled: true, child: widget.skeleton);
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.colors.skeletonBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) => SkeletonBox(
        width: width,
        height: height,
        radius: height / 2,
      );
}

class SkeletonCircle extends StatelessWidget {
  final double diameter;

  const SkeletonCircle({super.key, required this.diameter});

  @override
  Widget build(BuildContext context) => SkeletonBox(
        width: diameter,
        height: diameter,
        radius: diameter / 2,
      );
}

class SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        radius: radius,
        padding: padding,
        shadow: true,
        child: child,
      );
}

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Row(
            children: [
              SkeletonCircle(diameter: 44),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(width: 150, height: 15),
                    SizedBox(height: 8),
                    SkeletonLine(width: 100, height: 11),
                  ],
                ),
              ),
              SkeletonCircle(diameter: 40),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonBox(height: 170, radius: 28),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: SkeletonBox(height: 56, radius: 18)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 56, radius: 18)),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonCard(
            radius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: SkeletonLine(width: 142, height: 14)),
                    SkeletonBox(width: 72, height: 26, radius: 13),
                  ],
                ),
                SizedBox(height: 18),
                SkeletonLine(width: 180, height: 30),
                SizedBox(height: 16),
                SkeletonLine(height: 12),
                SizedBox(height: 8),
                SkeletonLine(width: 210, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SkeletonLine(width: 126, height: 14),
          const SizedBox(height: 12),
          SkeletonCard(
            radius: 22,
            child: Column(
              children: [
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0) const SizedBox(height: 18),
                  const Row(
                    children: [
                      SkeletonCircle(diameter: 42),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(width: 138, height: 13),
                            SizedBox(height: 8),
                            SkeletonLine(width: 94, height: 11),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      SkeletonLine(width: 76, height: 14),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}

class TransactionLoadingSkeleton extends StatelessWidget {
  const TransactionLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const SkeletonBox(height: 50, radius: 16),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: SkeletonBox(height: 36, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 36, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 36, radius: 18)),
            ],
          ),
          const SizedBox(height: 20),
          const SkeletonLine(width: 120, height: 13),
          const SizedBox(height: 12),
          SkeletonCard(
            child: Column(
              children: [
                for (var index = 0; index < 5; index++) ...[
                  if (index > 0) const SizedBox(height: 18),
                  const Row(
                    children: [
                      SkeletonCircle(diameter: 42),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(width: 145, height: 13),
                            SizedBox(height: 8),
                            SkeletonLine(width: 92, height: 11),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SkeletonLine(width: 72, height: 13),
                          SizedBox(height: 8),
                          SkeletonBox(width: 58, height: 20, radius: 8),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}

class RegistrationLoadingSkeleton extends StatelessWidget {
  const RegistrationLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const SkeletonBox(height: 50, radius: 16),
          const SizedBox(height: 12),
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SkeletonBox(width: 66, height: 36, radius: 18),
                SizedBox(width: 8),
                SkeletonBox(width: 92, height: 36, radius: 18),
                SizedBox(width: 8),
                SkeletonBox(width: 100, height: 36, radius: 18),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SkeletonLine(width: 168, height: 13),
          const SizedBox(height: 12),
          for (var index = 0; index < 4; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            SkeletonCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const SkeletonCircle(diameter: 44),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(width: 148, height: 14),
                        SizedBox(height: 7),
                        SkeletonLine(width: 118, height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 90, height: 22, radius: 9),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    AppIcons.chevronRight,
                    color: context.colors.skeletonBase,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ],
      );
}

bool isOfflineLoadError(Object error) {
  if (error is TimeoutException ||
      error is FirebaseException && error.code == 'network-request-failed') {
    return true;
  }
  final type = error.runtimeType.toString().toLowerCase();
  if (type == 'socketexception' ||
      type == 'httpexception' ||
      type == 'handshakeexception' ||
      type == 'clientexception') {
    return true;
  }
  final details = error is PostgrestException
      ? '${error.message} ${error.details} ${error.hint}'
      : error.toString();
  final message = details.toLowerCase();
  return message.contains('clientexception') ||
      message.contains('socketexception') ||
      message.contains('networkerror') ||
      message.contains('network error') ||
      message.contains('failed to fetch') ||
      message.contains('failed host lookup') ||
      message.contains('failed to connect') ||
      message.contains('network is unreachable') ||
      message.contains('connection refused') ||
      message.contains('connection reset') ||
      message.contains('connection aborted') ||
      message.contains('timed out');
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
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final Clip clipBehavior;
  final VoidCallback? onTap;
  final bool heroCircles;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.shadow = false,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    this.clipBehavior = Clip.none,
    this.onTap,
    this.heroCircles = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveClipBehavior =
        heroCircles && clipBehavior == Clip.none ? Clip.hardEdge : clipBehavior;
    final cardChild = heroCircles
        ? Stack(
            children: [
              Positioned(
                top: -105,
                right: -78,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: context.colors.onHeader.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -116,
                left: -92,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    color: context.colors.onHeader.withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              child,
            ],
          )
        : child;
    final decoration = BoxDecoration(
      color:
          gradient == null ? backgroundColor ?? context.colors.surface : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? context.colors.borderSoft,
        width: borderWidth,
      ),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: context.colors.cardShadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );
    if (onTap != null) {
      final ink = Ink(
        width: double.infinity,
        padding: padding,
        decoration: decoration,
        child: cardChild,
      );
      final clippedInk = effectiveClipBehavior == Clip.none
          ? ink
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: effectiveClipBehavior,
              child: ink,
            );
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: clippedInk,
      );
    }

    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: effectiveClipBehavior,
      decoration: decoration,
      child: cardChild,
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
  final double borderWidth;

  const ListRowCard({
    super.key,
    required this.child,
    this.onTap,
    this.minHeight = 76,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.radius = 22,
    this.shadow = false,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
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
            border: Border.all(
              color: borderColor ?? context.colors.borderSoft,
              width: borderWidth,
            ),
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
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;
  final Color? textColor;
  final String? emphasizedPrefix;
  final Widget? leading;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fontSize;
  final double? textHeight;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.maxLines = 2,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
    this.textColor,
    this.emphasizedPrefix,
    this.leading,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 14,
    this.fontSize = 13,
    this.textHeight,
  });

  @override
  Widget build(BuildContext context) {
    final warningNote = backgroundColor == context.colors.warningBg;
    final effectiveBorderColor =
        borderColor ?? (warningNote ? context.colors.warningBorder : null);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.colors.brandTint,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorderColor == null
            ? null
            : Border.all(color: effectiveBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading ??
              Icon(
                icon,
                color: warningNote
                    ? context.colors.goldTintText
                    : iconColor ?? context.colors.brand,
                size: 20,
              ),
          SizedBox(width: leading == null ? 10 : 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: warningNote
                      ? context.colors.goldTintText
                      : textColor ?? context.colors.textPrimary,
                  fontSize: fontSize,
                  height: textHeight,
                ),
                children: emphasizedPrefix != null &&
                        message.startsWith(emphasizedPrefix!)
                    ? [
                        TextSpan(
                          text: emphasizedPrefix,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                            text: message.substring(emphasizedPrefix!.length)),
                      ]
                    : [TextSpan(text: message)],
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
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
  final Widget? suffixIcon;
  final double radius;
  final double minHeight;
  final Color? hintColor;
  final Color? iconColor;
  final Color? borderColor;
  final double iconSize;

  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.suffixIcon,
    this.radius = 16,
    this.minHeight = 50,
    this.hintColor,
    this.iconColor,
    this.borderColor,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: hintColor == null ? null : TextStyle(color: hintColor),
          suffixIcon: suffixIcon,
          prefixIcon: Icon(
            AppIcons.search,
            color: iconColor ?? context.colors.hint,
            size: iconSize,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: minHeight,
            minHeight: minHeight,
          ),
          filled: true,
          fillColor: context.colors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide:
                BorderSide(color: borderColor ?? context.colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide:
                BorderSide(color: borderColor ?? context.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
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
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;
  final InputDecoration? decoration;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.style,
    this.decoration,
    this.suffixIcon,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: obscureText ? null : minLines,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: style,
      autofillHints: autofillHints,
      decoration: decoration ??
          InputDecoration(
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
  final bool showCount;
  final Color? selectedBackgroundColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final double selectedBorderWidth;
  final bool countBadge;
  final Color? countBackgroundColor;
  final Color? selectedCountBackgroundColor;
  final Color? countTextColor;
  final Color? selectedCountTextColor;
  final double chipRadius;
  final double chipFontSize;
  final FontWeight chipFontWeight;

  const FilterChipsRow({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.showCount = true,
    this.selectedBackgroundColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.selectedBorderWidth = 1,
    this.countBadge = false,
    this.countBackgroundColor,
    this.selectedCountBackgroundColor,
    this.countTextColor,
    this.selectedCountTextColor,
    this.chipRadius = 20,
    this.chipFontSize = 12,
    this.chipFontWeight = FontWeight.w700,
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
              showCount: showCount,
              selectedBackgroundColor: selectedBackgroundColor,
              selectedTextColor: selectedTextColor,
              unselectedTextColor: unselectedTextColor,
              selectedBorderWidth: selectedBorderWidth,
              countBadge: countBadge,
              countBackgroundColor: countBackgroundColor,
              selectedCountBackgroundColor: selectedCountBackgroundColor,
              countTextColor: countTextColor,
              selectedCountTextColor: selectedCountTextColor,
              chipRadius: chipRadius,
              chipFontSize: chipFontSize,
              chipFontWeight: chipFontWeight,
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
  final bool showCount;
  final Color? selectedBackgroundColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final double selectedBorderWidth;
  final bool countBadge;
  final Color? countBackgroundColor;
  final Color? selectedCountBackgroundColor;
  final Color? countTextColor;
  final Color? selectedCountTextColor;
  final double chipRadius;
  final double chipFontSize;
  final FontWeight chipFontWeight;

  const _FilterChip({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.showCount,
    required this.selectedBackgroundColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    required this.selectedBorderWidth,
    required this.countBadge,
    required this.countBackgroundColor,
    required this.selectedCountBackgroundColor,
    required this.countTextColor,
    required this.selectedCountTextColor,
    required this.chipRadius,
    required this.chipFontSize,
    required this.chipFontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: selected
          ? selectedTextColor ?? context.colors.onHeader
          : unselectedTextColor ?? context.colors.textBody,
      fontSize: chipFontSize,
      fontWeight: chipFontWeight,
    );
    final Widget content;
    if (showCount && countBadge) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.label, maxLines: 1, style: labelStyle),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? selectedCountBackgroundColor ?? context.colors.brand
                  : countBackgroundColor ?? context.colors.borderSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${item.count}',
              maxLines: 1,
              style: TextStyle(
                color: selected
                    ? selectedCountTextColor ?? context.colors.onHeader
                    : countTextColor ?? context.colors.textBody,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    } else {
      content = Text(
        showCount ? '${item.label} (${item.count})' : item.label,
        maxLines: 1,
        style: labelStyle,
      );
    }

    return Material(
      color: selected
          ? selectedBackgroundColor ?? context.colors.brand
          : context.colors.surface,
      borderRadius: BorderRadius.circular(chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(chipRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(chipRadius),
            border: Border.all(
              color: selected ? context.colors.brand : context.colors.border,
              width: selected ? selectedBorderWidth : 1,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String message;
  final Widget? action;
  final bool card;
  final double? iconContainerSize;
  final double? iconSize;
  final Color? iconColor;
  final double? titleFontSize;
  final double? messageFontSize;

  const EmptyState({
    super.key,
    required this.icon,
    this.title,
    required this.message,
    this.action,
    this.card = false,
    this.iconContainerSize,
    this.iconSize,
    this.iconColor,
    this.titleFontSize,
    this.messageFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final containerSize = iconContainerSize ?? (card ? 48.0 : 52.0);
    return Container(
      width: card ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: card
          ? BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSoft),
            )
          : null,
      child: Column(
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: colors.brandTint,
              shape: card ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: card ? BorderRadius.circular(12) : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor ?? (card ? colors.brand : colors.hint),
              size: iconSize ?? 24,
            ),
          ),
          if (title != null) ...[
            SizedBox(height: card ? 8 : 12),
            Text(
              title!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: titleFontSize,
              ),
            ),
          ] else
            const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textBody,
              fontSize: messageFontSize ?? (card ? null : 13),
            ),
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
  final bool prominent;
  final bool offline;

  const ErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    this.prominent = false,
    this.offline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (prominent) {
      final iconColor =
          offline ? context.colors.textBody : context.colors.dangerText;
      final iconBackground = offline
          ? context.colors.filterCountBackground
          : context.colors.dangerBg;
      return AppCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
        shadow: true,
        borderColor: offline
            ? context.colors.borderSoft
            : context.colors.dangerBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  offline ? AppIcons.wifiOff : AppIcons.error,
                  color: iconColor,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              offline ? 'No internet connection' : "Couldn't load",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Try again',
              onPressed: onRetry,
              minHeight: 56,
              borderRadius: 18,
              shadow: true,
            ),
          ],
        ),
      );
    }
    return AppCard(
      borderColor: context.colors.dangerBorder,
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

class ConfirmDialogRow {
  final String label;
  final String currentValue;
  final String newValue;

  const ConfirmDialogRow({
    required this.label,
    required this.currentValue,
    required this.newValue,
  });
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final bool loading;
  final IconData? icon;
  final String? errorMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final List<ConfirmDialogRow>? rows;
  final String? note;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.danger = false,
    this.loading = false,
    this.icon,
    this.errorMessage,
    this.onCancel,
    this.onConfirm,
    this.rows,
    this.note,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool danger = false,
    IconData? icon,
    List<ConfirmDialogRow>? rows,
    String? note,
  }) {
    final hasSummary = rows != null || note != null;
    return showDialog<bool>(
      context: context,
      barrierColor:
          hasSummary ? context.colors.modalScrim.withValues(alpha: .55) : null,
      animationStyle: hasSummary || danger && icon != null
          ? _dangerAnimationStyle(context)
          : null,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: danger,
        icon: icon,
        rows: rows,
        note: note,
      ),
    );
  }

  static AnimationStyle _dangerAnimationStyle(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return AnimationStyle(
      duration: duration,
      reverseDuration: duration,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rows != null || note != null) {
      return _summaryDialog(context);
    }

    if (danger && icon != null) {
      return _dangerDialog(context);
    }

    return AlertDialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      icon: icon == null
          ? null
          : Icon(
              icon,
              color: danger ? context.colors.dangerText : context.colors.brand,
            ),
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
          onPressed: loading
              ? null
              : (onCancel ?? () => Navigator.pop(context, false)),
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: loading
              ? null
              : (onConfirm ?? () => Navigator.pop(context, true)),
          style: FilledButton.styleFrom(
            backgroundColor:
                danger ? context.colors.danger : context.colors.brand,
            foregroundColor: context.colors.onHeader,
            minimumSize: const Size(64, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
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

  Widget _summaryDialog(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            radius: 28,
            shadow: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (rows != null) ...[
                  const SizedBox(height: 14),
                  _summaryTable(context, rows!),
                ],
                if (note != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warningBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.warningBorder,
                      ),
                    ),
                    child: Text(
                      note!,
                      style: TextStyle(
                        color: colors.goldTintText,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SecondaryButton(
                        label: cancelLabel,
                        onPressed: loading
                            ? null
                            : (onCancel ?? () => Navigator.pop(context, false)),
                        foregroundColor: colors.brand,
                        minHeight: 52,
                        borderRadius: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 7,
                      child: PrimaryButton(
                        label: confirmLabel,
                        onPressed: loading
                            ? null
                            : (onConfirm ?? () => Navigator.pop(context, true)),
                        loading: loading,
                        minHeight: 52,
                        borderRadius: 18,
                        shadow: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryTable(BuildContext context, List<ConfirmDialogRow> rows) {
    final colors = context.colors;
    final labelStyle = TextStyle(
      color: colors.textBody,
      fontSize: 13,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final valueColumnWidth =
            ((constraints.maxWidth - 48) / 2).clamp(0.0, 96.0).toDouble();

        Widget valueCell(
          String value, {
          required Color color,
          required FontWeight weight,
        }) {
          return SizedBox(
            width: valueColumnWidth,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: weight,
              ),
            ),
          );
        }

        Widget headerCell(String label) => SizedBox(
              width: valueColumnWidth,
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: colors.textBody,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            );

        return Column(
          children: [
            Row(
              children: [
                const Expanded(child: SizedBox()),
                headerCell('CURRENT'),
                const SizedBox(width: 8),
                headerCell('NEW'),
              ],
            ),
            Divider(height: 10, thickness: 1, color: colors.borderSoft),
            for (var index = 0; index < rows.length; index++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[index].label,
                        style: labelStyle,
                      ),
                    ),
                    valueCell(
                      rows[index].currentValue,
                      color: colors.textBody,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(width: 8),
                    valueCell(
                      rows[index].newValue,
                      color: rows[index].currentValue == rows[index].newValue
                          ? colors.textPrimary
                          : colors.brand,
                      weight: FontWeight.w800,
                    ),
                  ],
                ),
              ),
              if (index < rows.length - 1)
                Divider(height: 1, thickness: 1, color: colors.borderSoft),
            ],
          ],
        );
      },
    );
  }

  Widget _dangerDialog(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: AppCard(
            padding: const EdgeInsets.all(24),
            radius: 28,
            shadow: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.dangerBg.withValues(alpha: .55),
                    border: Border.all(
                      color: colors.dangerBg.withValues(alpha: .8),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.dangerBg,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 28,
                      color: colors.dangerText,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: colors.textBody,
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.dangerText,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: cancelLabel,
                        onPressed: loading
                            ? null
                            : (onCancel ?? () => Navigator.pop(context, false)),
                        minHeight: 52,
                        borderRadius: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: colors.danger.withValues(alpha: .2),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: PrimaryButton(
                          label: confirmLabel,
                          loadingLabel: confirmLabel,
                          onPressed: loading
                              ? null
                              : (onConfirm ??
                                  () => Navigator.pop(context, true)),
                          loading: loading,
                          backgroundColor: colors.danger,
                          minHeight: 52,
                          borderRadius: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? header;
  final double maxHeightFactor;
  final double radius;
  final EdgeInsetsGeometry contentPadding;
  final bool showDragHandle;
  final Size dragHandleSize;
  final Color? dragHandleColor;
  final double dragHandleRadius;

  const AppBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.header,
    this.maxHeightFactor = .85,
    this.radius = 28,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
    this.showDragHandle = false,
    this.dragHandleSize = const Size(64, 6),
    this.dragHandleColor,
    this.dragHandleRadius = 99,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          border: Border.all(color: context.colors.borderSoft),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: contentPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDragHandle) ...[
                  Center(
                    child: Container(
                      width: dragHandleSize.width,
                      height: dragHandleSize.height,
                      decoration: BoxDecoration(
                        color: dragHandleColor ?? context.colors.border,
                        borderRadius: BorderRadius.circular(dragHandleRadius),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (header != null)
                  header!
                else
                  Text(
                    title,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
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
  final double avatarSize;
  final Color? avatarRingColor;
  final double avatarRingWidth;
  final double nameFontSize;
  final double subtitleFontSize;
  final bool roundActionButtons;
  final double actionButtonSize;
  final bool dayNightIcons;

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
    this.avatarSize = 40,
    this.avatarRingColor,
    this.avatarRingWidth = 0,
    this.nameFontSize = 15,
    this.subtitleFontSize = 11,
    this.roundActionButtons = false,
    this.actionButtonSize = 48,
    this.dayNightIcons = false,
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
    final avatar = CircleAvatar(
      radius: (avatarSize - (avatarRingWidth * 2)) / 2,
      backgroundColor: context.colors.avatarBackground,
      child: Text(
        initials,
        style: TextStyle(
          color: isDark ? context.colors.textPrimary : context.colors.onGold,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
    final avatarWidget = avatarRingWidth > 0
        ? Container(
            width: avatarSize,
            height: avatarSize,
            padding: EdgeInsets.all(avatarRingWidth),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: avatarRingColor ?? context.colors.border,
                width: avatarRingWidth,
              ),
            ),
            child: avatar,
          )
        : avatar;
    final themeToggle = roundActionButtons
        ? Container(
            width: actionButtonSize,
            height: actionButtonSize,
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.borderSoft),
            ),
            child: ThemeToggleButton(
              color: actionColor,
              buttonSize: actionButtonSize,
              dayNightIcons: dayNightIcons,
            ),
          )
        : ThemeToggleButton(
            color: actionColor,
            pill: true,
            pillBackground: softBackground ? context.colors.surface : null,
            outlinedPill: softBackground,
          );

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
                  avatarWidget,
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
                            fontSize: nameFontSize,
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
                            fontSize: subtitleFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  themeToggle,
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Notifications',
                    child: Container(
                      width: roundActionButtons ? actionButtonSize : 48,
                      height: roundActionButtons ? actionButtonSize : 48,
                      decoration: softBackground || roundActionButtons
                          ? BoxDecoration(
                              color: context.colors.surface,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: context.colors.borderSoft),
                            )
                          : null,
                      child: IconButton(
                        onPressed: onNotifications,
                        constraints: roundActionButtons
                            ? BoxConstraints.tightFor(
                                width: actionButtonSize,
                                height: actionButtonSize,
                              )
                            : null,
                        padding: roundActionButtons ? EdgeInsets.zero : null,
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
  final double radius;
  final double iconTileSize;
  final double amountFontSize;

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
    this.radius = 22,
    this.iconTileSize = 44,
    this.amountFontSize = 32,
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
      radius: radius,
      shadow: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconTileSize,
                height: iconTileSize,
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: StatusChip(
                    statusLabel,
                    color: statusColor,
                    bg: statusBackground,
                  ),
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
                  fontSize: amountFontSize,
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
  final double radius;
  final double iconTileSize;

  const BiometricStatusCard({
    super.key,
    required this.onTap,
    this.highlighted = false,
    this.radius = 22,
    this.iconTileSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              highlighted ? context.colors.warningBg : context.colors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: highlighted
                ? context.colors.warningBorder
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
              width: iconTileSize,
              height: iconTileSize,
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
                        fontSize: highlighted ? 16 : 15,
                        color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Required to confirm allowance payouts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: highlighted ? 13 : 12,
                      color: context.colors.textBody,
                    ),
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
  final double iconTileSize;
  final double iconTileRadius;
  final double iconSize;

  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tileColor,
    this.iconColor,
    this.description,
    this.badge,
    this.iconTileSize = 40,
    this.iconTileRadius = 12,
    this.iconSize = 24,
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
                  width: iconTileSize,
                  height: iconTileSize,
                  decoration: BoxDecoration(
                    color: tileColor ?? context.colors.brandTint,
                    borderRadius: BorderRadius.circular(iconTileRadius),
                  ),
                  child: Icon(icon,
                      color: iconColor ?? context.colors.brand, size: iconSize),
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
  final String? loadingLabel;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final double minHeight;
  final double borderRadius;
  final bool shadow;
  final double iconSize;
  final double iconSpacing;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.loadingLabel,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.minHeight = 56,
    this.borderRadius = 18,
    this.shadow = false,
    this.iconSize = 24,
    this.iconSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = foregroundColor ?? context.colors.onHeader;
    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ??
          (isDark ? context.colors.header : context.colors.brand),
      foregroundColor: foreground,
      disabledBackgroundColor: disabledBackgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      minimumSize: Size.fromHeight(minHeight),
      elevation: shadow ? 5 : 0,
      shadowColor: shadow
          ? (backgroundColor ?? context.colors.brand).withValues(alpha: .24)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
    final spinner = SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: foreground,
      ),
    );
    final Widget child;
    if (loading && loadingLabel != null) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          spinner,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              loadingLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    } else if (loading) {
      child = spinner;
    } else {
      child = Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (icon == null) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
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
      constraints: BoxConstraints(minHeight: minHeight),
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
                    Icon(icon, color: foreground, size: iconSize),
                    SizedBox(width: iconSpacing),
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
  final Color? iconColor;
  final Color? foregroundColor;
  final Color? dangerTextColor;
  final Color? borderColor;
  final String? loadingLabel;
  final bool loading;
  final bool danger;
  final double minHeight;
  final double borderRadius;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconColor,
    this.foregroundColor,
    this.dangerTextColor,
    this.borderColor,
    this.loadingLabel,
    this.loading = false,
    this.danger = false,
    this.minHeight = 52,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? dangerTextColor ?? context.colors.danger
        : foregroundColor ?? context.colors.textPrimary;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(
              color: borderColor ??
                  (danger ? context.colors.danger : context.colors.border),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: loading
              ? loadingLabel == null
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
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            loadingLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: iconColor ?? color),
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

class DashboardStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tileColor;
  final Color iconColor;
  final String? detail;
  final VoidCallback onTap;
  final double radius;
  final double minHeight;
  final double iconTileSize;
  final double iconTileRadius;
  final double iconSize;
  final bool showChevron;

  const DashboardStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tileColor,
    required this.iconColor,
    required this.onTap,
    this.detail,
    this.radius = 16,
    this.minHeight = 96,
    this.iconTileSize = 40,
    this.iconTileRadius = 12,
    this.iconSize = 24,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: context.colors.borderSoft),
          ),
          child: Row(
            children: [
              Container(
                width: iconTileSize,
                height: iconTileSize,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(iconTileRadius),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: iconSize),
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
              if (showChevron) ...[
                const SizedBox(width: 4),
                Icon(
                  AppIcons.chevronRight,
                  size: 18,
                  color: context.colors.hint,
                ),
              ],
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
  final bool financialPresentation;
  final bool showCurrencyCode;
  final double iconSize;
  final String statusSeparator;

  const HomeActivityRow({
    super.key,
    required this.transaction,
    required this.friendlyDate,
    this.statusLabel,
    this.inCard = false,
    this.financialPresentation = false,
    this.showCurrencyCode = true,
    this.iconSize = 40,
    this.statusSeparator = '•',
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
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color:
                  isCredit ? context.colors.successBg : context.colors.dangerBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isCredit
                  ? financialPresentation
                      ? AppIcons.arrowDown
                      : AppIcons.plus
                  : financialPresentation
                      ? AppIcons.arrowUpRight
                      : AppIcons.minus,
              color: isCredit
                  ? financialPresentation
                      ? context.colors.successText
                      : context.colors.success
                  : financialPresentation
                      ? context.colors.dangerText
                      : context.colors.danger,
              size: iconSize * .46,
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
                      : '$friendlyDate $statusSeparator $statusLabel',
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
                '${isCredit ? '+' : '-'}'
                '${showCurrencyCode ? 'PHP ' : ''}'
                '${fmtPhp(financialPresentation ? transaction.amount.abs() : transaction.amount)}',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: isCredit
                      ? financialPresentation
                          ? context.colors.successText
                          : context.colors.success
                      : financialPresentation
                          ? context.colors.dangerText
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
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double letterSpacing;
  const StatusChip(
    this.label, {
    super.key,
    this.color = AppTheme.successGreen,
    this.bg,
    this.borderRadius = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.fontSize = 10,
    this.letterSpacing = .6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
          color: bg ?? context.colors.successBg,
          borderRadius: BorderRadius.circular(borderRadius)),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: letterSpacing,
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
    animationStyle: ConfirmDialog._dangerAnimationStyle(context),
    barrierDismissible: false,
    builder: (dialogContext) {
      var isBusy = false;
      String? errorMessage;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: !isBusy,
            child: ConfirmDialog(
              title: 'Log out?',
              message:
                  'Are you sure you want to log out of Scholar Wallet? You can log back in anytime.',
              confirmLabel: 'Log out',
              cancelLabel: 'Cancel',
              danger: true,
              icon: AppIcons.logout,
              loading: isBusy,
              errorMessage: errorMessage,
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () async {
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
  final double? buttonSize;
  final bool dayNightIcons;
  const ThemeToggleButton({
    super.key,
    this.color,
    this.pill = false,
    this.pillBackground,
    this.outlinedPill = false,
    this.buttonSize,
    this.dayNightIcons = false,
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
        constraints: buttonSize == null
            ? null
            : BoxConstraints.tightFor(
                width: buttonSize,
                height: buttonSize,
              ),
        padding: buttonSize == null ? null : EdgeInsets.zero,
        tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        icon: Icon(
          dayNightIcons
              ? (isDark ? AppIcons.moon : AppIcons.sun)
              : (isDark ? AppIcons.sun : AppIcons.moon),
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
Future<void> showPayoutQrSheet(BuildContext context, AllowanceClaim claim) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
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
              'Take a screenshot of this QR, then open Scan QR from Home or My Payouts and choose it from your gallery. It can only be used once.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    ),
  );
}
