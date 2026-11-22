import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors that differ between the light and dark themes.
///
/// Read them with `context.colors.surface`, `context.colors.textPrimary`, etc.
/// Brand/status colors that look fine on both backgrounds (gold, green, red,
/// amber, muted grey) stay as constants on [AppTheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color canvas; // full-screen background (login)
  final Color background; // scaffold background
  final Color surface; // cards, inputs, app bars
  final Color border; // input / outline borders
  final Color borderSoft; // subtle card borders
  final Color skeletonBase;
  final Color skeletonHighlight;
  final Color textPrimary; // headings & body text
  final Color textBody; // secondary paragraph text
  final Color textLabel; // form labels
  final Color hint; // input hints
  final Color hintContrast; // accessible hint and muted icon color
  final Color brand; // blue used for text / icons / links
  final Color heroGradientEnd;
  final Color receiptHeroEnd;
  final Color balanceHeroStart;
  final Color balanceHeroEnd;
  final Color balanceHeroText;
  final Color successText;
  final Color warningText;
  final Color dangerText;
  final Color brandTint; // tinted backgrounds for brand icon tiles
  final Color brandTintText;
  final Color filterCountBackground;
  final Color infoRequiredBg;
  final Color infoRequiredText;
  final Color dangerOutline;
  final Color dangerFeedbackText;
  final Color header; // home header bar
  final Color authHeroStart;
  final Color authHeroEnd;
  final Color onHeader; // content displayed on the header
  final Color scanGradientStart; // scan screen background
  final Color onGold; // content displayed on gold surfaces
  final Color avatarBackground; // cream avatar background
  final Color avatarTint;
  final Color avatarText;
  final Color goldTint; // pale gold panel
  final Color goldTintBorder;
  final Color goldTintText;
  final Color accentGold; // gold icons and accents
  final Color successBg;
  final Color dangerBg;
  final Color dangerBorder;
  final Color warningBg;
  final Color warningBorder;
  final Color success;
  final Color successAccent;
  final Color danger;
  final Color warning;
  final Color cardShadow;
  final Color modalScrim;
  final Color sheetHandle;
  final Color qrFrame;

  const AppColors({
    required this.canvas,
    required this.background,
    required this.surface,
    required this.border,
    required this.borderSoft,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.textPrimary,
    required this.textBody,
    required this.textLabel,
    required this.hint,
    required this.hintContrast,
    required this.brand,
    required this.heroGradientEnd,
    required this.receiptHeroEnd,
    required this.balanceHeroStart,
    required this.balanceHeroEnd,
    required this.balanceHeroText,
    required this.successText,
    required this.warningText,
    required this.dangerText,
    required this.brandTint,
    required this.brandTintText,
    required this.filterCountBackground,
    required this.infoRequiredBg,
    required this.infoRequiredText,
    required this.dangerOutline,
    required this.dangerFeedbackText,
    required this.header,
    required this.authHeroStart,
    required this.authHeroEnd,
    required this.onHeader,
    required this.scanGradientStart,
    required this.onGold,
    required this.avatarBackground,
    required this.avatarTint,
    required this.avatarText,
    required this.goldTint,
    required this.goldTintBorder,
    required this.goldTintText,
    required this.accentGold,
    required this.successBg,
    required this.dangerBg,
    required this.dangerBorder,
    required this.warningBg,
    required this.warningBorder,
    required this.success,
    required this.successAccent,
    required this.danger,
    required this.warning,
    required this.cardShadow,
    required this.modalScrim,
    required this.sheetHandle,
    required this.qrFrame,
  });

  static const light = AppColors(
    canvas: Color(0xFFF5F7FA),
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE3E8EF),
    borderSoft: Color(0xFFEEF1F6),
    skeletonBase: Color(0xFFE9EDF3),
    skeletonHighlight: Color(0xFFF5F7FA),
    textPrimary: Color(0xFF1A2530),
    textBody: Color(0xFF4A5568),
    textLabel: Color(0xFF3A4556),
    hint: Color(0xFF6B7686),
    hintContrast: Color(0xFF6B7686),
    brand: Color(0xFF1E5AA8),
    heroGradientEnd: Color(0xFF174B89),
    receiptHeroEnd: Color(0xFF123F86),
    balanceHeroStart: Color(0xFFEFC45F),
    balanceHeroEnd: Color(0xFFDDA33B),
    balanceHeroText: Color(0xFF342507),
    successText: Color(0xFF08734D),
    warningText: Color(0xFF765000),
    dangerText: Color(0xFFA52A2A),
    brandTint: Color(0xFFEAF2FE),
    brandTintText: Color(0xFF123F86),
    filterCountBackground: Color(0xFFF0F2F6),
    infoRequiredBg: Color(0xFFFDEFD2),
    infoRequiredText: Color(0xFF9A5B00),
    dangerOutline: Color(0xFFF0B8B8),
    dangerFeedbackText: Color(0xFFA52A2A),
    header: Color(0xFF1E5AA8),
    authHeroStart: Color(0xFF2A6FC9),
    authHeroEnd: Color(0xFF164786),
    onHeader: Color(0xFFFFFFFF),
    scanGradientStart: Color(0xFF0B1D3A),
    onGold: Color(0xFF342507),
    avatarBackground: Color(0xFFFFF4D8),
    avatarTint: Color(0xFFFFF1CC),
    avatarText: Color(0xFF4A3300),
    goldTint: Color(0xFFFCF7EA),
    goldTintBorder: Color(0xFFF3D9A0),
    goldTintText: Color(0xFF4A3200),
    accentGold: Color(0xFFD9A441),
    successBg: Color(0xFFE5F8F0),
    dangerBg: Color(0xFFFDECEC),
    dangerBorder: Color(0xFFF0B8B8),
    warningBg: Color(0xFFFFF6E3),
    warningBorder: Color(0xFFF3D9A0),
    success: Color(0xFF1FB886),
    successAccent: Color(0xFF1FB886),
    danger: Color(0xFFE15A5A),
    warning: Color(0xFFF0A020),
    cardShadow: Color(0x140E2946),
    modalScrim: Color(0xFF0F1B2D),
    sheetHandle: Color(0xFFD5DCE8),
    qrFrame: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    canvas: Color(0xFF0F141B),
    background: Color(0xFF0F141B),
    surface: Color(0xFF1A212B),
    border: Color(0xFF2E3846),
    borderSoft: Color(0xFF252E3B),
    skeletonBase: Color(0xFF2B3442),
    skeletonHighlight: Color(0xFF394455),
    textPrimary: Color(0xFFE8EDF4),
    textBody: Color(0xFFB4BDCB),
    textLabel: Color(0xFFC9D1DC),
    hint: Color(0xFF6B7587),
    hintContrast: Color(0xFFA6B0BF),
    brand: Color(0xFF1E5AA8),
    heroGradientEnd: Color(0xFF103C70),
    receiptHeroEnd: Color(0xFF0D2F5E),
    balanceHeroStart: Color(0xFFD9AD4F),
    balanceHeroEnd: Color(0xFFBF8928),
    balanceHeroText: Color(0xFF241A08),
    successText: Color(0xFF54D6A4),
    warningText: Color(0xFFF4B942),
    dangerText: Color(0xFFF07575),
    brandTint: Color(0xFF1D3554),
    brandTintText: Color(0xFFA8C6ED),
    filterCountBackground: Color(0xFF303744),
    infoRequiredBg: Color(0xFF423113),
    infoRequiredText: Color(0xFFF3C969),
    dangerOutline: Color(0xFF6A3A3E),
    dangerFeedbackText: Color(0xFFF2B1B1),
    header: Color(0xFF14467F),
    authHeroStart: Color(0xFF1E579B),
    authHeroEnd: Color(0xFF103763),
    onHeader: Color(0xFFFFFFFF),
    scanGradientStart: Color(0xFF08162D),
    onGold: Color(0xFF342507),
    avatarBackground: Color(0xFF453719),
    avatarTint: Color(0xFF3A301D),
    avatarText: Color(0xFFF1DDA8),
    goldTint: Color(0xFF2A2415),
    goldTintBorder: Color(0xFF5C4A28),
    goldTintText: Color(0xFFF3E4BD),
    accentGold: Color(0xFFE6B85D),
    successBg: Color(0xFF10352A),
    dangerBg: Color(0xFF3A1D1F),
    dangerBorder: Color(0xFF6A3A3E),
    warningBg: Color(0xFF3A2D12),
    warningBorder: Color(0xFF5C4A28),
    success: Color(0xFF1FB886),
    successAccent: Color(0xFF1FB886),
    danger: Color(0xFFF07575),
    warning: Color(0xFFF4B942),
    cardShadow: Color(0x33000000),
    modalScrim: Color(0xFF0F1B2D),
    sheetHandle: Color(0xFF3A4658),
    qrFrame: Color(0xFFFFFFFF),
  );

  @override
  AppColors copyWith({
    Color? canvas,
    Color? background,
    Color? surface,
    Color? border,
    Color? borderSoft,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? textPrimary,
    Color? textBody,
    Color? textLabel,
    Color? hint,
    Color? hintContrast,
    Color? brand,
    Color? heroGradientEnd,
    Color? receiptHeroEnd,
    Color? balanceHeroStart,
    Color? balanceHeroEnd,
    Color? balanceHeroText,
    Color? successText,
    Color? warningText,
    Color? dangerText,
    Color? brandTint,
    Color? brandTintText,
    Color? filterCountBackground,
    Color? infoRequiredBg,
    Color? infoRequiredText,
    Color? dangerOutline,
    Color? dangerFeedbackText,
    Color? header,
    Color? authHeroStart,
    Color? authHeroEnd,
    Color? onHeader,
    Color? scanGradientStart,
    Color? onGold,
    Color? avatarBackground,
    Color? avatarTint,
    Color? avatarText,
    Color? goldTint,
    Color? goldTintBorder,
    Color? goldTintText,
    Color? accentGold,
    Color? successBg,
    Color? dangerBg,
    Color? dangerBorder,
    Color? warningBg,
    Color? warningBorder,
    Color? success,
    Color? successAccent,
    Color? danger,
    Color? warning,
    Color? cardShadow,
    Color? modalScrim,
    Color? sheetHandle,
    Color? qrFrame,
  }) =>
      AppColors(
        canvas: canvas ?? this.canvas,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        borderSoft: borderSoft ?? this.borderSoft,
        skeletonBase: skeletonBase ?? this.skeletonBase,
        skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
        textPrimary: textPrimary ?? this.textPrimary,
        textBody: textBody ?? this.textBody,
        textLabel: textLabel ?? this.textLabel,
        hint: hint ?? this.hint,
        hintContrast: hintContrast ?? this.hintContrast,
        brand: brand ?? this.brand,
        heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
        receiptHeroEnd: receiptHeroEnd ?? this.receiptHeroEnd,
        balanceHeroStart: balanceHeroStart ?? this.balanceHeroStart,
        balanceHeroEnd: balanceHeroEnd ?? this.balanceHeroEnd,
        balanceHeroText: balanceHeroText ?? this.balanceHeroText,
        successText: successText ?? this.successText,
        warningText: warningText ?? this.warningText,
        dangerText: dangerText ?? this.dangerText,
        brandTint: brandTint ?? this.brandTint,
        brandTintText: brandTintText ?? this.brandTintText,
        filterCountBackground:
            filterCountBackground ?? this.filterCountBackground,
        infoRequiredBg: infoRequiredBg ?? this.infoRequiredBg,
        infoRequiredText: infoRequiredText ?? this.infoRequiredText,
        dangerOutline: dangerOutline ?? this.dangerOutline,
        dangerFeedbackText: dangerFeedbackText ?? this.dangerFeedbackText,
        header: header ?? this.header,
        authHeroStart: authHeroStart ?? this.authHeroStart,
        authHeroEnd: authHeroEnd ?? this.authHeroEnd,
        onHeader: onHeader ?? this.onHeader,
        scanGradientStart: scanGradientStart ?? this.scanGradientStart,
        onGold: onGold ?? this.onGold,
        avatarBackground: avatarBackground ?? this.avatarBackground,
        avatarTint: avatarTint ?? this.avatarTint,
        avatarText: avatarText ?? this.avatarText,
        goldTint: goldTint ?? this.goldTint,
        goldTintBorder: goldTintBorder ?? this.goldTintBorder,
        goldTintText: goldTintText ?? this.goldTintText,
        accentGold: accentGold ?? this.accentGold,
        successBg: successBg ?? this.successBg,
        dangerBg: dangerBg ?? this.dangerBg,
        dangerBorder: dangerBorder ?? this.dangerBorder,
        warningBg: warningBg ?? this.warningBg,
        warningBorder: warningBorder ?? this.warningBorder,
        success: success ?? this.success,
        successAccent: successAccent ?? this.successAccent,
        danger: danger ?? this.danger,
        warning: warning ?? this.warning,
        cardShadow: cardShadow ?? this.cardShadow,
        modalScrim: modalScrim ?? this.modalScrim,
        sheetHandle: sheetHandle ?? this.sheetHandle,
        qrFrame: qrFrame ?? this.qrFrame,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      canvas: l(canvas, other.canvas),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      border: l(border, other.border),
      borderSoft: l(borderSoft, other.borderSoft),
      skeletonBase: l(skeletonBase, other.skeletonBase),
      skeletonHighlight: l(skeletonHighlight, other.skeletonHighlight),
      textPrimary: l(textPrimary, other.textPrimary),
      textBody: l(textBody, other.textBody),
      textLabel: l(textLabel, other.textLabel),
      hint: l(hint, other.hint),
      hintContrast: l(hintContrast, other.hintContrast),
      brand: l(brand, other.brand),
      heroGradientEnd: l(heroGradientEnd, other.heroGradientEnd),
      receiptHeroEnd: l(receiptHeroEnd, other.receiptHeroEnd),
      balanceHeroStart: l(balanceHeroStart, other.balanceHeroStart),
      balanceHeroEnd: l(balanceHeroEnd, other.balanceHeroEnd),
      balanceHeroText: l(balanceHeroText, other.balanceHeroText),
      successText: l(successText, other.successText),
      warningText: l(warningText, other.warningText),
      dangerText: l(dangerText, other.dangerText),
      brandTint: l(brandTint, other.brandTint),
      brandTintText: l(brandTintText, other.brandTintText),
      filterCountBackground:
          l(filterCountBackground, other.filterCountBackground),
      infoRequiredBg: l(infoRequiredBg, other.infoRequiredBg),
      infoRequiredText: l(infoRequiredText, other.infoRequiredText),
      dangerOutline: l(dangerOutline, other.dangerOutline),
      dangerFeedbackText: l(dangerFeedbackText, other.dangerFeedbackText),
      header: l(header, other.header),
      authHeroStart: l(authHeroStart, other.authHeroStart),
      authHeroEnd: l(authHeroEnd, other.authHeroEnd),
      onHeader: l(onHeader, other.onHeader),
      scanGradientStart: l(scanGradientStart, other.scanGradientStart),
      onGold: l(onGold, other.onGold),
      avatarBackground: l(avatarBackground, other.avatarBackground),
      avatarTint: l(avatarTint, other.avatarTint),
      avatarText: l(avatarText, other.avatarText),
      goldTint: l(goldTint, other.goldTint),
      goldTintBorder: l(goldTintBorder, other.goldTintBorder),
      goldTintText: l(goldTintText, other.goldTintText),
      accentGold: l(accentGold, other.accentGold),
      successBg: l(successBg, other.successBg),
      dangerBg: l(dangerBg, other.dangerBg),
      dangerBorder: l(dangerBorder, other.dangerBorder),
      warningBg: l(warningBg, other.warningBg),
      warningBorder: l(warningBorder, other.warningBorder),
      success: l(success, other.success),
      successAccent: l(successAccent, other.successAccent),
      danger: l(danger, other.danger),
      warning: l(warning, other.warning),
      cardShadow: l(cardShadow, other.cardShadow),
      modalScrim: l(modalScrim, other.modalScrim),
      sheetHandle: l(sheetHandle, other.sheetHandle),
      qrFrame: l(qrFrame, other.qrFrame),
    );
  }
}

extension AppColorsContext on BuildContext {
  /// Theme-aware colors: `context.colors.surface`.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Central design tokens matching the Figma mockups.
class AppTheme {
  // Brand colors (identical in light & dark)
  static const Color primaryBlue = Color(0xFF1E5AA8);
  static const Color primaryBlueDark = Color(0xFF14467F);
  static const Color accentGold = Color(0xFFD9A441);
  static const Color accentGoldLight = Color(0xFFEFD9A7);
  static const Color textMuted = Color(0xFF6B7686);
  static const Color successGreen = Color(0xFF1FB886);
  static const Color dangerRed = Color(0xFFE15A5A);
  static const Color warningAmber = Color(0xFFF0A020);

  // Light-theme values kept for backwards compatibility. For anything that
  // must adapt to dark mode use `context.colors` instead.
  static const Color background = Color(0xFFF5F7FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A2530);
  static const Color successGreenBg = Color(0xFFE5F8F0);
  static const Color dangerRedBg = Color(0xFFFDECEC);
  static const Color warningAmberBg = Color(0xFFFFF6E3);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// Kept so existing references to `AppTheme.theme` still work.
  static ThemeData get theme => light;

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: brightness,
      primary: c.brand,
      secondary: accentGold,
      surface: c.surface,
    );

    // IMPORTANT: pass the brightness-matching base text theme, otherwise
    // GoogleFonts falls back to the light theme's dark text colors.
    final baseText =
        ThemeData(brightness: brightness, useMaterial3: true).textTheme;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      textTheme: GoogleFonts.interTextTheme(baseText),
      extensions: [c],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 56,
        iconTheme: IconThemeData(color: c.textPrimary),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: c.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: GoogleFonts.inter(color: c.hint, fontSize: 14),
        constraints: const BoxConstraints(minHeight: 50),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.dangerBorder),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.dangerBorder, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Section label like "QUICK ACCESS", "RECENT ACTIVITY".
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final Color? labelColor;
  final double fontSize;
  final double letterSpacing;
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.labelColor,
    this.fontSize = 12,
    this.letterSpacing = 1.1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: letterSpacing,
              color: labelColor ?? context.colors.hint,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
