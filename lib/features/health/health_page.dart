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

/// 健康页：体重×体型合并趋势图 + 类型筛选 + 疫苗/驱虫到期 + 按月分组记录。
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
    final cs = Theme.of(context).colorScheme;
    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));

    final weights = records
        .where((r) =>
            r.type == HealthRecordType.weight && r.value != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final bcsRecords = records
        .where((r) => r.type == HealthRecordType.bcs && r.value != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final latestWeight = weights.isEmpty ? null : weights.last;
    final latestBcs = HealthCalculator.latestBcs(records);
    final weightChange = HealthCalculator.weightChange(records, 30);

    // 体型趋势：最近两次评估对比（变胖/变瘦/维持，红/绿/灰）。
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

    return Scaffold(
      appBar: AppBar(
        title: Text('${pet.name} · 健康'),
        actions: [
          const SyncButton(),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '日历',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
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
              padding: const EdgeInsets.all(16),
              children: [
                // 体重 + 体型双卡（变化红涨绿跌）。
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: '当前体重',
                        value:
                            latestWeight == null ? '—' : '${latestWeight.value}',
                        subValue: latestWeight == null
                            ? '未记录'
                            : weightChange == null
                                ? 'kg'
                                : '30天 ${weightChange.$1 >= 0 ? "+" : ""}${weightChange.$1.toStringAsFixed(2)}kg',
                        subValueColor: weightChange == null || weightChange.$1 == 0
                            ? null
                            : weightChange.$1 > 0
                                ? AppTheme.warnRed
                                : AppTheme.okGreen,
                        onTap: () => context.push('/health/record/new',
                            extra: HealthRecordType.weight.name),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricTile(
                        label: '体型 BCS',
                        value: latestBcs == null
                            ? '—'
                            : '${latestBcs.value!.toInt()}/9',
                        subValue: latestBcs == null
                            ? '未评估'
                            : bcsBand(latestBcs.value!.toInt()) +
                                (bcsTrend == null ? '' : ' · ${bcsTrend.$1}'),
                        subValueColor: bcsTrend?.$2,
                        accent: latestBcs != null && latestBcs.value! >= 6,
                        onTap: () => context.push('/health/record/new',
                            extra: HealthRecordType.bcs.name),
                      ),
                    ),
                  ],
                ),
                // 趋势图区：不足 2 条体重时给常驻引导入口，而不是整个消失。
                const SizedBox(height: 16),
                if (weights.length >= 2)
                  _WeightBcsChart(weights: weights, bcsRecords: bcsRecords)
                else
                  _ChartTeaser(weightCount: weights.length),
                const SectionTitle('疫苗与驱虫'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final type in [
                          HealthRecordType.vaccine,
                          HealthRecordType.dewormIn,
                          HealthRecordType.dewormOut,
                        ])
                          _DueRow(records: records, type: type),
                      ],
                    ),
                  ),
                ),
                const SectionTitle('记录'),
                // 类型筛选条。
                if (presentTypes.length > 1)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SelectChip(
                            '全部 ${sorted.length}',
                            selected: _filter == null,
                            color: cs.primary,
                            onSelected: (_) =>
                                setState(() => _filter = null),
                          ),
                        ),
                        for (final t in presentTypes)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SelectChip(
                              '${t.label} ${typeCounts[t]}',
                              selected: _filter == t,
                              color: recordTypeColor(t),
                              onSelected: (_) => setState(() => _filter = t),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('该类型还没有记录',
                            style: AppTheme.subhead(cs.onSurfaceVariant)),
                      ),
                    ),
                  )
                else
                  ..._groupedByMonth(context, filtered, prevById, cs),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  /// 按月分组（月标题 + 行）。[prevById] 提供体重/体型的上一次记录。
  List<Widget> _groupedByMonth(BuildContext context,
      List<HealthRecord> records, Map<String, HealthRecord> prevById,
      ColorScheme cs) {
    final groups = <String, List<HealthRecord>>{};
    for (final r in records) {
      final key = '${r.date.year}年${r.date.month}月';
      groups.putIfAbsent(key, () => []).add(r);
    }
    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Text(entry.key, style: AppTheme.label(cs.onSurfaceVariant)),
      ));
      widgets.add(Card(
        child: Column(
          children: entry.value
              .map((r) => _RecordRow(
                    record: r,
                    previous: prevById[r.id],
                  ))
              .toList(),
        ),
      ));
    }
    return widgets;
  }
}

/// 趋势图引导卡：体重记录不足 2 条时常驻显示，保证入口可见。
class _ChartTeaser extends StatelessWidget {
  const _ChartTeaser({required this.weightCount});

  final int weightCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = weightCount == 0
        ? '记录体重后，这里会出现体重×体型趋势图'
        : '已有 1 次体重，再记 1 次即可看到趋势对比';
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.show_chart_rounded,
                    size: 24, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('趋势图', style: AppTheme.cardTitle(cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(text, style: AppTheme.footnote(cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => context.push('/health/record/new',
                    extra: HealthRecordType.weight.name),
                child: const Text('记体重'),
              ),
            ],
          ),
        ),
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
    final cs = Theme.of(context).colorScheme;
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
        ? cs.onSurfaceVariant
        : days < 0
            ? AppTheme.warnRed
            : days == 0
                ? AppTheme.warnRed
                : days <= 7
                    ? AppTheme.warnAmber
                    : AppTheme.okGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.label, style: AppTheme.cardTitle(cs.onSurface)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (due != null)
                      DatePill(
                        '${due.month}月${due.day}日到期',
                        color: color,
                        compact: true,
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        latest == null
                            ? '还没有记录，添加后自动推算下次时间'
                            : '上次 ${latest.date.year}/${latest.date.month}/${latest.date.day}'
                                '${latest.textValue == null ? "" : " · ${latest.textValue}"}',
                        style: AppTheme.footnote(cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.push('/health/record/new', extra: type.name),
            child: days == null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('去记录',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.primary)),
                  )
                : DueBadge(daysLeft: days),
          ),
        ],
      ),
    );
  }
}

/// 单条记录行（体重/体型带「较上次」彩色对比）。
class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, this.previous});

  final HealthRecord record;

  /// 同类型的上一次记录（按日期）。
  final HealthRecord? previous;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
      final band =
          '体型 ${record.value?.toInt() ?? "?"}/9 · ${bcsBand(record.value?.toInt() ?? 5)}';
      final delta = _DeltaText(
        current: record.value,
        previous: previous?.value,
        unit: '分',
        upLabel: '变胖',
        downLabel: '变瘦',
        flatLabel: '维持',
        fixed: 0,
        prefix: '$band · ',
      );
      subtitle = delta;
    } else {
      final text = [
        if (record.textValue != null && record.textValue!.isNotEmpty)
          record.textValue!,
        if (record.diagnosis != null && record.diagnosis!.isNotEmpty)
          record.diagnosis!,
        if (record.notes != null && record.notes!.isNotEmpty) record.notes!,
      ].join(' · ');
      subtitle =
          text.isEmpty ? null : Text(text, style: AppTheme.footnote(cs.onSurfaceVariant));
    }
    return ListTile(
      onTap: () => context.push('/health/record/${record.id}/edit'),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          recordTypeIcon(record.type),
          size: 20,
          color: color,
        ),
      ),
      // 日期与标题同行，副标题独占下方整行宽度（描述不再挤成多行）。
      title: Row(
        children: [
          Expanded(
            child: Text(
              record.type == HealthRecordType.weight
                  ? '${record.value} kg'
                  : record.type.label,
              style: AppTheme.cardTitle(cs.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          DatePill(
            '${record.date.month}/${record.date.day}',
            color: color,
            compact: true,
          ),
        ],
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: DefaultTextStyle(
                style: AppTheme.footnote(cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: subtitle,
              ),
            ),
    );
  }
}

/// 体重 × 体型合并趋势图：左轴体重（kg），右轴 BCS（1-9），
/// BCS 通过仿射变换映射到体重坐标区间，5 分（理想）绿色标出。
class _WeightBcsChart extends StatelessWidget {
  const _WeightBcsChart({
    required this.weights,
    required this.bcsRecords,
  });

  final List<HealthRecord> weights;
  final List<HealthRecord> bcsRecords;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bcsColor = AppTheme.warnAmber;

    final DateTime first;
    final DateTime lastDate;
    if (bcsRecords.isEmpty) {
      first = weights.first.date;
      lastDate = weights.last.date;
    } else {
      first = weights.first.date.isBefore(bcsRecords.first.date)
          ? weights.first.date
          : bcsRecords.first.date;
      lastDate = weights.last.date.isAfter(bcsRecords.last.date)
          ? weights.last.date
          : bcsRecords.last.date;
    }
    double xOf(DateTime d) {
      final x = d.difference(first).inDays.toDouble();
      return x;
    }

    final maxX = (xOf(lastDate).clamp(1.0, double.infinity));

    final wValues = weights.map((r) => r.value!).toList();
    final minW = wValues.reduce((a, b) => a < b ? a : b);
    final maxW = wValues.reduce((a, b) => a > b ? a : b);
    final pad = (maxW - minW).clamp(0.2, 10.0) * 0.3;
    final minY = minW - pad;
    final maxY = maxW + pad;
    // BCS 1-9 仿射映射到 [minY, maxY]。
    double yOfBcs(double bcs) => minY + (bcs - 1) / 8 * (maxY - minY);

    final weightSpots = [
      for (final r in weights) FlSpot(xOf(r.date), r.value!),
    ];
    final bcsSpots = [
      for (final r in bcsRecords) FlSpot(xOf(r.date), yOfBcs(r.value!)),
    ];
    final hasBcs = bcsSpots.isNotEmpty;

    // 两端趋势外推：体重与 BCS 记录日期往往不齐（如体重 5/1 起、
    // BCS 5/20 起），把没覆盖全局时间范围的一端按自身最小二乘趋势
    // 补一个预测点，让两条线在视觉上同框可比。预测段用浅色虚线区分。
    (double, double) fitLine(List<FlSpot> pts) {
      if (pts.length == 1) return (0, pts.first.y);
      var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
      for (final p in pts) {
        sx += p.x;
        sy += p.y;
        sxx += p.x * p.x;
        sxy += p.x * p.y;
      }
      final n = pts.length.toDouble();
      final denom = n * sxx - sx * sx;
      final slope = denom == 0 ? 0.0 : (n * sxy - sx * sy) / denom;
      return (slope, (sy - slope * sx) / n);
    }

    List<FlSpot> endsWithPrediction(
      List<FlSpot> pts, {
      required double Function(double) clampY,
    }) {
      if (pts.isEmpty) return pts;
      final (slope, intercept) = fitLine(pts);
      final out = [...pts];
      if (pts.first.x > 0.5) {
        out.insert(0, FlSpot(0, clampY(intercept)));
      }
      if (pts.last.x < maxX - 0.5) {
        out.add(FlSpot(maxX, clampY(slope * maxX + intercept)));
      }
      return out;
    }

    // 体重：预测值夹在图幅内；BCS：先在 1-9 分原始空间外推再映射。
    final weightAll = endsWithPrediction(weightSpots,
        clampY: (y) => y.clamp(minY, maxY));
    List<FlSpot> bcsAll = [];
    if (hasBcs) {
      final raw = [
        for (final r in bcsRecords) (xOf(r.date), r.value!),
      ];
      final extended = endsWithPrediction(
        [for (final p in raw) FlSpot(p.$1, p.$2)],
        clampY: (y) => y.clamp(1, 9),
      );
      bcsAll = [
        // 前后各可能多一个预测点，其余为真实点；统一转映射坐标。
        for (final p in extended) FlSpot(p.x, yOfBcs(p.y)),
      ];
    }
    // 真实点与预测点的分段索引（用于浅色虚线绘制）。
    final wPredLeft = weightAll.length > weightSpots.length &&
            weightAll.first.x == 0
        ? 1
        : 0;
    final wPredRight = weightAll.length - weightSpots.length - wPredLeft;
    final bPredLeft = hasBcs && bcsAll.length > bcsSpots.length && bcsAll.first.x == 0 ? 1 : 0;
    final bPredRight = hasBcs ? bcsAll.length - bcsSpots.length - bPredLeft : 0;

    // 轴刻度统一按"比例位置"判定（0 / 0.5 / 1 三档），
    // 左右轴刻度严格对齐且不会因浮点 interval 漂移产生重叠刻度。
    final range = maxY - minY;
    bool atFraction(double v, double f) =>
        ((v - minY) / range - f).abs() < 0.03;

    final last = weights.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('趋势', style: AppTheme.label(cs.onSurfaceVariant)),
                const Spacer(),
                // 图例。
                Row(
                  children: [
                    Container(
                        width: 10,
                        height: 3,
                        color: cs.primary,
                        margin: const EdgeInsets.only(right: 4)),
                    Text('体重', style: AppTheme.captionSm(cs.onSurfaceVariant)),
                    const SizedBox(width: 10),
                    if (hasBcs) ...[
                      Container(
                          width: 10,
                          height: 3,
                          color: bcsColor,
                          margin: const EdgeInsets.only(right: 4)),
                      Text('体型BCS',
                          style: AppTheme.captionSm(cs.onSurfaceVariant)),
                    ],
                  ],
                ),
                const SizedBox(width: 12),
                Text('${last.value} kg',
                    style: AppTheme.bigNumber(cs.primary, size: 18)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 168,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: range / 2,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: hasBcs,
                        reservedSize: 26,
                        interval: range / 2,
                        getTitlesWidget: (v, _) {
                          // 只在 1 / 5 / 9 三档显示，与左轴刻度同高对齐。
                          if (atFraction(v, 0.5)) {
                            return _bcsTitle('5', bcsColor,
                                highlight: true);
                          }
                          if (atFraction(v, 1)) return _bcsTitle('9', bcsColor);
                          if (atFraction(v, 0)) {
                            return _bcsTitle('1', bcsColor);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (maxX / 2).clamp(1.0, double.infinity),
                        getTitlesWidget: (v, _) {
                          final d = first.add(Duration(days: v.toInt()));
                          return SideTitleWidget(
                            axisSide: AxisSide.bottom,
                            child: Text('${d.month}/${d.day}',
                                style:
                                    AppTheme.captionSm(cs.onSurfaceVariant)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
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
                              style: AppTheme.captionSm(cs.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    // 体重真实段。
                    LineChartBarData(
                      spots: wPredLeft == 0 && wPredRight == 0
                          ? weightAll
                          : weightAll.sublist(
                              wPredLeft, weightAll.length - wPredRight),
                      isCurved: false,
                      color: cs.primary,
                      barWidth: 2.4,
                      dotData: FlDotData(
                        show: weights.length <= 12,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: cs.primary,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: wPredLeft == 0 && wPredRight == 0
                          ? BarAreaData(
                              show: true,
                              color: cs.primary.withValues(alpha: 0.08),
                            )
                          : BarAreaData(show: false),
                    ),
                    // 体重预测段（浅色虚线 + 空心端点）。
                    if (wPredLeft == 1)
                      LineChartBarData(
                        spots: weightAll.sublist(0, 2),
                        isCurved: false,
                        color: cs.primary.withValues(alpha: 0.45),
                        barWidth: 2,
                        dashArray: [4, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: cs.surface,
                            strokeColor: cs.primary.withValues(alpha: 0.6),
                            strokeWidth: 1.5,
                          ),
                        ),
                      ),
                    if (wPredRight == 1)
                      LineChartBarData(
                        spots:
                            weightAll.sublist(weightAll.length - 2),
                        isCurved: false,
                        color: cs.primary.withValues(alpha: 0.45),
                        barWidth: 2,
                        dashArray: [4, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: cs.surface,
                            strokeColor: cs.primary.withValues(alpha: 0.6),
                            strokeWidth: 1.5,
                          ),
                        ),
                      ),
                    // BCS 真实段。
                    if (hasBcs)
                      LineChartBarData(
                        spots: bPredLeft == 0 && bPredRight == 0
                            ? bcsAll
                            : bcsAll.sublist(
                                bPredLeft, bcsAll.length - bPredRight),
                        isCurved: false,
                        color: bcsColor,
                        barWidth: 1.8,
                        dashArray: [5, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: bcsColor,
                            strokeWidth: 1.5,
                            strokeColor: cs.surface,
                          ),
                        ),
                      ),
                    // BCS 预测段。
                    if (hasBcs && bPredLeft == 1)
                      LineChartBarData(
                        spots: bcsAll.sublist(0, 2),
                        isCurved: false,
                        color: bcsColor.withValues(alpha: 0.45),
                        barWidth: 1.6,
                        dashArray: [3, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: cs.surface,
                            strokeColor: bcsColor.withValues(alpha: 0.6),
                            strokeWidth: 1.5,
                          ),
                        ),
                      ),
                    if (hasBcs && bPredRight == 1)
                      LineChartBarData(
                        spots: bcsAll.sublist(bcsAll.length - 2),
                        isCurved: false,
                        color: bcsColor.withValues(alpha: 0.45),
                        barWidth: 1.6,
                        dashArray: [3, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: cs.surface,
                            strokeColor: bcsColor.withValues(alpha: 0.6),
                            strokeWidth: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                hasBcs
                    ? '右轴为体型分（1-9），绿色 5 分为理想体型；浅色虚线端点为趋势预测'
                    : '浅色虚线端点为按趋势外推的预测值',
                style: AppTheme.captionSm(cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bcsTitle(String text, Color color, {bool highlight = false}) =>
      SideTitleWidget(
        axisSide: AxisSide.right,
        child: Text(
          text,
          style: AppTheme.captionSm(highlight ? AppTheme.okGreen : color)
              .copyWith(fontWeight: highlight ? FontWeight.w800 : null),
        ),
      );
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
    final cs = Theme.of(context).colorScheme;
    final cur = current;
    final prev = previous;
    if (cur == null) return const SizedBox.shrink();
    final text = Text(
      prefix.isEmpty ? '体重记录' : prefix,
      style: AppTheme.footnote(cs.onSurfaceVariant),
    );
    if (prev == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: text),
          const SizedBox(width: 6),
          Text('首次记录', style: AppTheme.footnote(cs.onSurfaceVariant)),
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
      color = cs.onSurfaceVariant;
      label = flatLabel;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix.isNotEmpty) Flexible(child: text),
        if (prefix.isNotEmpty) const SizedBox(width: 6),
        Flexible(
          child: Text(
            '较上次 $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.footnote(color)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
