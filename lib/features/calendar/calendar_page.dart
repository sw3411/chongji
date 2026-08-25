import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/utils/money.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/moment.dart';
import '../../domain/models/pet.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/sync_button.dart';

/// 日历页：按月展示当月所有记录（健康/时刻/消费），
/// 日期格内用类型图标标记，点选某天在下方看当日详情。
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    if (pets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('日历')),
        body: EmptyView(
          icon: Icons.calendar_month_outlined,
          title: '先添加一只宠物吧',
          action: FilledButton(
            onPressed: () => context.push('/pet/new'),
            child: const Text('添加宠物'),
          ),
        ),
      );
    }
    final pet = ref.watch(currentPetProvider) ?? pets.first;
    final records = ref.watch(currentPetRecordsProvider);
    final moments =
        ref.watch(momentsProvider(pet.id)).valueOrNull ?? const <Moment>[];
    final allExpenses =
        ref.watch(expensesProvider).valueOrNull ?? const <Expense>[];
    final expenses = allExpenses
        .where((e) => e.petId == null || e.petId == pet.id)
        .toList();

    final cs = Theme.of(context).colorScheme;

    // 汇总当月每天的事件条目。
    final entriesByDay = <DateTime, List<_CalEntry>>{};
    void addEntry(DateTime date, _CalEntry entry) {
      final key = DateTime(date.year, date.month, date.day);
      entriesByDay.putIfAbsent(key, () => []).add(entry);
    }

    for (final r in records) {
      addEntry(r.date, _CalEntry(
        icon: recordTypeIcon(r.type),
        color: recordTypeColor(r.type),
        title: r.type == HealthRecordType.weight
            ? '体重 ${r.value} kg'
            : r.type == HealthRecordType.bcs
                ? '体型 ${r.value?.toInt()}/9'
                : r.type.label,
        subtitle: [
          if (r.textValue != null && r.textValue!.isNotEmpty) r.textValue!,
          if (r.diagnosis != null && r.diagnosis!.isNotEmpty) r.diagnosis!,
          if (r.notes != null && r.notes!.isNotEmpty) r.notes!,
        ].join(' · '),
        route: '/health/record/${r.id}/edit',
      ));
    }
    for (final m in moments) {
      addEntry(m.date, _CalEntry(
        icon: momentTypeIcon(m.type),
        color: momentTypeColor(m.type),
        title: m.title,
        subtitle: [
          m.type.label,
          if (m.location != null && m.location!.isNotEmpty) m.location!,
        ].join(' · '),
        route: '/moment/${m.id}/edit',
      ));
    }
    for (final e in expenses) {
      addEntry(e.date, _CalEntry(
        icon: expenseCategoryIcon(e.category),
        color: expenseCategoryColor(e.category),
        title: e.title,
        subtitle:
            '${e.category.label}${e.petId == null ? " · 全体" : ""} · ${Money.format(e.amount)}',
        route: '/expense/${e.id}/edit',
      ));
    }

    // 月份网格参数（周一起始）。
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;
    final totalCells = leading + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final today = DateTime.now();
    final isThisMonth =
        _month.year == today.year && _month.month == today.month;
    // 默认选中今天（仅当查看当月）。
    DateTime? selected = _selected;
    if (isThisMonth &&
        (selected == null ||
            selected.year != _month.year ||
            selected.month != _month.month)) {
      selected = DateTime(today.year, today.month, today.day);
    }
    final dayEntries = selected == null
        ? const <_CalEntry>[]
        : (entriesByDay[selected] ?? const <_CalEntry>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text('${pet.name} · 日历'),
        actions: [const SyncButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 月份切换。
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1);
                  _selected = null;
                }),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_month.year}年${_month.month}月',
                    style: AppTheme.title(cs.onSurface),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isThisMonth
                    ? null
                    : () => setState(() {
                          _month = DateTime(_month.year, _month.month + 1);
                          _selected = null;
                        }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 星期表头（周一起始）。
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map((w) => Expanded(
                      child: Center(
                        child: Text(w,
                            style: AppTheme.caption(cs.onSurfaceVariant)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          // 日期网格。
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.92,
              mainAxisSpacing: 2,
            ),
            itemCount: rows * 7,
            itemBuilder: (context, index) {
              final day = index - leading + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(_month.year, _month.month, day);
              final entries = entriesByDay[date] ?? const <_CalEntry>[];
              final isSelected = selected == date;
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return GestureDetector(
                onTap: () => setState(() => _selected = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.10)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(color: cs.primary, width: 1.4)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: isToday
                            ? const BoxDecoration(
                                color: AppTheme.greenLight,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w800
                                : FontWeight.w400,
                            color: isToday
                                ? Colors.white
                                : cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (entries.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final e in entries.take(3))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 1),
                                child: Icon(e.icon,
                                    size: 10, color: e.color),
                              ),
                            if (entries.length > 3)
                              Text('+${entries.length - 3}',
                                  style: AppTheme.captionSm(
                                      cs.onSurfaceVariant)),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // 当日详情。
          SectionTitle(selected == null
              ? '选择日期查看记录'
              : '${selected.month}月${selected.day}日 · ${dayEntries.length} 条记录'),
          if (dayEntries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('这天没有记录',
                    style: AppTheme.subhead(cs.onSurfaceVariant)),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final e in dayEntries)
                    ListTile(
                      onTap: () => context.push(e.route),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: e.color.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(e.icon, size: 19, color: e.color),
                      ),
                      title: Text(e.title,
                          style: AppTheme.cardTitle(cs.onSurface)),
                      subtitle: e.subtitle.isEmpty
                          ? null
                          : Text(e.subtitle,
                              style: AppTheme.footnote(
                                  cs.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 日历上的一条事件。
class _CalEntry {
  const _CalEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;
}
