import 'package:chongji/core/cloud/space_crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpaceCrypto', () {
    test('暗号与恢复码格式', () {
      final code = SpaceCrypto.generateCode();
      expect(code, matches(RegExp(r'^CJ-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$')));
      // 两次生成不重复。
      expect(code, isNot(SpaceCrypto.generateCode()));
      final recovery = SpaceCrypto.generateRecoveryCode();
      expect(recovery, startsWith('RC-'));
    });

    test('包裹与解包往返', () async {
      final dataKey = await SpaceCrypto.randomDataKey();
      final wrapped = await SpaceCrypto.wrapKey(dataKey, '我家豆豆2026');
      final unwrapped = await SpaceCrypto.unwrapKey(wrapped, '我家豆豆2026');
      expect(await unwrapped.extractBytes(),
          await dataKey.extractBytes());
    });

    test('错误密码抛 SpaceAuthException', () async {
      final dataKey = await SpaceCrypto.randomDataKey();
      final wrapped = await SpaceCrypto.wrapKey(dataKey, '正确密码');
      expect(() => SpaceCrypto.unwrapKey(wrapped, '错误密码'),
          throwsA(isA<SpaceAuthException>()));
    });

    test('JSON 加解密往返', () async {
      final dataKey = await SpaceCrypto.randomDataKey();
      final data = {
        'petName': '豆豆',
        'version': 3,
        'list': [1, 2, 3],
      };
      final enc = await SpaceCrypto.encryptJson(dataKey, data);
      final dec = await SpaceCrypto.decryptJson(dataKey, enc);
      expect(dec['petName'], '豆豆');
      expect(dec['version'], 3);
    });

    test('错误的 key 解不开 JSON', () async {
      final k1 = await SpaceCrypto.randomDataKey();
      final k2 = await SpaceCrypto.randomDataKey();
      final enc = await SpaceCrypto.encryptJson(k1, {'a': 1});
      expect(() => SpaceCrypto.decryptJson(k2, enc),
          throwsA(isA<SpaceAuthException>()));
    });

    test('二进制加解密往返（图片）', () async {
      final key = await SpaceCrypto.randomDataKey();
      final bytes =
          List<int>.generate(1024, (i) => i % 256);
      final enc = await SpaceCrypto.encryptBytes(key, bytes);
      final dec = await SpaceCrypto.decryptBytes(key, enc);
      expect(dec, bytes);
    });

    test('密钥 base64 存取往返（钥匙串）', () async {
      final key = await SpaceCrypto.randomDataKey();
      final b64 = await SpaceCrypto.encodeKey(key);
      final restored = SpaceCrypto.decodeKey(b64);
      expect(await restored.extractBytes(), await key.extractBytes());
    });
  });

  group('SecretKey', () {
    test('extractBytes 与 SecretKey 构造', () async {
      final key = SecretKey(List<int>.filled(32, 7));
      expect((await key.extractBytes()).length, 32);
    });
  });
}
