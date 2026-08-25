import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

/// TOS（火山引擎对象存储）S3 兼容客户端。
/// - 查看者：公共读桶，匿名 GET 即可，无需任何凭证
/// - 编辑/管理：AWS SigV4 签名的 PUT / HEAD
/// endpoint 形如 `tos-s3-cn-beijing.volces.com`（区域从中推导）。
class TosClient {
  TosClient({
    required this.endpoint,
    required this.bucket,
    this.accessKey = '',
    this.secretKey = '',
  });

  final String endpoint;
  final String bucket;
  final String accessKey;
  final String secretKey;

  Uri _uri(String key, {bool virtualHost = true}) {
    final host = virtualHost ? '$bucket.$endpoint' : endpoint;
    final path = key.split('/').map(Uri.encodeComponent).join('/');
    return Uri.parse('https://$host/$path');
  }

  String get region {
    // tos-s3-cn-beijing.volces.com → cn-beijing
    final m = RegExp(r'tos-s3-([a-z0-9-]+)\.volces\.com').firstMatch(endpoint);
    return m?.group(1) ?? 'cn-beijing';
  }

  bool get hasCredentials => accessKey.isNotEmpty && secretKey.isNotEmpty;

  // ---------- 公共读（查看者） ----------

  /// 匿名 GET（桶需为公共读）。404 返回 null，网络错误抛异常。
  Future<Uint8List?> publicGet(String key) async {
    http.Response resp;
    try {
      resp = await http.get(_uri(key)).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw TosException('网络请求失败：$e');
    }
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw TosException('读取失败（${resp.statusCode}）');
    }
    return resp.bodyBytes;
  }

  // ---------- SigV4 签名请求（编辑/管理） ----------

  Future<Map<String, String>> _signedHeaders(
    String method,
    String key,
    Uint8List? body,
  ) async {
    final uri = _uri(key);
    final host = uri.host;
    final now = DateTime.now().toUtc();
    final amzDate = _fmtAmzDate(now);
    final dateStamp = amzDate.substring(0, 8);
    final payloadHash =
        body == null ? _sha256Empty : (await _sha256(body));

    final canonicalHeaders = 'host:$host\n'
        'x-amz-content-sha256:$payloadHash\n'
        'x-amz-date:$amzDate\n';
    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
    final canonicalRequest = '$method\n'
        '${uri.path.isEmpty ? '/' : uri.path}\n'
        '${uri.query.isEmpty ? '' : uri.query}\n'
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';

    final scope = '$dateStamp/$region/s3/aws4_request';
    final stringToSign = 'AWS4-HMAC-SHA256\n'
        '$amzDate\n'
        '$scope\n'
        '${await _sha256(Uint8List.fromList(utf8.encode(canonicalRequest)))}';

    final kDate = await _hmac(utf8.encode('AWS4$secretKey'), dateStamp);
    final kRegion = await _hmac(kDate, region);
    final kService = await _hmac(kRegion, 's3');
    final kSigning = await _hmac(kService, 'aws4_request');
    final signature =
        (await _hmac(kSigning, stringToSign)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return {
      'Host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Authorization':
          'AWS4-HMAC-SHA256 Credential=$accessKey/$scope, '
          'SignedHeaders=$signedHeaders, Signature=$signature',
    };
  }

  /// 签名 PUT。失败抛 TosException。
  Future<void> put(String key, Uint8List body) async {
    if (!hasCredentials) {
      throw TosException('当前是查看权限，未配置写入密钥');
    }
    final headers = await _signedHeaders('PUT', key, body);
    http.Response resp;
    try {
      resp = await http
          .put(_uri(key), headers: headers, body: body)
          .timeout(const Duration(seconds: 120));
    } catch (e) {
      throw TosException('上传失败：$e');
    }
    if (resp.statusCode != 200) {
      throw TosException('上传失败（${resp.statusCode}）');
    }
  }

  /// 签名 HEAD：对象是否存在。
  Future<bool> exists(String key) async {
    if (!hasCredentials) {
      throw TosException('当前是查看权限，未配置写入密钥');
    }
    final headers = await _signedHeaders('HEAD', key, null);
    http.Response resp;
    try {
      final req = http.Request('HEAD', _uri(key))..headers.addAll(headers);
      resp = await http.Response.fromStream(
          await http.Client().send(req).timeout(const Duration(seconds: 30)));
    } catch (_) {
      // HEAD 失败按不存在处理（下次推送会重传覆盖，幂等安全）。
      return false;
    }
    return resp.statusCode == 200;
  }

  // ---------- SigV4 工具 ----------

  static String _fmtAmzDate(DateTime utc) =>
      '${utc.year.toString().padLeft(4, '0')}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}T'
      '${utc.hour.toString().padLeft(2, '0')}${utc.minute.toString().padLeft(2, '0')}${utc.second.toString().padLeft(2, '0')}Z';

  static const _sha256Empty =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  static Future<String> _sha256(Uint8List data) async {
    final digest = await Sha256().hash(data);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<List<int>> _hmac(List<int> key, String message) async {
    final mac = await Hmac.sha256().calculateMac(
      utf8.encode(message),
      secretKey: SecretKey(key),
    );
    return mac.bytes;
  }
}

/// TOS 访问异常。
class TosException implements Exception {
  TosException(this.message);

  final String message;

  @override
  String toString() => message;
}
