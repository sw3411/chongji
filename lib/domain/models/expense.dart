import 'enums.dart';

/// 消费记录。金额以分（int）存储；petId 为空表示全体宠物共用支出。
class Expense {
  Expense({
    required this.id,
    this.petId,
    required this.category,
    required this.title,
    required this.amount,
    required this.date,
    this.notes,
    this.imagePaths = const [],
    this.relatedRecordId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String? petId;
  final ExpenseCategory category;
  final String title;

  /// 金额（分）。
  final int amount;
  final DateTime date;
  final String? notes;
  final List<String> imagePaths;

  /// 关联的健康记录（如就诊费）。
  final String? relatedRecordId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 云同步墓碑：非空 = 已删除（保留一段时间供其他设备同步删除语义）。
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Expense copyWith({
    String? petId,
    ExpenseCategory? category,
    String? title,
    int? amount,
    DateTime? date,
    String? notes,
    List<String>? imagePaths,
    String? relatedRecordId,
    DateTime? updatedAt,
  }) =>
      Expense(
        id: id,
        petId: petId ?? this.petId,
        category: category ?? this.category,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        notes: notes ?? this.notes,
        imagePaths: imagePaths ?? this.imagePaths,
        relatedRecordId: relatedRecordId ?? this.relatedRecordId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'category': category.name,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
        'imagePaths': imagePaths,
        'relatedRecordId': relatedRecordId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        petId: json['petId'] as String?,
        category: ExpenseCategory.fromName(json['category'] as String?),
        title: json['title'] as String? ?? '',
        amount: json['amount'] as int? ?? 0,
        date: DateTime.parse(json['date'] as String),
        notes: json['notes'] as String?,
        imagePaths: (json['imagePaths'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        relatedRecordId: json['relatedRecordId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
      );
}
