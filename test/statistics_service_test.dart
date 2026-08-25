import 'package:flutter_test/flutter_test.dart';
import 'package:chongji/domain/models/enums.dart';
import 'package:chongji/domain/models/expense.dart';
import 'package:chongji/domain/services/statistics_service.dart';

Expense exp(int yuan, int month, int day, ExpenseCategory category,
        {int year = 2026}) =>
    Expense(
      id: 'e$yuan-$month-$day-${category.name}',
      petId: 'p1',
      category: category,
      title: category.label,
      amount: yuan * 100,
      date: DateTime(year, month, day),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 8, 25);

  final expenses = [
    exp(200, 8, 1, ExpenseCategory.food),
    exp(300, 8, 10, ExpenseCategory.medical),
    exp(80, 8, 20, ExpenseCategory.food),
    exp(500, 7, 15, ExpenseCategory.grooming),
    exp(120, 6, 2, ExpenseCategory.toys),
  ];

  group('monthTotal / yearTotal', () {
    test('8 月合计 580 元', () {
      expect(StatisticsService.monthTotal(expenses, 2026, 8), 58000);
    });

    test('年度合计', () {
      expect(StatisticsService.yearTotal(expenses, 2026), 120000);
    });

    test('空月份为 0', () {
      expect(StatisticsService.monthTotal(expenses, 2025, 8), 0);
    });
  });

  group('byCategory', () {
    test('占比降序', () {
      final slices = StatisticsService.byCategory(expenses);
      // 最大单项：美容 500 元。
      expect(slices.first.category, ExpenseCategory.grooming);
      expect(slices.first.total, 50000);
      // 全部分类占比合计 100%。
      final sum = slices.fold(0.0, (s, e) => s + e.pct);
      expect(sum, closeTo(100, 0.001));
    });

    test('空数据', () {
      expect(StatisticsService.byCategory([]), isEmpty);
    });
  });

  group('monthlyTrend', () {
    test('最近 3 个月升序', () {
      final trend = StatisticsService.monthlyTrend(expenses, months: 3, now: now);
      expect(trend.length, 3);
      expect(trend.map((m) => m.month).toList(), [6, 7, 8]);
      expect(trend.last.total, 58000);
    });
  });

  group('monthlyAverage', () {
    test('只对有记录的月份求均值', () {
      // 有记录月份：6 月 120、7 月 500、8 月 580 → 均 400。
      expect(
        StatisticsService.monthlyAverage(expenses, months: 3, now: now),
        40000,
      );
    });

    test('无记录为 0', () {
      expect(StatisticsService.monthlyAverage([], now: now), 0);
    });
  });
}
