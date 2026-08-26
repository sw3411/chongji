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
                // ---- 沉浸式健康大卡 ----
                _WellnessCard(
                  weights: weights,
                  latestWeight: latestWeight?.value,
                  weightChange: weightChange?.$1,
                  latestBcs: latestBcs?.value,
                  bcsBandText: latestBcs == null
                      ? null
                      : bcsBand(latestBcs.value!.toInt()),
                  bcsTrend: bcsTrend,
                  onWeightTap: () => context.push('/health/record/new',
                      extra: HealthRecordType.weight.name),
                  onBcsTap: () => context.push(
                      '/health/record/new',
                      extra: HealthRecordType.bcs.name),
                ),
                const SizedBox(height: 14),

                // ---- 趋势图（不足 2 条体重时给常驻引导入口）----
                if (weights.length >= 2)
                  _TrendChart(weights: weights, bcsRecords: bcsRecords)
                else
                  _ChartTeaser(weightCount: weights.length),
                const SizedBox(height: 18),

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
// 沉浸式健康大卡：渐变场景 + 大数字 + 背景 sparkline
// ============================================================

class _WellnessCard extends StatelessWidget {
  const _WellnessCard({
    required this.weights,
    this.latestWeight,
    this.weightChange,
    this.latestBcs,
    this.bcsBandText,
    this.bcsTrend,
    this.onWeightTap,
    this.onBcsTap,
  });

  final List<HealthRecord> weights;
  final double? latestWeight;
  final double? weightChange;
  final double? latestBcs;
  final String? bcsBandText;
  final (String, Color?)? bcsTrend;
  final VoidCallback? onWeightTap;
  final VoidCallback? onBcsTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 渐变底：浅色陶土暖渐变，深色暖夜渐变。
    final gradient = dark
        ? const LinearGradient(
            colors: [Color(0xFF463527), Color(0xFF2A2018)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFDE9B74), Color(0xFFC0665D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final onCard = Colors.white.withValues(alpha: 0.95);
    final onCardFaint = Colors.white.withValues(alpha: 0.55);

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 背景折线纹理：隐约的体重走势，不与前景争抢。
            if (weights.length >= 2)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.14,
                  child: _Sparkline(spots: [
                    for (final r in weights)
                      FlSpot(
                          r.date.millisecondsSinceEpoch.toDouble(), r.value!),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 体重大数字（点击记体重）。
                  GestureDetector(
                    onTap: onWeightTap,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              latestWeight == null
                                  ? '—'
                                  : latestWeight!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -1.5,
                                height: 1.05,
                                color: onCard,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text('kg',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w300,
                                    color: onCardFaint)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text('当前体重',
                                style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 2,
                                    color: onCardFaint)),
                            // 30 天变化胶囊。
                            if (weightChange != null &&
                                weightChange != 0) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '30天 ${weightChange! >= 0 ? "+" : ""}${weightChange!.toStringAsFixed(2)}kg',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: onCard,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // 发丝分隔线。
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: 14),
                  // 体型（点击记体型） + 记录按钮。
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onBcsTap,
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('体型 BCS',
                                  style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      color: onCardFaint)),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    latestBcs == null
                                        ? '未评估'
                                        : '${latestBcs!.toInt()}/9',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w400,
                                      color: onCard,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                  if (bcsTrend != null) ...[
                                    const SizedBox(width: 7),
                                    Text(
                                      bcsTrend!.$1,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: bcsTrend!.$2 == null
                                            ? onCardFaint
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                  if (bcsBandText != null) ...[
                                    const SizedBox(width: 6),
                                    Text(bcsBandText!,
                                        style: TextStyle(
                                            fontSize: 11, color: onCardFaint)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 记一笔按钮。
                      GestureDetector(
                        onTap: () => context.push('/health/record/new'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: onCard),
                              const SizedBox(width: 3),
                              Text('记一笔',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: onCard)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 背景装饰折线：无轴无网格无交互，Apple Health 式 sparkline。
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.spots});

  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    if (spots.length < 2) return const SizedBox.shrink();
    final minX = spots.first.x;
    var maxX = spots.last.x;
    if (maxX <= minX) maxX = minX + 1; // 同日两条记录时避免零宽。
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY).clamp(0.1, 10.0) * 0.35;
    return LineChart(
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
    );
  }
}

// ============================================================
// 趋势图：体重实线（渐变面积）× BCS 虚线，两端趋势外推
// ============================================================

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.weights, required this.bcsRecords});

  final List<HealthRecord> weights;
  final List<HealthRecord> bcsRecords;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSec = dark ? Colors.white38 : AppTheme.inkSecondary;
    final surface = dark ? AppTheme.darkSurface : Colors.white;
    final weightColor = AppTheme.green;
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
    double xOf(DateTime d) => d.difference(first).inDays.toDouble();

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

    return _QuietCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('体重趋势',
                    style: AppTheme.label(dark ? Colors.white30 : AppTheme.inkTertiary)),
                const Spacer(),
                // 图例。
                Row(
                  children: [
                    Container(
                        width: 12,
                        height: 2.5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: weightColor,
                        ),
                        margin: const EdgeInsets.only(right: 5)),
                    Text('体重', style: AppTheme.captionSm(inkSec)),
                    const SizedBox(width: 12),
                    if (hasBcs) ...[
                      Container(
                          width: 12,
                          height: 2.5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: bcsColor,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          margin: const EdgeInsets.only(right: 5)),
                      Text('体型', style: AppTheme.captionSm(inkSec)),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 170,
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
                      color: (dark ? Colors.white : AppTheme.ink)
                          .withValues(alpha: 0.05),
                      strokeWidth: 1,
                      dashArray: [2, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: hasBcs,
                        reservedSize: 22,
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
                    // 体重真实段：渐变面积 + 白圈端点。
                    LineChartBarData(
                      spots: wPredLeft == 0 && wPredRight == 0
                          ? weightAll
                          : weightAll.sublist(
                              wPredLeft, weightAll.length - wPredRight),
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
                    // 体重预测段（浅色虚线 + 空心端点）。
                    if (wPredLeft == 1)
                      LineChartBarData(
                        spots: weightAll.sublist(0, 2),
                        isCurved: false,
                        color: weightColor.withValues(alpha: 0.45),
                        barWidth: 2,
                        dashArray: [4, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 3.5,
                            color: surface,
                            strokeColor: weightColor.withValues(alpha: 0.6),
                            strokeWidth: 1.5,
                          ),
                        ),
                      ),
                    if (wPredRight == 1)
                      LineChartBarData(
                        spots:
                            weightAll.sublist(weightAll.length - 2),
                        isCurved: false,
                        color: weightColor.withValues(alpha: 0.45),
                        barWidth: 2,
                        dashArray: [4, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 3.5,
                            color: surface,
                            strokeColor: weightColor.withValues(alpha: 0.6),
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
                            radius: 3.5,
                            color: bcsColor,
                            strokeWidth: 2,
                            strokeColor: surface,
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
                            radius: 3.5,
                            color: surface,
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
                            radius: 3.5,
                            color: surface,
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
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                hasBcs
                    ? '右轴为体型分（1-9），绿色 5 分为理想体型；浅色虚线端点为趋势预测'
                    : '浅色虚线端点为按趋势外推的预测值',
                style: AppTheme.captionSm(inkSec),
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

/// 趋势图引导卡：体重记录不足 2 条时常驻显示，保证入口可见。
class _ChartTeaser extends StatelessWidget {
  const _ChartTeaser({required this.weightCount});

  final int weightCount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = weightCount == 0
        ? '记录体重后，这里会出现体重×体型趋势图'
        : '已有 1 次体重，再记 1 次即可看到趋势对比';
    return _QuietCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.show_chart_rounded,
                  size: 19, color: AppTheme.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('体重趋势',
                      style: AppTheme.cardTitle(
                          dark ? Colors.white : AppTheme.ink)),
                  const SizedBox(height: 2),
                  Text(text,
                      style: AppTheme.footnote(
                          dark ? Colors.white38 : AppTheme.inkSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push('/health/record/new',
                  extra: HealthRecordType.weight.name),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text('记体重',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: dark ? Colors.white70 : AppTheme.green)),
              ),
            ),
          ],
        ),
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

/// 类型筛选 chip：细线描边小胶囊，选中淡染。
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
            color: selected ? base.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? base.withValues(alpha: 0.30)
                  : dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppTheme.lightDivider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? base : (dark ? Colors.white38 : AppTheme.inkTertiary),
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

/// 安静的卡：浅色白底发丝描边无投影；深色微亮底。
class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.035) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: dark
            ? Border.all(color: Colors.white.withValues(alpha: 0.05))
            : Border.all(color: const Color(0x083D2E26)),
      ),
      child: child,
    );
  }
}
