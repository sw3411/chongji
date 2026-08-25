import 'enums.dart';

/// 宠物档案。
class Pet {
  Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.birthday,
    this.adoptionDate,
    this.gender = PetGender.unknown,
    this.neutered = false,
    this.avatarPath,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final PetSpecies species;
  final String? breed;

  /// 生日（年龄与生日纪念日的依据）。
  final DateTime? birthday;

  /// 到家日期（到家纪念日的依据，可与生日不同）。
  final DateTime? adoptionDate;
  final PetGender gender;
  final bool neutered;
  final String? avatarPath;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  String get speciesLabel => species.label;
  String get breedLabel => breed == null || breed!.trim().isEmpty ? '未填品种' : breed!;

  Pet copyWith({
    String? name,
    PetSpecies? species,
    String? breed,
    PetGender? gender,
    bool? neutered,
    DateTime? birthday,
    DateTime? adoptionDate,
    String? notes,
    DateTime? updatedAt,
  }) =>
      Pet(
        id: id,
        name: name ?? this.name,
        species: species ?? this.species,
        breed: breed ?? this.breed,
        gender: gender ?? this.gender,
        neutered: neutered ?? this.neutered,
        birthday: birthday ?? this.birthday,
        adoptionDate: adoptionDate ?? this.adoptionDate,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt,
      );

  /// 需要把字段清回 null 的场景（换头像/清日期/清备注）。
  Pet clearFields({
    bool avatar = false,
    bool birthday = false,
    bool adoptionDate = false,
    bool notes = false,
    DateTime? updatedAt,
  }) =>
      Pet(
        id: id,
        name: name,
        species: species,
        breed: breed,
        gender: gender,
        neutered: neutered,
        birthday: birthday ? null : this.birthday,
        adoptionDate: adoptionDate ? null : this.adoptionDate,
        avatarPath: avatar ? null : avatarPath,
        notes: notes ? null : this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'species': species.name,
        'breed': breed,
        'birthday': birthday?.toIso8601String(),
        'adoptionDate': adoptionDate?.toIso8601String(),
        'gender': gender.name,
        'neutered': neutered,
        'avatarPath': avatarPath,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        species: PetSpecies.fromName(json['species'] as String?),
        breed: json['breed'] as String?,
        birthday: json['birthday'] == null
            ? null
            : DateTime.parse(json['birthday'] as String),
        adoptionDate: json['adoptionDate'] == null
            ? null
            : DateTime.parse(json['adoptionDate'] as String),
        gender: PetGender.fromName(json['gender'] as String?),
        neutered: json['neutered'] as bool? ?? false,
        avatarPath: json['avatarPath'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
      );
}
