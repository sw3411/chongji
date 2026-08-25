import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/pet.dart';
import '../../domain/services/statistics_service.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/sync_button.dart';

/// 账本页：月度汇总 + 分类占比 + 趋势 + 明细。
class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final expenses =
        ref.watch(expensesProvider).valueOrNull ?? const <Expense>[];
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    final cs = Theme.of(context).colorScheme;

    final monthExpenses = expenses
        .where((e) => e.date.year == _month.year && e.date.month == _month.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = monthExpenses.fold(0, (s, e) => s + e.amount);
    final slices = StatisticsService.byCategory(monthExpenses);
    final trend = StatisticsService.monthlyTrend(
        expenses.where((e) => e.date.year == _month.year).toList(),
        months: 12,
        now: _month);
    final avg = StatisticsService.monthlyAverage(expenses, now: _month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账本'),
        actions: [
          const SyncButton(),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导出 CSV',
            onPressed: () async {
              await ref
                  .read(backupServiceProvider)
                  .exportCsv(expenses, {for (final p in pets) p.id: p.name});
              if (context.mounted) showAutoToast(context, '已导出 CSV');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '记一笔',
            onPressed: () => context.push('/expense/new'),
          ),
        ],
      ),
      body: expenses.isEmpty
          ? EmptyView(
              icon: Icons.account_balance_wallet_outlined,
              title: '还没有消费记录',
              subtitle: '粮、零食、医疗、美容…\n为它花的每一笔都记下来',
              action: FilledButton(
                onPressed: () => context.push('/expense/new'),
                child: const Text('记第一笔'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 月份切换 + 月度大数字。
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() =>
                          _month = DateTime(_month.year, _month.month - 1)),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(Fmt.monthCn(_month),
                            style: AppTheme.title(cs.onSurface)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _isCurrentMonth()
                          ? null
                          : () => setState(() =>
                              _month = DateTime(_month.year, _month.month + 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    Money.format(total),
                    style: AppTheme.largeTitle(cs.onSurface),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '本月 ${monthExpenses.length} 笔 · 月均 ${Money.formatCompact(avg)}',
                    style: AppTheme.subhead(cs.onSurfaceVariant),
                  ),
                ),
                if (slices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('分类占比',
                              style: AppTheme.label(cs.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 140,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 126,
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 32,
                                      sections: [
                                        for (final s in slices.take(6))
                                          PieChartSectionData(
                                            value: s.total.toDouble(),
                                            color: expenseCategoryColor(
                                                s.category),
                                            radius: 13,
                                            showTitle: false,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final s in slices.take(5))
                                        Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 3),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color:
                                                      expenseCategoryColor(
                                                          s.category),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // 分类名单行省略，金额自适应缩放，杜绝换行。
                                              Flexible(
                                                child: Text(
                                                  s.category.label,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTheme.footnote(
                                                      cs.onSurface),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '${Money.formatCompact(s.total)}·${s.pct.toStringAsFixed(0)}%',
                                                  maxLines: 1,
                                                  style: AppTheme.footnote(
                                                          cs.onSurfaceVariant)
                                                      .copyWith(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontFeatures: const [
                                                      FontFeature
                                                          .tabularFigures()
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (trend.where((t) => t.total > 0).length >= 2) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('月度趋势',
                              style: AppTheme.label(cs.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 110,
                            child: BarChart(
                              BarChartData(
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(),
                                  rightTitles: const AxisTitles(),
                                  leftTitles: const AxisTitles(),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 20,
                                      getTitlesWidget: (v, _) {
                                        final i = v.toInt();
                                        if (i < 0 ||
                                            i >= trend.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return Text(
                                            '${trend[i].month}月',
                                            style: AppTheme.captionSm(
                                                cs.onSurfaceVariant));
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: [
                                  for (var i = 0; i < trend.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: trend[i].total / 100.0,
                                          color: i == _month.month - 1
                                              ? cs.primary
                                              : cs.primary
                                                  .withValues(alpha: 0.25),
                                          width: 14,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SectionTitle('明细'),
                Card(
                  child: Column(
                    children: monthExpenses.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text('本月还没有消费',
                                  style: AppTheme.subhead(
                                      cs.onSurfaceVariant)),
                            ),
                          ]
                        : monthExpenses
                            .map((e) => _ExpenseRow(
                                expense: e, petName: _petName(e.petId, pets)))
                            .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  bool _isCurrentMonth() {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  static String _petName(String? petId, List<Pet> pets) {
    if (petId == null) return '全体';
    for (final p in pets) {
      if (p.id == petId) return p.name;
    }
    return '';
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.petName});

  final Expense expense;
  final String petName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = expenseCategoryColor(expense.category);
    return ListTile(
      onTap: () => context.push('/expense/${expense.id}/edit'),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          switch (expense.category) {
            ExpenseCategory.food => Icons.rice_bowl_outlined,
            ExpenseCategory.treats => Icons.cookie_outlined,
            ExpenseCategory.medical => Icons.local_hospital_outlined,
            ExpenseCategory.grooming => Icons.content_cut_outlined,
            ExpenseCategory.toys => Icons.toys_outlined,
            ExpenseCategory.supplies => Icons.shopping_bag_outlined,
            ExpenseCategory.insurance => Icons.shield_outlined,
            ExpenseCategory.other => Icons.more_horiz,
          },
          size: 20,
          color: color,
        ),
      ),
      title: Text(expense.title, style: AppTheme.cardTitle(cs.onSurface)),
      subtitle: Text(
        '${expense.category.label}'
        '${petName.isEmpty ? "" : " · $petName"}'
        '${expense.notes == null || expense.notes!.isEmpty ? "" : " · ${expense.notes}"}',
        style: AppTheme.footnote(cs.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        Money.format(expense.amount),
        style: AppTheme.bigNumber(cs.onSurface, size: 15),
      ),
    );
  }
}
