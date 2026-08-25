import 'enums.dart';

/// 喂食计划中的一餐。
class PlanMeal {
  PlanMeal({
    required this.time,
    required this.name,
    this.type,
    this.grams,
    this.kcal,
    this.items = const [],
    this.ingredients = const [],
    this.steps = const [],
  });

  /// 建议时间，如 "08:00"。
  final String time;

  /// 餐名，如 "早餐·狗粮" / "晚餐·鲜食"。
  final String name;

  /// kibble / fresh / mixed / treat。
  final String? type;
  final double? grams;
  final double? kcal;

  /// 食物明细（如「渴望成犬粮 120g」）。
  final List<String> items;

  /// 鲜食食材清单。
  final List<String> ingredients;

  /// 鲜食做法步骤。
  final List<String> steps;

  factory PlanMeal.fromJson(Map<String, dynamic> json) => PlanMeal(
        time: json['time'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String?,
        grams: (json['grams'] as num?)?.toDouble(),
        kcal: (json['kcal'] as num?)?.toDouble(),
        items: _strList(json['items']),
        ingredients: _strList(json['ingredients']),
        steps: _strList(json['steps']),
      );

  Map<String, dynamic> toJson() => {
        'time': time,
        'name': name,
        'type': type,
        'grams': grams,
        'kcal': kcal,
        'items': items,
        'ingredients': ingredients,
        'steps': steps,
      };

  static List<String> _strList(dynamic v) =>
      (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
}

/// 日维度喂食计划（AI 生成或手动建立）。
class MealPlan {
  MealPlan({
    required this.id,
    required this.petId,
    required this.date,
    required this.source,
    this.totalKcal,
    this.waterMl,
    this.meals = const [],
    this.advice,
    this.warnings = const [],
    this.repeatWeekly = false,
    required this.createdAt,
  });

  final String id;
  final String petId;
  final DateTime date;
  final PlanSource source;
  final double? totalKcal;
  final double? waterMl;
  final List<PlanMeal> meals;

  /// 总体建议（Markdown）。
  final String? advice;
  final List<String> warnings;

  /// 月度模式：本计划为一周循环模板，未来同星期按此执行。
  final bool repeatWeekly;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'date': date.toIso8601String(),
        'source': source.name,
        'content': {
          'totalKcal': totalKcal,
          'waterMl': waterMl,
          'meals': meals.map((m) => m.toJson()).toList(),
          'advice': advice,
          'warnings': warnings,
          'repeatWeekly': repeatWeekly,
        },
        'createdAt': createdAt.toIso8601String(),
      };

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>? ?? {};
    return MealPlan(
      id: json['id'] as String,
      petId: json['petId'] as String,
      date: DateTime.parse(json['date'] as String),
      source: PlanSource.fromName(json['source'] as String?),
      totalKcal: (content['totalKcal'] as num?)?.toDouble(),
      waterMl: (content['waterMl'] as num?)?.toDouble(),
      meals: (content['meals'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlanMeal.fromJson)
          .toList(),
      advice: content['advice'] as String?,
      warnings: _strList(content['warnings']),
      repeatWeekly: content['repeatWeekly'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(json['createdAt'] as String),
    );
  }

  static List<String> _strList(dynamic v) =>
      (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
}
