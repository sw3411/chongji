/// 云空间绑定：本机一只宠物 ↔ TOS 上一个加密空间。
class CloudSpace {
  CloudSpace({
    required this.petId,
    required this.code,
    required this.endpoint,
    required this.bucket,
    required this.role,
    required this.memberName,
    this.accessKey = '',
    this.secretKey = '',
    this.lastVersion = 0,
    this.lastSyncAt,
    required this.createdAt,
  });

  final String petId;

  /// 空间暗号，同时是对象前缀：spaces/{code}/…
  final String code;

  /// S3 兼容 endpoint，如 tos-s3-cn-beijing.volces.com。
  final String endpoint;
  final String bucket;

  /// 我的角色：manage / edit / view。
  final String role;
  final String memberName;
  final String accessKey;
  final String secretKey;
  final int lastVersion;
  final DateTime? lastSyncAt;
  final DateTime createdAt;

  bool get canWrite => role == 'manage' || role == 'edit';
  bool get canManage => role == 'manage';
  bool get hasCredentials => accessKey.isNotEmpty && secretKey.isNotEmpty;

  String get roleLabel => switch (role) {
        'manage' => '管理',
        'edit' => '编辑',
        _ => '查看',
      };

  CloudSpace copyWith({
    String? role,
    String? memberName,
    String? accessKey,
    String? secretKey,
    int? lastVersion,
    DateTime? lastSyncAt,
  }) =>
      CloudSpace(
        petId: petId,
        code: code,
        endpoint: endpoint,
        bucket: bucket,
        role: role ?? this.role,
        memberName: memberName ?? this.memberName,
        accessKey: accessKey ?? this.accessKey,
        secretKey: secretKey ?? this.secretKey,
        lastVersion: lastVersion ?? this.lastVersion,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        createdAt: createdAt,
      );
}
