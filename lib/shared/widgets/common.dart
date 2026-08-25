import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/theme.dart';
import '../../domain/models/enums.dart';

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
        borderRadius: BorderRadius.circular(6),
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

/// 健康记录类型的徽标配色。
Color recordTypeColor(HealthRecordType type) => switch (type) {
      HealthRecordType.weight => AppTheme.infoBlue,
      HealthRecordType.bcs => AppTheme.infoBlue,
      HealthRecordType.vaccine => AppTheme.okGreen,
      HealthRecordType.dewormIn => const Color(0xFF8B5CF6),
      HealthRecordType.dewormOut => const Color(0xFF8B5CF6),
      HealthRecordType.vetVisit => AppTheme.warnRed,
      HealthRecordType.medication => AppTheme.warnAmber,
      HealthRecordType.surgery => AppTheme.warnRed,
      HealthRecordType.symptom => AppTheme.warnAmber,
      HealthRecordType.other => AppTheme.inkSecondary,
    };

/// 时刻类型的徽标配色。
Color momentTypeColor(MomentType type) => switch (type) {
      MomentType.birthday => const Color(0xFFEC4899),
      MomentType.outing => AppTheme.okGreen,
      MomentType.grooming => AppTheme.infoBlue,
      MomentType.adoption => const Color(0xFFF97316),
      MomentType.anniversary => const Color(0xFFF43F5E),
      MomentType.custom => AppTheme.inkSecondary,
    };

/// 消费分类徽标配色。
Color expenseCategoryColor(ExpenseCategory c) => switch (c) {
      ExpenseCategory.food => AppTheme.okGreen,
      ExpenseCategory.treats => const Color(0xFFD946EF),
      ExpenseCategory.medical => AppTheme.warnRed,
      ExpenseCategory.grooming => AppTheme.infoBlue,
      ExpenseCategory.toys => const Color(0xFFF97316),
      ExpenseCategory.supplies => AppTheme.inkSecondary,
      ExpenseCategory.insurance => const Color(0xFF14B8A6),
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

/// 强视觉选择芯片（表单选项专用，参考 wuji 的 PillChip）：
/// - 选中：实色底 + 白色加粗字，一眼锁定
/// - 未选中：浅色底(8%)+ 描边 + 彩色字，与选中形成强对比
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
    final cs = Theme.of(context).colorScheme;
    final base = color ?? cs.primary;
    final fg = selected ? Colors.white : base;
    return GestureDetector(
      onTap: onSelected == null ? null : () => onSelected!(true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? base : base.withValues(alpha: 0.08),
          border: Border.all(
            color: selected ? base : base.withValues(alpha: 0.35),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(20),
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
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 日期药丸：底色 + 加粗等宽数字，用于行尾时间、到期日等。
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
    final cs = Theme.of(context).colorScheme;
    final base = color ?? cs.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
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

/// 到期天数强调块：大号加粗数字 + 天，底色随紧急程度变化；
/// 传入 [tone]（类型主色）时未过期部分用类型色，过期仍为红色警示。
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
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

/// 数字突出展示的小卡片。
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
                    size: 22,
                  ),
                ),
              ),
              if (subValue != null) ...[
                const SizedBox(height: 4),
                Text(
                  subValue!,
                  style: AppTheme.caption(
                          subValueColor ?? cs.onSurfaceVariant)
                      .copyWith(fontWeight: subValueColor == null ? null : FontWeight.w700),
                ),
              ],
            ],
          ),
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

const loadingView = Center(child: CircularProgressIndicator());

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
/// - **加粗** → 放大加粗的绿色关键数字
/// - 正文 13.5/1.75，标题 15.5
MarkdownStyleSheet digestMarkdownStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: const TextStyle(fontSize: 13.5, height: 1.75),
    strong: TextStyle(
      fontSize: 16.5,
      fontWeight: FontWeight.w800,
      color: cs.primary,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    listBullet: const TextStyle(fontSize: 13.5, height: 1.75),
    h2: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
    h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
