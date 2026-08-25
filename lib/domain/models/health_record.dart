import 'enums.dart';

/// 健康记录：体重 / BCS / 疫苗 / 驱虫 / 就诊 / 用药 / 手术 / 症状等共用一张表，
/// 按类型取用字段（value=体重kg或BCS分；textValue=疫苗名/药名/医院名）。
class HealthRecord {
  HealthRecord({
    required this.id,
    required this.petId,
    required this.type,
    required this.date,
    this.value,
    this.textValue,
    this.diagnosis,
    this.cycleDays,
    this.notes,
    this.imagePaths = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String petId;
  final HealthRecordType type;
  final DateTime date;

  /// 体重（kg）或 BCS 分（1-9）。
  final double? value;

  /// 疫苗名称 / 驱虫药名 / 医院名等。
  final String? textValue;
  final String? diagnosis;

  /// 周期天数（疫苗/驱虫），用于推算下次到期。
  final int? cycleDays;
  final String? notes;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 云同步墓碑：非空 = 已删除（保留一段时间供其他设备同步删除语义）。
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  HealthRecord copyWith({
    HealthRecordType? type,
    DateTime? date,
    double? value,
    String? textValue,
    String? diagnosis,
    int? cycleDays,
    String? notes,
    List<String>? imagePaths,
    DateTime? updatedAt,
  }) =>
      HealthRecord(
        id: id,
        petId: petId,
        type: type ?? this.type,
        date: date ?? this.date,
        value: value ?? this.value,
        textValue: textValue ?? this.textValue,
        diagnosis: diagnosis ?? this.diagnosis,
        cycleDays: cycleDays ?? this.cycleDays,
        notes: notes ?? this.notes,
        imagePaths: imagePaths ?? this.imagePaths,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'petId': petId,
        'type': type.name,
        'date': date.toIso8601String(),
        'value': value,
        'textValue': textValue,
        'diagnosis': diagnosis,
        'cycleDays': cycleDays,
        'notes': notes,
        'imagePaths': imagePaths,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory HealthRecord.fromJson(Map<String, dynamic> json) => HealthRecord(
        id: json['id'] as String,
        petId: json['petId'] as String,
        type: HealthRecordType.fromName(json['type'] as String?),
        date: DateTime.parse(json['date'] as String),
        value: (json['value'] as num?)?.toDouble(),
        textValue: json['textValue'] as String?,
        diagnosis: json['diagnosis'] as String?,
        cycleDays: json['cycleDays'] as int?,
        notes: json['notes'] as String?,
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
