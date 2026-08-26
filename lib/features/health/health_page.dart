import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/constants/bcs.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/pet.dart';
import '../../domain/services/health_calculator.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/sync_button.dart';

/// 健康页：沉浸式健康大卡（渐变 + 背景 sparkline）+ 趋势图 +
/// 疫苗/驱虫到期 + 类型筛选 + 按月分组记录。
class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
  HealthRecordType? _filter;

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petsProvider).valueOrNull ?? const <Pet>[];
    if (pets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('健康')),
        body: EmptyView(
          icon: Icons.pets,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));

    final weights = records
        .where((r) => r.type == HealthRecordType.weight && r.value != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final bcsRecords = records
        .where((r) => r.type == HealthRecordType.bcs && r.value != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final latestWeight = weights.isEmpty ? null : weights.last;
    final latestBcs = HealthCalculator.latestBcs(records);
    final weightChange = HealthCalculator.weightChange(records, 30);

    // 体型趋势：最近两次评估对比（变胖/变瘦/维持）。
    (String, Color?)? bcsTrend;
    if (bcsRecords.length >= 2 &&
        bcsRecords.last.value != null &&
        bcsRecords[bcsRecords.length - 2].value != null) {
      final d = bcsRecords.last.value!.toInt() -
          bcsRecords[bcsRecords.length - 2].value!.toInt();
      bcsTrend = d > 0
          ? ('变胖', AppTheme.warnRed)
          : d < 0
              ? ('变瘦', AppTheme.okGreen)
              : ('维持', null);
    }

    // 体重/体型每条记录的「上一次」，用于行内较上次对比。
    final prevById = <String, HealthRecord>{};
    for (final t in [HealthRecordType.weight, HealthRecordType.bcs]) {
      final asc = records.where((r) => r.type == t).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      for (var i = 1; i < asc.length; i++) {
        prevById[asc[i].id] = asc[i - 1];
      }
    }

    // 类型筛选：全部 + 出现过的类型（带计数）。
    final typeCounts = <HealthRecordType, int>{};
    for (final r in records) {
      typeCounts[r.type] = (typeCounts[r.type] ?? 0) + 1;
    }
    final presentTypes = HealthRecordType.values
        .where((t) => typeCounts.containsKey(t))
        .toList();
    final filtered = _filter == null
        ? sorted
        : sorted.where((r) => r.type == _filter).toList();
    final hasCycleRecords =
        records.any((r) => r.type == HealthRecordType.vaccine) ||
            records.any((r) => r.type == HealthRecordType.dewormIn) ||
            records.any((r) => r.type == HealthRecordType.dewormOut);

    return Scaffold(
      backgroundColor: dark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${pet.name} · 健康',
            style: AppTheme.cardTitle(dark ? Colors.white : AppTheme.ink)),
        actions: [
          const SyncButton(),
          IconButton(
            icon: Icon(Icons.calendar_month_outlined,
                color: dark ? Colors.white70 : AppTheme.inkSecondary),
            tooltip: '日历',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: Icon(Icons.add,
                color: dark ? Colors.white70 : AppTheme.inkSecondary),
            tooltip: '添加记录',
            onPressed: () => context.push('/health/record/new'),
          ),
        ],
      ),
      body: sorted.isEmpty
          ? EmptyView(
              icon: Icons.monitor_heart_outlined,
              title: '还没有健康记录',
              subtitle: '记录体重、疫苗、驱虫，到期自动提醒',
              action: FilledButton(
                onPressed: () => context.push('/health/record/new'),
                child: const Text('记第一条'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                // ---- 顶部数据区：大数字直接落在画布上 ----
                _DataHeader(
                  latestWeight: latestWeight?.value,
                  weightChange: weightChange?.$1,
                  bcs: latestBcs?.value?.toInt(),
                  bcsBandText:
                      latestBcs == null ? null : bcsBand(latestBcs.value!.toInt()),
                  bcsTrend: bcsTrend,
                  recordCount: sorted.length,
                  onBcsTap: () => context.push(
                      '/health/record/new',
                      extra: HealthRecordType.bcs.name),
                  onAddTap: () => context.push('/health/record/new'),
                ),

                // ---- 趋势图（融入页面，无卡片盒）（不足 2 条体重时常驻引导）----
                if (weights.length >= 2)
                  _TrendChart(weights: weights)
                else
                  _ChartTeaser(weightCount: weights.length),
                const SizedBox(height: 20),

                // ---- 疫苗与驱虫 ----
                if (hasCycleRecords) ...[
                  const _SectionLabel('疫苗与驱虫'),
                  _DueGroup(records: records),
                  const SizedBox(height: 18),
                ],

                // ---- 记录 ----
                const _SectionLabel('记录'),
                if (presentTypes.length > 1) ...[
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _TypeChip(
                          '全部 ${sorted.length}',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        ...presentTypes.map((t) => _TypeChip(
                              '${t.label} ${typeCounts[t]}',
                              selected: _filter == t,
                              color: recordTypeColor(t),
                              onTap: () => setState(() => _filter = t),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (filtered.isEmpty)
                  _QuietCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text('该类型还没有记录',
                            style: AppTheme.subhead(
                                dark ? Colors.white38 : AppTheme.inkTertiary)),
                      ),
                    ),
                  )
                else
                  ..._groupedByMonth(filtered, prevById, dark),
              ],
            ),
    );
  }

  /// 按月分组（月标题 + 行）。[prevById] 提供体重/体型的上一次记录。
  List<Widget> _groupedByMonth(List<HealthRecord> records,
      Map<String, HealthRecord> prevById, bool dark) {
    final groups = <String, List<HealthRecord>>{};
    for (final r in records) {
      final key = '${r.date.year}年${r.date.month}月';
      groups.putIfAbsent(key, () => []).add(r);
    }
    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      widgets.add(_SectionLabel(entry.key));
      widgets.add(_QuietCard(
        child: Column(
          children: [
            for (var i = 0; i < entry.value.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 58,
                  color: dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppTheme.lightDivider,
                ),
              _RecordRow(record: entry.value[i], previous: prevById[entry.value[i].id]),
            ],
          ],
        ),
      ));
      widgets.add(const SizedBox(height: 14));
    }
    return widgets;
  }
}

// ============================================================
// 顶部数据区：大数字直接落在画布上（与首页照片场景卡形成差异）
// ============================================================

class _DataHeader extends StatelessWidget {
  const _DataHeader({
    required this.latestWeight,
    required this.weightChange,
    required this.bcs,
    required this.bcsBandText,
    required this.bcsTrend,
    required this.recordCount,
    this.onBcsTap,
    this.onAddTap,
  });

  final double? latestWeight;
  final double? weightChange;
  final int? bcs;
  final String? bcsBandText;
  final (String, Color?)? bcsTrend;
  final int recordCount;
  final VoidCallback? onBcsTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : AppTheme.ink;
    final inkSec = dark ? Colors.white38 : AppTheme.inkSecondary;
    final inkTer = dark ? Colors.white30 : AppTheme.inkTertiary;
    final deltaColor = weightChange == null || weightChange == 0
        ? inkSec
        : weightChange! > 0
            ? AppTheme.warnRed
            : AppTheme.okGreen;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 体重大数字 + 30 天变化。
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前体重',
                        style: TextStyle(
                            fontSize: 11, letterSpacing: 2, color: inkTer)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          latestWeight == null
                              ? '—'
                              : latestWeight!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1.2,
                            height: 1.05,
                            color: ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('kg',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w300,
                                color: inkSec)),
                        if (weightChange != null && weightChange != 0) ...[
                          const SizedBox(width: 10),
                          Text(
                            '30天 ${weightChange! >= 0 ? "+" : ""}${weightChange!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: deltaColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 记一笔。
              GestureDetector(
                onTap: onAddTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: AppTheme.green),
                      const SizedBox(width: 3),
                      Text('记一笔',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.green)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 次级信息：体型（可点击记录） + 记录数。
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onBcsTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text('体型 BCS ', style: AppTheme.subhead(inkSec)),
                      Text(
                        bcs == null
                            ? '未评估 · 点击记录'
                            : '$bcs/9${bcsBandText == null ? '' : ' · $bcsBandText'}',
                        style: AppTheme.subhead(ink)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (bcsTrend != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '较上次${bcsTrend!.$1}',
                          style: AppTheme.subhead(bcsTrend!.$2 ?? inkSec)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Text('共 $recordCount 条',
                  style: AppTheme.captionSm(inkTer)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 趋势图：仅体重，融入画布（无卡片盒、无网格，底部发丝基线）
// ============================================================

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.weights});

  final List<HealthRecord> weights;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSec = dark ? Colors.white38 : AppTheme.inkSecondary;
    final surface = dark ? AppTheme.darkSurface : Colors.white;
    final weightColor = AppTheme.green;

    final first = weights.first.date;
    final lastDate = weights.last.date;
    double xOf(DateTime d) => d.difference(first).inDays.toDouble();
    final maxX = xOf(lastDate).clamp(1.0, double.infinity);

    final wValues = weights.map((r) => r.value!).toList();
    final minW = wValues.reduce((a, b) => a < b ? a : b);
    final maxW = wValues.reduce((a, b) => a > b ? a : b);
    final pad = (maxW - minW).clamp(0.2, 10.0) * 0.25;
    final minY = minW - pad;
    final maxY = maxW + pad;
    final range = maxY - minY;

    // 轴刻度按"比例位置"判定（0 / 0.5 / 1 三档），不因浮点漂移重叠。
    bool atFraction(double v, double f) =>
        ((v - minY) / range - f).abs() < 0.03;

    final spots = [
      for (final r in weights) FlSpot(xOf(r.date), r.value!),
    ];
    final spanDays = lastDate.difference(first).inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text('近 $spanDays 天体重',
                    style: AppTheme.label(
                        dark ? Colors.white30 : AppTheme.inkTertiary)),
                const Spacer(),
                Text('单位 kg', style: AppTheme.captionSm(inkSec)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color:
                          dark ? AppTheme.darkDivider : AppTheme.lightDivider,
                      width: 1,
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (maxX / 2).clamp(1.0, double.infinity),
                      getTitlesWidget: (v, _) {
                        final d = first.add(Duration(days: v.toInt()));
                        return SideTitleWidget(
                          axisSide: AxisSide.bottom,
                          child: Text('${d.month}/${d.day}',
                              style: AppTheme.captionSm(inkSec)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: range / 2,
                      getTitlesWidget: (v, _) {
                        if (!atFraction(v, 0.5) &&
                            !atFraction(v, 1) &&
                            !atFraction(v, 0)) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: AxisSide.left,
                          child: Text(
                            v.toStringAsFixed(1),
                            style: AppTheme.captionSm(inkSec),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: weightColor,
                    barWidth: 2.4,
                    dotData: FlDotData(
                      show: weights.length <= 12,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: weightColor,
                        strokeWidth: 2,
                        strokeColor: surface,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          weightColor.withValues(alpha: 0.14),
                          weightColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 趋势图引导：体重记录不足 2 条时的常驻入口（无卡片盒，融入画布）。
class _ChartTeaser extends StatelessWidget {
  const _ChartTeaser({required this.weightCount});

  final int weightCount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = weightCount == 0
        ? '记录体重后，这里会出现体重×体型趋势图'
        : '已有 1 次体重，再记 1 次即可看到趋势对比';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
      child: Row(
        children: [
          Icon(Icons.show_chart_rounded,
              size: 16,
              color: dark ? Colors.white30 : AppTheme.inkTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppTheme.subhead(
                    dark ? Colors.white38 : AppTheme.inkSecondary)),
          ),
          GestureDetector(
            onTap: () => context.push('/health/record/new',
                extra: HealthRecordType.weight.name),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text('记体重',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.green)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 疫苗与驱虫到期
// ============================================================

class _DueGroup extends StatelessWidget {
  const _DueGroup({required this.records});

  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final types = [
      HealthRecordType.vaccine,
      HealthRecordType.dewormIn,
      HealthRecordType.dewormOut,
    ];
    return _QuietCard(
      child: Column(
        children: [
          for (var i = 0; i < types.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 54,
                color: dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.lightDivider,
              ),
            _DueRow(records: records, type: types[i]),
          ],
        ],
      ),
    );
  }
}

/// 疫苗/驱虫到期行。
class _DueRow extends StatelessWidget {
  const _DueRow({required this.records, required this.type});

  final List<HealthRecord> records;
  final HealthRecordType type;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSec = dark ? Colors.white38 : AppTheme.inkSecondary;
    final due = HealthCalculator.nextDue(records, type);
    final latest = records
        .where((r) => r.type == type)
        .fold<HealthRecord?>(null, (last, r) =>
            last == null || r.date.isAfter(last.date) ? r : last);

    final today = DateTime.now();
    int? days;
    if (due != null) {
      days = due
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
    }
    final Color color = days == null
        ? inkSec
        : days < 0
            ? AppTheme.warnRed
            : days == 0
                ? AppTheme.warnRed
                : days <= 7
                    ? AppTheme.warnAmber
                    : AppTheme.okGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.label,
                    style: AppTheme.cardTitle(
                        dark ? Colors.white : AppTheme.ink)),
                const SizedBox(height: 2),
                Text(
                  latest == null
                      ? '还没有记录，添加后自动推算下次时间'
                      : due != null
                          ? '${due.month}月${due.day}日到期'
                          : '上次 ${latest.date.year}/${latest.date.month}/${latest.date.day}'
                              '${latest.textValue == null ? "" : " · ${latest.textValue}"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: days == null ? inkSec : color,
                    fontWeight: days == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/health/record/new', extra: type.name),
            child: days == null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('去记录',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.white70 : AppTheme.green)),
                  )
                : DueBadge(daysLeft: days),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 记录行 / 筛选 / 通用小组件
// ============================================================

/// 单条记录行（体重/体型带「较上次」彩色对比）。
class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, this.previous});

  final HealthRecord record;

  /// 同类型的上一次记录（按日期）。
  final HealthRecord? previous;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : AppTheme.ink;
    final inkSec = dark ? Colors.white38 : AppTheme.inkSecondary;
    final color = recordTypeColor(record.type);
    Widget? subtitle;
    if (record.type == HealthRecordType.weight) {
      subtitle = _DeltaText(
        current: record.value,
        previous: previous?.value,
        unit: 'kg',
        upLabel: '涨',
        downLabel: '跌',
        fixed: 2,
      );
    } else if (record.type == HealthRecordType.bcs) {
      subtitle = _DeltaText(
        current: record.value,
        previous: previous?.value,
        unit: '分',
        upLabel: '变胖',
        downLabel: '变瘦',
        flatLabel: '维持',
        fixed: 0,
        prefix: bcsBand(record.value?.toInt() ?? 5),
      );
    } else {
      final text = [
        if (record.textValue != null && record.textValue!.isNotEmpty)
          record.textValue!,
        if (record.diagnosis != null && record.diagnosis!.isNotEmpty)
          record.diagnosis!,
        if (record.notes != null && record.notes!.isNotEmpty) record.notes!,
      ].join(' · ');
      subtitle = text.isEmpty ? null : Text(text, style: AppTheme.footnote(inkSec));
    }
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      onTap: () => context.push('/health/record/${record.id}/edit'),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(recordTypeIcon(record.type), size: 16, color: color),
      ),
      // 日期与标题同行，副标题独占下方整行宽度。
      title: Row(
        children: [
          Expanded(
            child: Text(
              record.type == HealthRecordType.weight
                  ? '${record.value} kg'
                  : record.type.label,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${record.date.month}/${record.date.day}',
            style: TextStyle(
              fontSize: 10.5,
              color: inkSec,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 1.5),
              child: DefaultTextStyle(
                style: AppTheme.footnote(inkSec),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: subtitle,
              ),
            ),
    );
  }
}

/// 「较上次」变化文本：红涨绿跌，首次记录显示占位。
class _DeltaText extends StatelessWidget {
  const _DeltaText({
    required this.current,
    required this.previous,
    required this.unit,
    required this.upLabel,
    required this.downLabel,
    this.flatLabel = '持平',
    this.fixed = 2,
    this.prefix = '',
  });

  final double? current;
  final double? previous;
  final String unit;
  final String upLabel;
  final String downLabel;
  final String flatLabel;
  final int fixed;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSec = dark ? Colors.white38 : AppTheme.inkSecondary;
    final cur = current;
    final prev = previous;
    if (cur == null) return const SizedBox.shrink();
    if (prev == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefix.isNotEmpty)
            Flexible(
              child: Text(prefix, style: AppTheme.footnote(inkSec)),
            ),
          if (prefix.isNotEmpty) const SizedBox(width: 6),
          Text('首次记录', style: AppTheme.footnote(inkSec)),
        ],
      );
    }
    final d = cur - prev;
    final Color color;
    final String label;
    if (d > 0) {
      color = AppTheme.warnRed;
      label = '+${d.toStringAsFixed(fixed)}$unit $upLabel';
    } else if (d < 0) {
      color = AppTheme.okGreen;
      label = '${d.toStringAsFixed(fixed)}$unit $downLabel';
    } else {
      color = inkSec;
      label = flatLabel;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix.isNotEmpty)
          Flexible(child: Text(prefix, style: AppTheme.footnote(inkSec))),
        if (prefix.isNotEmpty) const SizedBox(width: 6),
        Flexible(
          child: Text(
            '较上次 $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.footnote(color)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// 类型筛选 chip：未选中白瓷片，选中淡染（无描边）。
class _TypeChip extends StatelessWidget {
  const _TypeChip(
    this.label, {
    required this.selected,
    this.color,
    this.onTap,
  });

  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? (dark ? Colors.white : AppTheme.ink);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? base.withValues(alpha: 0.11)
                : (dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? base
                  : (dark ? Colors.white38 : AppTheme.inkTertiary),
            ),
          ),
        ),
      ),
    );
  }
}

/// 区块小标题：小字 + 字距。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: dark ? Colors.white30 : AppTheme.inkTertiary,
        ),
      ),
    );
  }
}

/// 安静的卡：白瓷片（画布底色差分层，无描边无投影）；深色微亮底。
class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: child,
    );
  }
}
