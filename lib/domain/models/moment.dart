import 'enums.dart';

/// 时刻：生日 / 游玩 / 美容 / 纪念日等带照片的时间线节点。
class Moment {
  Moment({
    required this.id,
    required this.petId,
    required this.type,
    required this.date,
    required this.title,
    this.notes,
    this.location,
    this.imagePaths = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String petId;
  final MomentType type;
  final DateTime date;
  final String title;
  final String? notes;
  final String? location;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 云同步墓碑：非空 = 已删除（保留一段时间供其他设备同步删除语义）。
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Moment copyWith({
    MomentType? type,
    DateTime? date,
    String? title,
    String? notes,
    String? location,
    List<String>? imagePaths,
    DateTime? updatedAt,
  }) =>
      Moment(
        id: id,
        petId: petId,
        type: type ?? this.type,
        date: date ?? this.date,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        location: location ?? this.location,
        imagePaths: imagePaths ?? this.imagePaths,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'type': type.name,
        'date': date.toIso8601String(),
        'title': title,
        'notes': notes,
        'location': location,
        'imagePaths': imagePaths,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Moment.fromJson(Map<String, dynamic> json) => Moment(
        id: json['id'] as String,
        petId: json['petId'] as String,
        type: MomentType.fromName(json['type'] as String?),
        date: DateTime.parse(json['date'] as String),
        title: json['title'] as String? ?? '',
        notes: json['notes'] as String?,
        location: json['location'] as String?,
        imagePaths: (json['imagePaths'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
      );
}
