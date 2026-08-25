import 'dart:math' as math;

import '../models/health_record.dart';
import '../models/pet.dart';
import '../models/enums.dart';
import '../../core/constants/breeds.dart';

/// 健康相关计算：年龄 / 体重趋势 / BCS 分档 / 下次到期 / 生日。
/// 全部纯函数，now 由调用方注入。
class HealthCalculator {
  HealthCalculator._();

  /// 月龄（按日历月近似：30.44 天/月）。
  static int ageInMonths(DateTime? birthday, {DateTime? now}) {
    if (birthday == null) return 0;
    final n = now ?? DateTime.now();
    if (birthday.isAfter(n)) return 0;
    int months = (n.year - birthday.year) * 12 + (n.month - birthday.month);
    if (n.day < birthday.day) months--;
    return math.max(0, months);
  }

  /// 年龄展示：不足 1 个月「刚到家」；不足 12 个月「X个月」；否则「X岁Y个月」。
  static String ageText(DateTime? birthday, {DateTime? now}) {
    if (birthday == null) return '年龄未填';
    final months = ageInMonths(birthday, now: now);
    if (months <= 0) return '未满月';
    if (months < 12) return '$months个月';
    final years = months ~/ 12;
    final rest = months % 12;
    return rest == 0 ? '$years岁' : '$years岁$rest个月';
  }

  /// 生活阶段（供热量系数与 AI 参考）。
  static String lifeStage(DateTime? birthday, PetSpecies species,
      {DateTime? now}) {
    final months = ageInMonths(birthday, now: now);
    if (months < 4) return '幼年（4个月以下）';
    if (months < 12) return '幼年（4-12个月）';
    final years = months / 12.0;
    if (species == PetSpecies.dog && years >= 7) return '老年';
    if (species == PetSpecies.cat && years >= 10) return '老年';
    return '成年';
  }

  /// 最新体重（kg）。记录未按时间排序时先排序。
  static HealthRecord? latestWeight(List<HealthRecord> records) {
    final weights = records.where((r) => r.type == HealthRecordType.weight);
    if (weights.isEmpty) return null;
    return weights.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  }

  static HealthRecord? latestBcs(List<HealthRecord> records) {
    final bcs = records.where((r) => r.type == HealthRecordType.bcs);
    if (bcs.isEmpty) return null;
    return bcs.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  }

  /// 体重趋势：与 windowDays 天前最近一次记录比较。
  /// 返回 (差值 kg, 变化率%)；样本不足返回 null。
  static (double, double)? weightChange(
    List<HealthRecord> records,
    int windowDays, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final weights = records
        .where((r) => r.type == HealthRecordType.weight && r.value != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (weights.isEmpty) return null;
    final latest = weights.last;
    final cutoff = n.subtract(Duration(days: windowDays));
    HealthRecord? baseline;
    for (final r in weights) {
      if (!r.date.isAfter(cutoff)) baseline = r;
    }
    // 窗口内只有一条：与更早的最近一条比（若有）。
    if (baseline == null && weights.length >= 2) baseline = weights.first;
    if (baseline == null || baseline.id == latest.id) return null;
    final diff = latest.value! - baseline.value!;
    final pct = baseline.value! == 0 ? 0.0 : diff / baseline.value! * 100;
    return (diff, pct);
  }

  /// 下次到期（疫苗/驱虫）：最近一次记录日期 + 周期。
  static DateTime? nextDue(
    List<HealthRecord> records,
    HealthRecordType type, {
    DateTime? now,
  }) {
    final list = records.where((r) => r.type == type).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (list.isEmpty) return null;
    // 有周期用周期；无周期用该类型默认周期。
    final last = list.last;
    final days = last.cycleDays ?? _defaultCycleDays(type);
    return last.date.add(Duration(days: days));
  }

  /// 默认周期：体内驱虫 90 天、体外驱虫 30 天、疫苗 365 天、
  /// 称重与体型评估建议每周一次（7 天）。
  static int _defaultCycleDays(HealthRecordType type) => switch (type) {
        HealthRecordType.dewormIn => 90,
        HealthRecordType.dewormOut => 30,
        HealthRecordType.vaccine => 365,
        HealthRecordType.weight => 7,
        HealthRecordType.bcs => 7,
        _ => 0,
      };

  /// 下一个生日（月日循环；今年已过则取明年）。
  static DateTime? nextBirthday(DateTime? birthday, {DateTime? now}) {
    if (birthday == null) return null;
    return nextAnnual(birthday, now: now);
  }

  /// 任意年度纪念日（生日 / 到家纪念日）的下一次到来。
  static DateTime? nextAnnual(DateTime? date, {DateTime? now}) {
    if (date == null) return null;
    final n = now ?? DateTime.now();
    var next = DateTime(n.year, date.month, date.day);
    if (next.isBefore(DateTime(n.year, n.month, n.day))) {
      next = DateTime(n.year + 1, date.month, date.day);
    }
    return next;
  }

  /// 品种典型体重区间文本（找不到返回 null）。
  static String? breedRangeLabel(Pet pet) => findBreed(pet.breed, pet.species)?.rangeLabel;
}

/// 首页到期项视图模型。
class DueItem {
  DueItem({
    required this.title,
    required this.date,
    required this.daysLeft,
    required this.kind,
  });

  final String title;
  final DateTime date;

  /// 负数 = 已过期天数。
  final int daysLeft;

  /// vaccine / dewormIn / dewormOut / birthday。
  final String kind;

  bool get overdue => daysLeft < 0;
}

/// 汇总一只宠物的全部到期项（疫苗 / 体内驱虫 / 体外驱虫 / 生日）。
List<DueItem> buildDueItems(
  Pet pet,
  List<HealthRecord> records, {
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final items = <DueItem>[];

  for (final type in [
    HealthRecordType.vaccine,
    HealthRecordType.dewormIn,
    HealthRecordType.dewormOut,
  ]) {
    final due = HealthCalculator.nextDue(records, type, now: n);
    if (due == null) continue;
    final days = due.difference(today).inDays;
    // 生日之外的到期项只显示未来 60 天与已过期 30 天内的。
    if (days > 60 || days < -30) continue;
    items.add(DueItem(
      title: '${type.label}到期',
      date: due,
      daysLeft: days,
      kind: type.name,
    ));
  }

  // 称重 / 体型评估：两次测量间隔不超过 7 天。
  // 到期前 3 天开始提示，过期 30 天后不再打扰。
  for (final type in [HealthRecordType.weight, HealthRecordType.bcs]) {
    final due = HealthCalculator.nextDue(records, type, now: n);
    if (due == null) continue;
    final days = due.difference(today).inDays;
    if (days > 3 || days < -30) continue;
    items.add(DueItem(
      title: type == HealthRecordType.weight ? '称重测量' : '体型评估',
      date: due,
      daysLeft: days,
      kind: type.name,
    ));
  }

  final birthday = HealthCalculator.nextBirthday(pet.birthday, now: n);
  if (birthday != null) {
    items.add(DueItem(
      title: '生日',
      date: birthday,
      daysLeft: birthday.difference(today).inDays,
      kind: 'birthday',
    ));
  }

  // 到家纪念日（与生日独立，都值得纪念）。
  final adoption = pet.adoptionDate;
  if (adoption != null) {
    final next = HealthCalculator.nextAnnual(adoption, now: n);
    // 到家当年不算纪念日。
    if (next != null && adoption.year < n.year) {
      items.add(DueItem(
        title: '到家纪念日',
        date: next,
        daysLeft: next.difference(today).inDays,
        kind: 'adoption',
      ));
    }
  }

  items.sort((a, b) => a.daysLeft.abs().compareTo(b.daysLeft.abs()));
  return items;
}
