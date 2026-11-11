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
  final Color textPrimary; // headings & body text
  final Color textBody; // secondary paragraph text
  final Color textLabel; // form labels
  final Color hint; // input hints
  final Color brand; // blue used for text / icons / links
  final Color heroGradientEnd;
  final Color balanceHeroStart;
  final Color balanceHeroEnd;
  final Color balanceHeroText;
  final Color successText;
  final Color warningText;
  final Color dangerText;
  final Color brandTint; // tinted backgrounds for brand icon tiles
  final Color header; // home header bar
  final Color onHeader; // content displayed on the header
  final Color scanGradientStart; // scan screen background
  final Color onGold; // content displayed on gold surfaces
  final Color avatarBackground; // cream avatar background
  final Color goldTint; // pale gold panel
  final Color accentGold; // gold icons and accents
  final Color successBg;
  final Color dangerBg;
  final Color warningBg;
  final Color success;
  final Color danger;
  final Color warning;
  final Color cardShadow;

  const AppColors({
    required this.canvas,
    required this.background,
    required this.surface,
    required this.border,
    required this.borderSoft,
    required this.textPrimary,
    required this.textBody,
    required this.textLabel,
    required this.hint,
    required this.brand,
    required this.heroGradientEnd,
    required this.balanceHeroStart,
    required this.balanceHeroEnd,
    required this.balanceHeroText,
    required this.successText,
    required this.warningText,
    required this.dangerText,
    required this.brandTint,
    required this.header,
    required this.onHeader,
    required this.scanGradientStart,
    required this.onGold,
    required this.avatarBackground,
    required this.goldTint,
    required this.accentGold,
    required this.successBg,
    required this.dangerBg,
    required this.warningBg,
    required this.success,
    required this.danger,
    required this.warning,
    required this.cardShadow,
  });

  static const light = AppColors(
    canvas: Color(0xFFFFFFFF),
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE3E8EF),
    borderSoft: Color(0xFFEEF1F6),
    textPrimary: Color(0xFF1A2530),
    textBody: Color(0xFF4A5568),
    textLabel: Color(0xFF3A4556),
    hint: Color(0xFFA3ABB8),
    brand: Color(0xFF1E5AA8),
    heroGradientEnd: Color(0xFF174B89),
    balanceHeroStart: Color(0xFFEFC45F),
    balanceHeroEnd: Color(0xFFDDA33B),
    balanceHeroText: Color(0xFF342507),
    successText: Color(0xFF08734D),
    warningText: Color(0xFF765000),
    dangerText: Color(0xFFA52A2A),
    brandTint: Color(0xFFEAF2FE),
    header: Color(0xFF1E5AA8),
    onHeader: Color(0xFFFFFFFF),
    scanGradientStart: Color(0xFF0B1D3A),
    onGold: Color(0xFF342507),
    avatarBackground: Color(0xFFFFF4D8),
    goldTint: Color(0xFFFCF7EA),
    accentGold: Color(0xFFD9A441),
    successBg: Color(0xFFE5F8F0),
    dangerBg: Color(0xFFFDECEC),
    warningBg: Color(0xFFFFF6E3),
    success: Color(0xFF1DB981),
    danger: Color(0xFFE15A5A),
    warning: Color(0xFFF0A020),
    cardShadow: Color(0x140E2946),
  );

  static const dark = AppColors(
    canvas: Color(0xFF0F141B),
    background: Color(0xFF0F141B),
    surface: Color(0xFF1A212B),
    border: Color(0xFF2E3846),
    borderSoft: Color(0xFF252E3B),
    textPrimary: Color(0xFFE8EDF4),
    textBody: Color(0xFFB4BDCB),
    textLabel: Color(0xFFC9D1DC),
    hint: Color(0xFF6B7587),
    brand: Color(0xFF6FA3E8),
    heroGradientEnd: Color(0xFF103C70),
    balanceHeroStart: Color(0xFFD9AD4F),
    balanceHeroEnd: Color(0xFFBF8928),
    balanceHeroText: Color(0xFF241A08),
    successText: Color(0xFF54D6A4),
    warningText: Color(0xFFF4B942),
    dangerText: Color(0xFFF07575),
    brandTint: Color(0xFF1D3554),
    header: Color(0xFF14467F),
    onHeader: Color(0xFFFFFFFF),
    scanGradientStart: Color(0xFF08162D),
    onGold: Color(0xFF342507),
    avatarBackground: Color(0xFF453719),
    goldTint: Color(0xFF2A2415),
    accentGold: Color(0xFFE6B85D),
    successBg: Color(0xFF10352A),
    dangerBg: Color(0xFF3A1D1F),
    warningBg: Color(0xFF3A2D12),
    success: Color(0xFF54D6A4),
    danger: Color(0xFFF07575),
    warning: Color(0xFFF4B942),
    cardShadow: Color(0x33000000),
  );

  @override
  AppColors copyWith({
    Color? canvas,
    Color? background,
    Color? surface,
    Color? border,
    Color? borderSoft,
    Color? textPrimary,
    Color? textBody,
    Color? textLabel,
    Color? hint,
    Color? brand,
    Color? heroGradientEnd,
    Color? balanceHeroStart,
    Color? balanceHeroEnd,
    Color? balanceHeroText,
    Color? successText,
    Color? warningText,
    Color? dangerText,
    Color? brandTint,
    Color? header,
    Color? onHeader,
    Color? scanGradientStart,
    Color? onGold,
    Color? avatarBackground,
    Color? goldTint,
    Color? accentGold,
    Color? successBg,
    Color? dangerBg,
    Color? warningBg,
    Color? success,
    Color? danger,
    Color? warning,
    Color? cardShadow,
  }) =>
      AppColors(
        canvas: canvas ?? this.canvas,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        borderSoft: borderSoft ?? this.borderSoft,
        textPrimary: textPrimary ?? this.textPrimary,
        textBody: textBody ?? this.textBody,
        textLabel: textLabel ?? this.textLabel,
        hint: hint ?? this.hint,
        brand: brand ?? this.brand,
        heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
        balanceHeroStart: balanceHeroStart ?? this.balanceHeroStart,
        balanceHeroEnd: balanceHeroEnd ?? this.balanceHeroEnd,
        balanceHeroText: balanceHeroText ?? this.balanceHeroText,
        successText: successText ?? this.successText,
        warningText: warningText ?? this.warningText,
        dangerText: dangerText ?? this.dangerText,
        brandTint: brandTint ?? this.brandTint,
        header: header ?? this.header,
        onHeader: onHeader ?? this.onHeader,
        scanGradientStart: scanGradientStart ?? this.scanGradientStart,
        onGold: onGold ?? this.onGold,
        avatarBackground: avatarBackground ?? this.avatarBackground,
        goldTint: goldTint ?? this.goldTint,
        accentGold: accentGold ?? this.accentGold,
        successBg: successBg ?? this.successBg,
        dangerBg: dangerBg ?? this.dangerBg,
        warningBg: warningBg ?? this.warningBg,
        success: success ?? this.success,
        danger: danger ?? this.danger,
        warning: warning ?? this.warning,
        cardShadow: cardShadow ?? this.cardShadow,
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
      textPrimary: l(textPrimary, other.textPrimary),
      textBody: l(textBody, other.textBody),
      textLabel: l(textLabel, other.textLabel),
      hint: l(hint, other.hint),
      brand: l(brand, other.brand),
      heroGradientEnd: l(heroGradientEnd, other.heroGradientEnd),
      balanceHeroStart: l(balanceHeroStart, other.balanceHeroStart),
      balanceHeroEnd: l(balanceHeroEnd, other.balanceHeroEnd),
      balanceHeroText: l(balanceHeroText, other.balanceHeroText),
      successText: l(successText, other.successText),
      warningText: l(warningText, other.warningText),
      dangerText: l(dangerText, other.dangerText),
      brandTint: l(brandTint, other.brandTint),
      header: l(header, other.header),
      onHeader: l(onHeader, other.onHeader),
      scanGradientStart: l(scanGradientStart, other.scanGradientStart),
      onGold: l(onGold, other.onGold),
      avatarBackground: l(avatarBackground, other.avatarBackground),
      goldTint: l(goldTint, other.goldTint),
      accentGold: l(accentGold, other.accentGold),
      successBg: l(successBg, other.successBg),
      dangerBg: l(dangerBg, other.dangerBg),
      warningBg: l(warningBg, other.warningBg),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      warning: l(warning, other.warning),
      cardShadow: l(cardShadow, other.cardShadow),
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
  static const Color textMuted = Color(0xFF8A94A6);
  static const Color successGreen = Color(0xFF1DB981);
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
        iconTheme: IconThemeData(color: c.textPrimary),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.brand, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
  const SectionLabel(this.text, {super.key, this.trailing, this.labelColor});

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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: labelColor ?? context.colors.hint,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
