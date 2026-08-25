import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 空间加密：信封加密。
/// - dataKey（32 字节随机）加密数据（AES-256-GCM）
/// - 密码/恢复码经 PBKDF2 派生 KEK 包裹 dataKey，改密码无需重加密数据
class SpaceCrypto {
  SpaceCrypto._();

  static const int pbkdf2Iterations = 210000;
  static final AesGcm _aes = AesGcm.with256bits();
  static final Pbkdf2 _kdf =
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: pbkdf2Iterations, bits: 256);
  static final Random _random = Random.secure();

  // ---------- 空间暗号 ----------

  /// 生成空间暗号：CJ-XXXX-XXXX-XXXX（16 位 Base32，约 80 bit，不可枚举）。
  static String generateCode() {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // 去掉易混淆字符
    final chars =
        List.generate(16, (_) => alphabet[_random.nextInt(alphabet.length)]);
    final raw = chars.join();
    return 'CJ-${raw.substring(0, 4)}-${raw.substring(4, 8)}-'
        '${raw.substring(8, 12)}-${raw.substring(12, 16)}';
  }

  /// 生成恢复码：12 位，与暗号格式区分。
  static String generateRecoveryCode() {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final chars =
        List.generate(12, (_) => alphabet[_random.nextInt(alphabet.length)]);
    final raw = chars.join();
    return 'RC-${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8, 12)}';
  }

  // ---------- 密钥 ----------

  static Future<SecretKey> randomDataKey() async =>
      SecretKey(_randomBytes(32));

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

  static Future<String> encodeKey(SecretKey key) async =>
      base64Encode(await key.extractBytes());

  static SecretKey decodeKey(String b64) => SecretKey(base64Decode(b64));

  // ---------- 包裹 / 解包 dataKey ----------

  /// 用口令（密码或恢复码）包裹 dataKey。
  /// ct = 密文 + 16 字节 GCM 认证标签（与 encryptJson 同约定）。
  static Future<Map<String, String>> wrapKey(
      SecretKey dataKey, String passphrase) async {
    final salt = _randomBytes(16);
    final kek = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final box = await _aes.encrypt(
      await dataKey.extractBytes(),
      secretKey: kek,
    );
    return {
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'ct': base64Encode([...box.cipherText, ...box.mac.bytes]),
    };
  }

  /// 用口令解出 dataKey；失败抛 SpaceAuthException（口令错误）。
  static Future<SecretKey> unwrapKey(
      Map<String, dynamic> wrapped, String passphrase) async {
    try {
      final kek = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)),
        nonce: base64Decode(wrapped['salt'] as String),
      );
      final raw = base64Decode(wrapped['ct'] as String);
      if (raw.length < 16) throw const FormatException();
      final dataKey = await _aes.decrypt(
        SecretBox(
          raw.sublist(0, raw.length - 16),
          nonce: base64Decode(wrapped['nonce'] as String),
          mac: Mac(raw.sublist(raw.length - 16)),
        ),
        secretKey: kek,
      );
      return SecretKey(dataKey);
    } on SecretBoxAuthenticationError {
      throw SpaceAuthException('密码或恢复码不正确');
    } on FormatException {
      throw SpaceAuthException('密钥数据格式不正确');
    } catch (e) {
      throw SpaceAuthException('密钥解包失败：$e');
    }
  }

  // ---------- 数据加解密 ----------

  /// 加密任意 JSON → 密文 bytes（自带 12 字节随机 nonce）。
  static Future<Uint8List> encryptJson(
      SecretKey dataKey, Map<String, dynamic> json) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(json)),
      secretKey: dataKey,
    );
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// 解密 encryptJson 的产物。
  static Future<Map<String, dynamic>> decryptJson(
      SecretKey dataKey, List<int> bytes) async {
    if (bytes.length < 12 + 16) {
      throw SpaceAuthException('密文格式不正确');
    }
    final nonce = bytes.sublist(0, 12);
    final mac = bytes.sublist(bytes.length - 16);
    final cipher = bytes.sublist(12, bytes.length - 16);
    try {
      final plain = await _aes.decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: dataKey,
      );
      return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    } on SecretBoxAuthenticationError {
      throw SpaceAuthException('解密失败：密钥不匹配或数据损坏');
    }
  }

  /// 加密二进制（图片）。
  static Future<Uint8List> encryptBytes(SecretKey key, List<int> bytes) async {
    final box = await _aes.encrypt(bytes, secretKey: key);
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> decryptBytes(SecretKey key, List<int> bytes) async {
    if (bytes.length < 12 + 16) throw SpaceAuthException('密文格式不正确');
    final nonce = bytes.sublist(0, 12);
    final mac = bytes.sublist(bytes.length - 16);
    final cipher = bytes.sublist(12, bytes.length - 16);
    final plain =
        await _aes.decrypt(SecretBox(cipher, nonce: nonce, mac: Mac(mac)), secretKey: key);
    return Uint8List.fromList(plain);
  }
}

/// 空间认证/解密异常。
class SpaceAuthException implements Exception {
  SpaceAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
