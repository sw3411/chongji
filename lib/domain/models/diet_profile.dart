import 'enums.dart';

/// 饮食偏好（每只宠物一份）。
class DietProfile {
  DietProfile({
    required this.petId,
    this.foodType = FoodType.mixed,
    this.brand,
    this.likes = const [],
    this.dislikes = const [],
    this.allergens = const [],
    this.mealsPerDay = 2,
    this.notes,
    required this.updatedAt,
  });

  final String petId;

  /// 主食类型：干粮 / 鲜食 / 混搭。
  final FoodType foodType;
  final String? brand;

  /// 爱吃的 / 不爱吃的 / 过敏源。
  final List<String> likes;
  final List<String> dislikes;
  final List<String> allergens;

  /// 每日正餐顿数。
  final int mealsPerDay;
  final String? notes;
  final DateTime updatedAt;

  DietProfile copyWith({
    FoodType? foodType,
    String? brand,
    List<String>? likes,
    List<String>? dislikes,
    List<String>? allergens,
    int? mealsPerDay,
    String? notes,
    DateTime? updatedAt,
  }) =>
      DietProfile(
        petId: petId,
        foodType: foodType ?? this.foodType,
        brand: brand ?? this.brand,
        likes: likes ?? this.likes,
        dislikes: dislikes ?? this.dislikes,
        allergens: allergens ?? this.allergens,
        mealsPerDay: mealsPerDay ?? this.mealsPerDay,
        notes: notes ?? this.notes,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'petId': petId,
        'foodType': foodType.name,
        'brand': brand,
        'likes': likes,
        'dislikes': dislikes,
        'allergens': allergens,
        'mealsPerDay': mealsPerDay,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DietProfile.fromJson(Map<String, dynamic> json) => DietProfile(
        petId: json['petId'] as String,
        foodType: FoodType.fromName(json['foodType'] as String?),
        brand: json['brand'] as String?,
        likes: _strList(json['likes']),
        dislikes: _strList(json['dislikes']),
        allergens: _strList(json['allergens']),
        mealsPerDay: json['mealsPerDay'] as int? ?? 2,
        notes: json['notes'] as String?,
        updatedAt: json['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(json['updatedAt'] as String),
      );

  static List<String> _strList(dynamic v) =>
      (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
}
