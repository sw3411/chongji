import 'dart:io';

import 'package:exif/exif.dart';
import 'package:geocoding/geocoding.dart';

/// 照片 EXIF 信息：拍摄时间与 GPS 坐标。
class PhotoExif {
  const PhotoExif({this.takenAt, this.lat, this.lng});

  final DateTime? takenAt;
  final double? lat;
  final double? lng;

  bool get isEmpty => takenAt == null && lat == null;
}

/// EXIF 解析与逆地理编码。
class PhotoExifReader {
  PhotoExifReader._();

  /// 从图片文件读 EXIF（时间 + GPS）。失败/无信息返回空对象。
  static Future<PhotoExif> read(String path) async {
    try {
      final tags = await readExifFromBytes(await File(path).readAsBytes());
      DateTime? takenAt;
      // 主用 EXIF IFD 的 DateTimeOriginal；部分照片（截图/旧机型）只有
      // IFD0 的 Image DateTime，作为回退。
      final dateStr = tags['EXIF DateTimeOriginal']?.printable ??
          tags['EXIF DateTime']?.printable ??
          tags['Image DateTime']?.printable;
      if (dateStr != null) takenAt = parseExifDate(dateStr);

      double? lat;
      double? lng;
      final latTag = tags['GPS GPSLatitude']?.printable;
      final lngTag = tags['GPS GPSLongitude']?.printable;
      if (latTag != null && lngTag != null) {
        lat = parseGpsDms(latTag, tags['GPS GPSLatitudeRef']?.printable ?? 'N');
        lng = parseGpsDms(
            lngTag, tags['GPS GPSLongitudeRef']?.printable ?? 'E');
      }
      return PhotoExif(takenAt: takenAt, lat: lat, lng: lng);
    } catch (_) {
      return const PhotoExif();
    }
  }

  /// 'yyyy:MM:dd HH:mm:ss'（EXIF 标准格式）→ DateTime。
  static DateTime? parseExifDate(String printable) {
    final s = printable.trim();
    final m =
        RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(s);
    if (m == null) return DateTime.tryParse(s.replaceAll(':', '-'));
    return DateTime.tryParse(
        '${m.group(1)}-${m.group(2)}-${m.group(3)} ${m.group(4)}:${m.group(5)}:${m.group(6)}');
  }

  /// 解析 GPS 度分秒（EXIF 常见 "31/1, 14/1, 5268/100" 或十进制）→ 十进制度。
  /// [refPrintable] 含 'S'/'W' 取负。
  static double? parseGpsDms(String printable, String refPrintable) {
    final pairs = <double>[];
    for (final m in RegExp(r'(\d+(?:\.\d+)?)(?:\s*/\s*(\d+))?').allMatches(printable)) {
      final n = double.tryParse(m.group(1)!);
      if (n == null) continue;
      final d = m.group(2) == null ? 1.0 : double.tryParse(m.group(2)!);
      if (d == null || d == 0) continue;
      pairs.add(n / d);
    }
    double? value;
    if (pairs.length == 3) {
      value = pairs[0] + pairs[1] / 60 + pairs[2] / 3600;
    } else if (pairs.length == 1) {
      value = pairs[0];
    }
    if (value == null) return null;
    final ref = refPrintable.toUpperCase();
    if (ref.contains('S') || ref.contains('W')) value = -value;
    return value;
  }

  /// 逆地理编码：坐标 → 中文地名（如「青岛市 市南区」）。失败返回 null。
  static Future<String?> placeName(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final m = marks.first;
      final parts = [
        m.locality ?? m.administrativeArea ?? '',
        m.subLocality ?? m.name ?? '',
      ].where((s) => s.trim().isNotEmpty).toList();
      if (parts.isEmpty) return null;
      return parts.join(' ');
    } catch (_) {
      return null;
    }
  }
}
