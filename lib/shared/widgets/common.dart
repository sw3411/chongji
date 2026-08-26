import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/theme.dart';
import '../../domain/models/enums.dart';

/// Tab 页统一骨架：环境光渐变头部 + 大标题 + 动作区。
/// 五个底部 Tab 共用同一头部节奏（与首页问候头一致）。
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? AppTheme.darkBg : AppTheme.lightBg,
      floatingActionButton: floatingActionButton,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? AppTheme.headerGradientDark
                : AppTheme.headerGradientLight,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.25],
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.largeTitle(
                            dark ? Colors.white : AppTheme.ink,
                            size: 19),
                      ),
                    ),
                    ...?actions,
                  ],
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// 表单底部常驻保存栏：悬浮瓷片 + 全宽按钮（长表单保存不随滚动消失）。
class FormSaveBar extends StatelessWidget {
  const FormSaveBar({
    super.key,
    this.label = '保存',
    this.loading = false,
    this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: dark
              ? Border.all(color: Colors.white.withValues(alpha: 0.06))
              : null,
        ),
        child: FilledButton(
          onPressed: onPressed,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      ),
    );
  }
}

/// 空状态占位。
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.outline),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTheme.subhead(cs.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// 类型徽标：低饱和色 + 图标 + 文本，不只依赖颜色。
class TypeChip extends StatelessWidget {
  const TypeChip(
    this.text, {
    super.key,
    this.color = AppTheme.okGreen,
    this.icon,
    this.compact = false,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 健康记录类型的徽标配色（低饱和家族，杜绝彩虹感）。
Color recordTypeColor(HealthRecordType type) => switch (type) {
      HealthRecordType.weight => AppTheme.green,
      HealthRecordType.bcs => AppTheme.green,
      HealthRecordType.vaccine => AppTheme.sage,
      HealthRecordType.dewormIn => AppTheme.mauve,
      HealthRecordType.dewormOut => AppTheme.mauve,
      HealthRecordType.vetVisit => AppTheme.rose,
      HealthRecordType.medication => AppTheme.ochre,
      HealthRecordType.surgery => AppTheme.rose,
      HealthRecordType.symptom => AppTheme.ochre,
      HealthRecordType.other => AppTheme.inkSecondary,
    };

/// 时刻类型的徽标配色。
Color momentTypeColor(MomentType type) => switch (type) {
      MomentType.birthday => AppTheme.rose,
      MomentType.outing => AppTheme.sage,
      MomentType.grooming => AppTheme.steel,
      MomentType.adoption => AppTheme.ochre,
      MomentType.anniversary => AppTheme.mauve,
      MomentType.custom => AppTheme.taupe,
    };

/// 消费分类徽标配色。
Color expenseCategoryColor(ExpenseCategory c) => switch (c) {
      ExpenseCategory.food => AppTheme.sage,
      ExpenseCategory.treats => AppTheme.mauve,
      ExpenseCategory.medical => AppTheme.rose,
      ExpenseCategory.grooming => AppTheme.steel,
      ExpenseCategory.toys => AppTheme.ochre,
      ExpenseCategory.supplies => AppTheme.taupe,
      ExpenseCategory.insurance => AppTheme.olive,
      ExpenseCategory.other => AppTheme.inkSecondary,
    };

/// 各类记录的展示图标（日历/列表共用）。
IconData recordTypeIcon(HealthRecordType type) => switch (type) {
      HealthRecordType.weight => Icons.scale,
      HealthRecordType.bcs => Icons.accessibility_new,
      HealthRecordType.vaccine => Icons.vaccines,
      HealthRecordType.dewormIn => Icons.medication_liquid,
      HealthRecordType.dewormOut => Icons.shower,
      HealthRecordType.vetVisit => Icons.local_hospital,
      HealthRecordType.medication => Icons.medication,
      HealthRecordType.surgery => Icons.healing,
      HealthRecordType.symptom => Icons.sick,
      HealthRecordType.other => Icons.notes,
    };

IconData momentTypeIcon(MomentType type) => switch (type) {
      MomentType.birthday => Icons.cake,
      MomentType.outing => Icons.park,
      MomentType.grooming => Icons.content_cut,
      MomentType.adoption => Icons.home,
      MomentType.anniversary => Icons.favorite,
      MomentType.custom => Icons.pets,
    };

IconData expenseCategoryIcon(ExpenseCategory c) => switch (c) {
      ExpenseCategory.food => Icons.rice_bowl,
      ExpenseCategory.treats => Icons.cookie,
      ExpenseCategory.medical => Icons.local_hospital,
      ExpenseCategory.grooming => Icons.content_cut,
      ExpenseCategory.toys => Icons.toys,
      ExpenseCategory.supplies => Icons.shopping_bag,
      ExpenseCategory.insurance => Icons.shield,
      ExpenseCategory.other => Icons.more_horiz,
    };

/// 强视觉选择芯片（表单选项专用）：
/// - 选中：陶土淡染 + 强调色文字
/// - 未选中：白瓷片底 + 墨色文字（与全局卡片同一语言，无描边）
class SelectChip extends StatelessWidget {
  const SelectChip(
    this.label, {
    super.key,
    required this.selected,
    this.onSelected,
    this.color,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? Theme.of(context).colorScheme.primary;
    final fg = selected ? base : (dark ? Colors.white70 : AppTheme.ink);
    return GestureDetector(
      onTap: onSelected == null ? null : () => onSelected!(true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? base.withValues(alpha: 0.13)
              : (dark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
            ],
            if (selected) ...[
              Icon(Icons.check_rounded, size: 15, color: fg),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 日期药丸：淡染底 + 等宽数字。
class DatePill extends StatelessWidget {
  const DatePill(
    this.text, {
    super.key,
    this.color,
    this.compact = false,
  });

  final String text;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? (dark ? Colors.white54 : AppTheme.inkSecondary);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: base,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 表单分区卡：白卡 + 左上角彩色小标题，让每个选项模块之间有明确视觉分隔。
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3.5,
                  height: 14,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Text(label,
                    style: AppTheme.label(cs.onSurfaceVariant).copyWith(
                      fontSize: 12.5,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 到期天数徽标：淡染胶囊 + 等宽数字，颜色只表达紧急程度。
class DueBadge extends StatelessWidget {
  const DueBadge({super.key, required this.daysLeft, this.tone});

  /// 负数 = 已过期。
  final int daysLeft;
  final Color? tone;

  Color get _color => daysLeft < 0
      ? AppTheme.warnRed
      : daysLeft == 0
          ? AppTheme.warnRed
          : tone ??
              (daysLeft <= 7 ? AppTheme.warnAmber : AppTheme.okGreen);

  @override
  Widget build(BuildContext context) {
    final c = _color;
    final String label;
    if (daysLeft < 0) {
      label = '已过${-daysLeft}天';
    } else if (daysLeft == 0) {
      label = '今天';
    } else {
      label = '$daysLeft天';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 通用信息行：label(13 灰) + value(14)。
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon});

  final String label;
  final String? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.trim().isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: cs.outline),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 76,
            child: Text(label, style: AppTheme.footnote(cs.onSurfaceVariant)),
          ),
          Expanded(child: Text(v, style: AppTheme.subhead(cs.onSurface))),
        ],
      ),
    );
  }
}

/// 数字突出展示的小卡片（白瓷片，大数字默认墨色）。
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.subValue,
    this.subValueColor,
    this.onTap,
    this.accent = false,
  });

  final String label;
  final String value;
  final String? subValue;

  /// 副文案颜色（涨红跌绿等语义色）。
  final Color? subValueColor;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppTheme.label(cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: AppTheme.bigNumber(
                    accent ? cs.primary : cs.onSurface,
                    size: 21,
                  ),
                ),
              ),
              if (subValue != null) ...[
                const SizedBox(height: 4),
                Text(
                  subValue!,
                  style: AppTheme.caption(
                          subValueColor ?? cs.onSurfaceVariant)
                      .copyWith(fontWeight: subValueColor == null ? null : FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 场景卡背景装饰折线：无轴无网格无交互的白色 sparkline，
/// 铺在渐变大卡底部当纹理（首页/健康页共用）。
class SparklineBg extends StatelessWidget {
  const SparklineBg({super.key, required this.spots, this.opacity = 0.14});

  final List<FlSpot> spots;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (spots.length < 2) return const SizedBox.shrink();
    final minX = spots.first.x;
    var maxX = spots.last.x;
    if (maxX <= minX) maxX = minX + 1; // 同日两条记录时避免零宽。
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY).clamp(0.1, 10.0) * 0.35;
    return Opacity(
      opacity: opacity,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(),
            rightTitles: AxisTitles(),
            bottomTitles: AxisTitles(),
            leftTitles: AxisTitles(),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.white,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 区块标题。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTheme.label(
                  Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 骨架屏加载态：灰块脉冲（替代转圈，更产品化）。
final loadingView = _SkeletonView();

class _SkeletonView extends StatefulWidget {
  @override
  State<_SkeletonView> createState() => _SkeletonViewState();
}

class _SkeletonViewState extends State<_SkeletonView>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final block = dark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFEDEAE3);
    Widget bar(double height, {double? width}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: block,
            borderRadius: BorderRadius.circular(12),
          ),
        );
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.45)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              bar(72),
              const SizedBox(height: 12),
              bar(20, width: 180),
              const SizedBox(height: 12),
              bar(120),
              const SizedBox(height: 12),
              bar(120),
            ],
          ),
        ),
      ),
    );
  }
}

/// 展示 4 秒自动消失的 SnackBar。
void showAutoToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              onPressed: onAction ?? () {},
            ),
    ));
  Future.delayed(const Duration(seconds: 4), () {
    messenger.hideCurrentSnackBar();
  });
}

/// AI 生成内容的统一 Markdown 排版：
/// - **加粗** → 强调色关键数字（尺寸克制，与正文协调不割裂）
/// - 正文 13.5/1.7，标题 15
MarkdownStyleSheet digestMarkdownStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: const TextStyle(fontSize: 13.5, height: 1.7),
    strong: TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
      color: cs.primary,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    listBullet: const TextStyle(fontSize: 13.5, height: 1.7),
    h2: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    h3: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
  );
}

/// WhatsApp 式列表行：头像 + 加粗主标题 + 灰色副标题 + 右侧元信息。
class WhatsAppRow extends StatelessWidget {
  const WhatsAppRow({
    super.key,
    required this.avatar,
    required this.title,
    this.subtitle,
    this.trailing,
    this.meta,
    this.onTap,
    this.onLongPress,
  });

  final Widget avatar;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? meta;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.cardTitle(cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTheme.subhead(cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (meta != null) ...[
              const SizedBox(width: 8),
              meta!,
            ],
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
