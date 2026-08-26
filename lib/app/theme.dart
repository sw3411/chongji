import 'package:flutter/material.dart';

/// 主题：暖萌宠物风（2026-08 视觉重构）。
///
/// 设计语言：奶油米底 + 蜜桃橙主色 + 糖果点缀（薄荷/奶油黄/樱花粉），
/// 超大圆角、软投影、胶囊按钮——参考主流宠物 App 的温馨可爱气质。
/// 字体层级沿用 Apple 规格（大小 × 粗细严格区分），骨架不变、气质换血。
///
/// 注意：为兼容存量页面，主色常量仍沿用旧命名（green* 等），
/// 值已全部映射为暖萌色板，语义以注释为准。
class AppTheme {
  AppTheme._();

  // ---------- 暖萌色板 ----------

  /// 主色：蜜桃橙（操作、选中、强调）。
  static const Color green = Color(0xFFFF8A4C);

  /// 主色亮版（悬浮按钮、发送、今天标记）。
  static const Color greenLight = Color(0xFFFFA168);

  /// 深色模式主色（更沉的焦糖橙）。
  static const Color greenDark = Color(0xFFF0703A);

  /// 深色模式自己发出的气泡（焦糖棕）。
  static const Color greenBubble = Color(0xFF8A5230);

  /// 浅色模式自己发出的气泡（奶油杏）。
  static const Color bubbleOut = Color(0xFFFFE9D2);

  /// 糖果点缀：薄荷 / 奶油黄 / 樱花粉。
  static const Color mint = Color(0xFF3BB273);
  static const Color honey = Color(0xFFFFC64B);
  static const Color sakura = Color(0xFFFF9BB3);

  /// 主色渐变（中央钮 / 品牌元素）。
  static const List<Color> primaryGradient = [Color(0xFFFF8A4C), Color(0xFFFF7E79)];

  /// 文字：暖棕黑 / 暖灰棕 / 更浅。
  static const Color ink = Color(0xFF3D2E26);
  static const Color inkSecondary = Color(0xFF9A8578);
  static const Color inkTertiary = Color(0xFFBCA99B);

  /// 浅色：奶油米底、纯白卡、暖分割线。
  static const Color lightBg = Color(0xFFFFF7EF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFF3E7DC);

  /// 深色：暖棕夜色。
  static const Color darkBg = Color(0xFF211A15);
  static const Color darkSurface = Color(0xFF2D251F);
  static const Color darkSurfaceAlt = Color(0xFF3A2F27);
  static const Color darkDivider = Color(0xFF45392F);

  /// 状态色（保持高饱和，微暖化）。
  static const Color warnRed = Color(0xFFF0544F);
  static const Color warnAmber = Color(0xFFF5A83C);
  static const Color okGreen = Color(0xFF3BB273);
  static const Color infoBlue = Color(0xFF5B9BD5);

  /// 卡片圆角：暖萌风加大。
  static const double cardRadius = 22;

  /// 软投影（暖色调、低透明度、大扩散）。
  static List<BoxShadow> softShadow([Color base = const Color(0x143D2E26)]) => [
        BoxShadow(color: base, blurRadius: 16, offset: const Offset(0, 6)),
      ];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      primary: green,
      onPrimary: Colors.white,
      secondary: greenLight,
      onSecondary: Colors.white,
      tertiary: mint,
      brightness: Brightness.light,
      surface: lightSurface,
      onSurface: ink,
      surfaceContainerHighest: lightDivider,
      onSurfaceVariant: inkSecondary,
      outlineVariant: lightDivider,
    );
    return _common(ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBg,
    ));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: greenDark,
      primary: greenDark,
      onPrimary: Colors.white,
      secondary: greenLight,
      onSecondary: Colors.white,
      tertiary: mint,
      brightness: Brightness.dark,
      surface: darkSurface,
      onSurface: const Color(0xFFF3E9E1),
      surfaceContainerHighest: darkSurfaceAlt,
      onSurfaceVariant: const Color(0xFFBCA99B),
      outlineVariant: darkDivider,
    );
    return _common(ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBg,
    ));
  }

  static ThemeData _common(ThemeData base) {
    final cs = base.colorScheme;
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: base.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: cs.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        // 暖萌质感：软投影 + 大圆角。
        elevation: 1.2,
        shadowColor: const Color(0x143D2E26),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary, width: 1.4),
          shape: const StadiumBorder(),
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.brightness == Brightness.light
            ? const Color(0xFFFFFCF7)
            : darkSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.primary, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.onSurface,
        contentTextStyle: TextStyle(color: cs.surface),
        shape: const StadiumBorder(),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.transparent,
        shape: const StadiumBorder(),
        side: BorderSide(color: cs.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      // 正文字高 1.45~1.55：全局可读性基调（层级规格保持不变）。
      textTheme: base.textTheme
          .apply(
            bodyColor: cs.onSurface,
            displayColor: cs.onSurface,
          )
          .copyWith(
            bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.55),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
            bodySmall:
                base.textTheme.bodySmall?.copyWith(height: 1.45, fontSize: 12.5),
            titleMedium: base.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
            titleSmall:
                base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
    );
  }

  // ---------- 字号阶梯（页面直接引用，规格不变） ----------

  /// 大标题：34/w700，页面主视觉与汇总大数字。
  static TextStyle largeTitle(Color color, {double size = 34}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.12,
        color: color,
      );

  /// 区块大标题：22/w700。
  static TextStyle title(Color color) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        height: 1.2,
        color: color,
      );

  /// 卡片/列表主标题：17/w700。
  static TextStyle cardTitle(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  /// 正文：16/w400。
  static TextStyle body(Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  /// 次要行：14/w400 灰。
  static TextStyle subhead(Color color) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color,
      );

  /// 脚注：13/w400。
  static TextStyle footnote(Color color) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  /// 时间戳/单位：12/w400 三级色。
  static TextStyle caption(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  /// 更小的时间戳：11/w400。
  static TextStyle captionSm(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color,
      );

  /// 大数字：等宽数字 + 加粗（体重、金额、倒计时）。
  static TextStyle bigNumber(Color color, {double size = 24}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.1,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// 区块小标题：11.5/w700 +0.6 字距。
  static TextStyle label(Color color) => TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color,
      );

  /// 深色横幅上文字的投影常量。
  static const bannerShadow = <Shadow>[
    Shadow(blurRadius: 6, color: Colors.black54),
  ];
}
