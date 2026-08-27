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
/// 语义色门面：页面统一经 `AppPalette.of(context)` 取色，
/// 杜绝 `dark ? Colors.white : AppTheme.ink` 式散写三元——
/// 主题调整只动这一个文件。
class ChongjiPalette {
  const ChongjiPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.buttonBg,
    required this.divider,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// 装饰性强调（图标/大数字点缀/选中态）。
  final Color accent;

  /// 文字级强调（链接/胶囊字/正文重点），保证 4.5:1。
  final Color accentText;

  /// 强调色淡染底（胶囊/选中芯片背景，约 12% 透明度等效实值）。
  final Color accentSoft;

  /// 实底按钮与 FAB 底色（配白字过对比）。
  final Color buttonBg;
  final Color divider;

  static const light = ChongjiPalette(
    canvas: AppTheme.lightBg,
    surface: AppTheme.lightSurface,
    surfaceAlt: Color(0xFFEFF2F6),
    textPrimary: AppTheme.ink,
    textSecondary: AppTheme.inkSecondary,
    textTertiary: AppTheme.inkTertiary,
    accent: AppTheme.green,
    accentText: AppTheme.lAccentText,
    accentSoft: Color(0x1F17724B),
    buttonBg: AppTheme.lAccentText,
    divider: AppTheme.lightDivider,
  );

  static const dark = ChongjiPalette(
    canvas: AppTheme.darkBg,
    surface: AppTheme.darkSurface,
    surfaceAlt: AppTheme.darkSurfaceAlt,
    textPrimary: AppTheme.dInk,
    textSecondary: AppTheme.dInkSecondary,
    textTertiary: AppTheme.dInkTertiary,
    accent: AppTheme.greenDark,
    accentText: AppTheme.dAccentText,
    accentSoft: Color(0x4057CF97),
    buttonBg: AppTheme.greenButtonDark,
    divider: AppTheme.darkDivider,
  );
}

extension AppPalette on BuildContext {
  ChongjiPalette get palette =>
      Theme.of(this).brightness == Brightness.dark
          ? ChongjiPalette.dark
          : ChongjiPalette.light;
}

/// 动效 token：全局共用一根曲线两个时长（克制原则）。
class Motion {
  Motion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Curve curve = Curves.easeOutCubic;
}

class AppTheme {
  AppTheme._();

  // ---------- v5 色板 ----------

  /// 主色：鲜薄荷绿（清爽活力系唯一强调色）。
  /// 装饰/图标/选中态用 [green]（白底 3.2:1 合规非文字位）；
  /// 文字级强调用 [lAccentText]/[dAccentText]（≥4.5:1 实测达标）。
  static const Color green = Color(0xFF21A36B);

  static const Color greenLight = Color(0xFF57C08F);

  /// 深色模式下的强调色（略提亮保证对比）。
  /// 实底按钮/中央钮用 [greenButtonDark]（白字 4.24:1，原陶土上仅 2.98）。
  static const Color greenDark = Color(0xFF3FBF82);
  static const Color greenButtonDark = Color(0xFF1C7E56);

  static const Color greenBubble = Color(0xFF274A3B);

  static const Color bubbleOut = Color(0xFFE6F5EE);

  /// 低饱和分类色板（图表/徽标共用，同一明度家族，避免彩虹感）。
  static const Color sage = Color(0xFF6FBF94);
  static const Color ochre = Color(0xFFE0A84F);
  static const Color mauve = Color(0xFFAF96D9);
  static const Color steel = Color(0xFF64A8DC);
  static const Color rose = Color(0xFFE28181);
  static const Color olive = Color(0xFF8FB56A);
  static const Color taupe = Color(0xFF9AA7B4);

  // 兼容旧命名。
  static const Color mint = sage;
  static const Color honey = ochre;
  static const Color sakura = rose;

  /// 中央钮 / 品牌元素渐变。
  static const List<Color> primaryGradient = [Color(0xFF2EB878), Color(0xFF178455)];

  /// 场景卡渐变（首页/健康页数据大卡）。
  static const List<Color> sceneGradientLight = [Color(0xFF35B47E), Color(0xFF178455)];
  static const List<Color> sceneGradientDark = [Color(0xFF1E4435), Color(0xFF153328)];

  /// 页面顶部环境光渐变（极淡，过渡进画布）。
  static const List<Color> headerGradientLight = [Color(0xFFFFFFFF), Color(0xFFF7F8FA)];
  static const List<Color> headerGradientDark = [Color(0xFF464040), Color(0xFF3B3535)];

  /// 毛玻璃表面（悬浮底导用）。
  static Color glassSurface(bool dark) =>
      dark ? const Color(0xCC1D1A17) : const Color(0xCCFFFFFF);
  static Color glassBorder(bool dark) =>
      dark ? const Color(0x1FFFFFFF) : const Color(0x14000000);

  /// 文字：墨色三级（冷调）。对比度实测（WCAG 4.5:1，白底）
  /// ：ink 14.7 / inkSecondary 5.8 / inkTertiary 4.89 —— 全部达标。
  static const Color ink = Color(0xFF20242A);
  static const Color inkSecondary = Color(0xFF5D6772);
  static const Color inkTertiary = Color(0xFF68727D);

  /// 浅色：暖纸画布 + 白瓷片 + 片内发丝线。
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F5F2);
  static const Color lightDivider = Color(0xFFECE8E1);

  /// 深色：#3B3535 画布 + 三档微亮表面。文字对比度实测（/#3B3535 底）
  /// ：dInk 10.7 / dInkSecondary 5.6 / dInkTertiary≈4.8 / dAccentText
  /// (D29273) 4.64 —— 正文级全部 ≥4.5。
  static const Color darkBg = Color(0xFF3B3535);
  static const Color darkSurface = Color(0xFF453E3E);
  static const Color darkSurfaceAlt = Color(0xFF4C4545);
  static const Color darkDivider = Color(0xFF4A4343);
  static const Color dInk = Color(0xFFF5F1ED);
  static const Color dInkSecondary = Color(0xFFB8AFA6);
  static const Color dInkTertiary = Color(0xFFADA49B);

  /// 文字级强调（深/浅）；装饰性 accent 仍用 green/greenDark。
  static const Color dAccentText = Color(0xFF57CF97);
  static const Color lAccentText = Color(0xFF17724B);

  /// 状态色（仅用于语义：到期/涨跌/成功）。
  static const Color warnRed = Color(0xFFE25B55);
  static const Color warnAmber = Color(0xFFDE9A3A);
  static const Color okGreen = Color(0xFF4CA477);
  static const Color infoBlue = Color(0xFF7FA0B5);

  /// 卡片圆角：全局唯一圆角体系（场景卡 24，其余 20）。
  /// 组件内微缩档：cardRadius-4（芯片/小卡）、cardRadius-8（点击区）。
  static const double cardRadius = 22;

  /// 输入框圆角（与 cardRadius 同族但独立一档）。
  static const double fieldRadius = 16;

  /// 极轻投影：仅悬浮元素（FAB/底导）使用，卡片一律不用。
  static List<BoxShadow> softShadow([Color base = const Color(0x0A3D2E26)]) => [
        BoxShadow(color: base, blurRadius: 16, offset: const Offset(0, 4)),
      ];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: lAccentText,
      primary: lAccentText,
      onPrimary: Colors.white,
      secondary: greenLight,
      onSecondary: Colors.white,
      tertiary: sage,
      brightness: Brightness.light,
      surface: lightSurface,
      onSurface: ink,
      surfaceContainerHighest: lightDivider,
      onSurfaceVariant: inkSecondary,
      primaryFixedDim: lAccentText,
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
      primary: greenButtonDark,
      onPrimary: Colors.white,
      secondary: greenLight,
      onSecondary: Colors.white,
      tertiary: sage,
      brightness: Brightness.dark,
      surface: darkSurface,
      onSurface: dInk,
      surfaceContainerHighest: darkSurfaceAlt,
      onSurfaceVariant: dInkSecondary,
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
            ? const Color(0xFFF1F4F7)
            : darkSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
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
  static TextStyle largeTitle(Color color, {double size = 22}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.12,
        color: color,
      );

  /// 区块大标题：17/w700。
  static TextStyle title(Color color) => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.2,
        color: color,
      );

  /// 卡片/列表主标题：15/w600。
  static TextStyle cardTitle(Color color) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
        color: color,
      );

  /// 正文：15/w400（可达性达标线）。
  static TextStyle body(Color color) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: color,
      );

  /// 次要行：13/w400 灰。
  static TextStyle subhead(Color color) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  /// 脚注：12/w400。
  static TextStyle footnote(Color color) => TextStyle(
        fontSize: 12,
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

  /// 大数字：等宽 + w600（避免"w800 粗黑"的老气，轻盈才高级）。
  /// 大数字：Manrope 数字字体 + w700/等宽——数据主角的专属声音。
  static TextStyle bigNumber(Color color, {double size = 20}) => TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// 展示级大数字（体重/金额主位）：Manrope 细字重档用 w500。
  static TextStyle displayNumber(Color color, {double size = 56}) =>
      TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: -2,
        height: 1.05,
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
