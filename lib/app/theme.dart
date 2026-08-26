import 'package:flutter/material.dart';

/// 主题：纸感画布 + 白瓷片（2026-08 v5 全局统一）。
///
/// 设计语言：整页是一张连续的暖纸画布（canvas），内容放在白瓷"片"
/// （sheet）上——无描边、无投影、统一 20 圆角，靠底色差而非边框分层。
/// 色彩收敛：墨色文字 + 单一陶土强调色；彩色只保留给状态语义（到期/
/// 涨跌）与图表分类，且分类色统一为同明度的低饱和家族，杜绝彩虹感。
/// 页面主视觉（首页/健康页数据大卡）用整张渐变"场景卡"承载大数字。
///
/// 注意：为兼容存量页面，主色常量仍沿用旧命名（green* 等），
/// 语义以注释为准。
class AppTheme {
  AppTheme._();

  // ---------- v5 色板 ----------

  /// 主色：陶土（唯一强调色，克制使用）。
  static const Color green = Color(0xFFC0765A);

  static const Color greenLight = Color(0xFFD09A80);

  /// 深色模式下的强调色（略提亮保证对比）。
  static const Color greenDark = Color(0xFFC9856A);

  static const Color greenBubble = Color(0xFF5E4536);

  static const Color bubbleOut = Color(0xFFF3E9E1);

  /// 低饱和分类色板（图表/徽标共用，同一明度家族，避免彩虹感）。
  static const Color sage = Color(0xFF93A88C);
  static const Color ochre = Color(0xFFC4A265);
  static const Color mauve = Color(0xFFA78FAD);
  static const Color steel = Color(0xFF7FA0B5);
  static const Color rose = Color(0xFFC79191);
  static const Color olive = Color(0xFF9BA182);
  static const Color taupe = Color(0xFFB3A48F);

  // 兼容旧命名。
  static const Color mint = sage;
  static const Color honey = ochre;
  static const Color sakura = rose;

  /// 中央钮 / 品牌元素渐变。
  static const List<Color> primaryGradient = [Color(0xFFC98061), Color(0xFFB4644C)];

  /// 场景卡渐变（首页/健康页数据大卡）。
  static const List<Color> sceneGradientLight = [Color(0xFFE2A57D), Color(0xFFBB6852)];
  static const List<Color> sceneGradientDark = [Color(0xFF4A3828), Color(0xFF2B2118)];

  /// 页面顶部环境光渐变（极淡，过渡进画布）。
  static const List<Color> headerGradientLight = [Color(0xFFF1EAE1), Color(0xFFF3F0EA)];
  static const List<Color> headerGradientDark = [Color(0xFF201C17), Color(0xFF131110)];

  /// 毛玻璃表面（悬浮底导用）。
  static Color glassSurface(bool dark) =>
      dark ? const Color(0xCC1D1A17) : const Color(0xCCFFFFFF);
  static Color glassBorder(bool dark) =>
      dark ? const Color(0x1FFFFFFF) : const Color(0x14000000);

  /// 文字：墨色三级（暖灰调）。
  static const Color ink = Color(0xFF292420);
  static const Color inkSecondary = Color(0xFF9C948B);
  static const Color inkTertiary = Color(0xFFC2BAB1);

  /// 浅色：暖纸画布 + 白瓷片 + 片内发丝线。
  static const Color lightBg = Color(0xFFF3F0EA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFECE8E1);

  /// 深色：暖夜画布 + 微亮瓷片。
  static const Color darkBg = Color(0xFF131110);
  static const Color darkSurface = Color(0xFF1D1A17);
  static const Color darkSurfaceAlt = Color(0xFF262219);
  static const Color darkDivider = Color(0xFF2B2721);

  /// 状态色（仅用于语义：到期/涨跌/成功）。
  static const Color warnRed = Color(0xFFE25B55);
  static const Color warnAmber = Color(0xFFDE9A3A);
  static const Color okGreen = Color(0xFF4CA477);
  static const Color infoBlue = Color(0xFF7FA0B5);

  /// 卡片圆角：全局唯一圆角体系（场景卡 24，其余 20）。
  static const double cardRadius = 20;

  /// 极轻投影：仅悬浮元素（FAB/底导）使用，卡片一律不用。
  static List<BoxShadow> softShadow([Color base = const Color(0x0A3D2E26)]) => [
        BoxShadow(color: base, blurRadius: 16, offset: const Offset(0, 4)),
      ];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      primary: green,
      onPrimary: Colors.white,
      secondary: greenLight,
      onSecondary: Colors.white,
      tertiary: sage,
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
      tertiary: sage,
      brightness: Brightness.dark,
      surface: darkSurface,
      onSurface: const Color(0xFFF0EAE3),
      surfaceContainerHighest: darkSurfaceAlt,
      onSurfaceVariant: const Color(0xFFB5ACA2),
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
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: cs.onSurface,
        ),
        iconTheme: IconThemeData(color: cs.onSurfaceVariant, size: 22),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        // 白瓷片：零投影零描边，靠画布底色差分层。
        elevation: 0,
        shadowColor: Colors.transparent,
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          minimumSize: const Size(40, 40),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outlineVariant, width: 1),
          shape: const StadiumBorder(),
          minimumSize: const Size(40, 40),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.brightness == Brightness.light
            ? const Color(0xFFF5F2EC)
            : darkSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.42),
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

  /// 大标题：页面主视觉与汇总大数字。
  static TextStyle largeTitle(Color color, {double size = 20}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.12,
        color: color,
      );

  /// 区块大标题：16/w700。
  static TextStyle title(Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.2,
        color: color,
      );

  /// 卡片/列表主标题：14/w600。
  static TextStyle cardTitle(Color color) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
        color: color,
      );

  /// 正文：13/w400。
  static TextStyle body(Color color) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  /// 次要行：12/w400 灰。
  static TextStyle subhead(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color,
      );

  /// 脚注：11/w400。
  static TextStyle footnote(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  /// 时间戳/单位：11/w400 三级色。
  static TextStyle caption(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  /// 更小的时间戳：10.5/w400。
  static TextStyle captionSm(Color color) => TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color,
      );

  /// 大数字：等宽 + w600（避免"w800 粗黑"的老气，轻盈才高级）。
  static TextStyle bigNumber(Color color, {double size = 18}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.1,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// 区块小标题：10.5/w600 +0.6 字距。
  static TextStyle label(Color color) => TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: color,
      );

  /// 深色横幅上文字的投影常量。
  static const bannerShadow = <Shadow>[
    Shadow(blurRadius: 6, color: Colors.black54),
  ];
}
