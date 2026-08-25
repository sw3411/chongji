import '../models/expense.dart';
import '../models/enums.dart';

/// 消费统计口径：月度 / 年度汇总、分类占比、月度趋势。
class StatisticsService {
  StatisticsService._();

  /// 指定月份（1-12）总支出（分）。
  static int monthTotal(List<Expense> expenses, int year, int month) {
    return expenses
        .where((e) => e.date.year == year && e.date.month == month)
        .fold(0, (sum, e) => sum + e.amount);
  }

  static int yearTotal(List<Expense> expenses, int year) =>
      expenses.where((e) => e.date.year == year).fold(0, (s, e) => s + e.amount);

  /// 分类占比（降序，占比按总额计算）。
  static List<CategorySlice> byCategory(List<Expense> expenses) {
    final totals = <ExpenseCategory, int>{};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    final total = totals.values.fold(0, (a, b) => a + b);
    final list = totals.entries
        .map((e) => CategorySlice(
              category: e.key,
              total: e.value,
              pct: total == 0 ? 0.0 : e.value / total * 100,
            ))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// 最近 N 个月（含当月）的月度支出序列，升序。
  static List<MonthPoint> monthlyTrend(List<Expense> expenses,
      {int months = 6, DateTime? now}) {
    final n = now ?? DateTime.now();
    return List.generate(months, (i) {
      final d = DateTime(n.year, n.month - (months - 1 - i));
      return MonthPoint(
        year: d.year,
        month: d.month,
        total: monthTotal(expenses, d.year, d.month),
      );
    });
  }

  /// 月均支出（分）。
  static int monthlyAverage(List<Expense> expenses,
      {int months = 12, DateTime? now}) {
    final trend = monthlyTrend(expenses, months: months, now: now);
    final active = trend.where((m) => m.total > 0).toList();
    if (active.isEmpty) return 0;
    return active.fold(0, (s, m) => s + m.total) ~/ active.length;
  }
}

class CategorySlice {
  CategorySlice({required this.category, required this.total, required this.pct});

  final ExpenseCategory category;
  final int total;
  final double pct;
}

class MonthPoint {
  MonthPoint({required this.year, required this.month, required this.total});

  final int year;
  final int month;
  final int total;

  String get label => '$year年$month月';
}
