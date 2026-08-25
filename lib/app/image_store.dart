import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/photo_exif.dart';

/// 图片存取：统一压缩并复制到 App 私有目录。
class ImageStore {
  ImageStore._();

  static const _uuid = Uuid();

  /// 图片目录（备份恢复落盘用）。
  static Future<Directory> imageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'images'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> _imageDir() => imageDir();

  /// 从相册选图（可多选），返回保存后的本地路径列表。
  static Future<List<String>> pickFromGallery({int maxCount = 9}) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    final result = <String>[];
    for (final f in files.take(maxCount)) {
      final saved = await _save(f);
      if (saved != null) result.add(saved);
    }
    return result;
  }

  /// 从相册选原图（不压缩，保留 EXIF），读出拍摄时间/GPS 后原样存入图片目录。
  /// 用于时刻表单的"按照片自动填日期/位置"。
  static Future<List<(String, PhotoExif)>> pickFromGalleryWithExif(
      {int maxCount = 9}) async {
    final picker = ImagePicker();
    // 不传 imageQuality/maxWidth：一旦走插件重编码，EXIF（含 GPS）会被剥掉。
    final files = await picker.pickMultiImage();
    final result = <(String, PhotoExif)>[];
    for (final f in files.take(maxCount)) {
      final exif = await PhotoExifReader.read(f.path);
      final saved = await _save(f);
      if (saved != null) result.add((saved, exif));
    }
    return result;
  }

  /// 拍照。
  static Future<String?> pickFromCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return null;
    return _save(file);
  }

  static Future<String?> _save(XFile file) async {
    try {
      final dir = await _imageDir();
      final ext =
          p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
      final name = '${_uuid.v4()}$ext';
      final target = p.join(dir.path, name);
      await File(file.path).copy(target);
      return target;
    } catch (_) {
      return null;
    }
  }

  static bool exists(String? path) {
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  static Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static Future<int> storageUsage() async {
    try {
      final dir = await _imageDir();
      int total = 0;
      await for (final e in dir.list()) {
        if (e is File) total += await e.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// 清理无引用图片，返回清理数量。
  static Future<int> cleanUnreferenced(Set<String> referenced) async {
    int count = 0;
    try {
      final dir = await _imageDir();
      await for (final e in dir.list()) {
        if (e is File && !referenced.contains(e.path)) {
          await e.delete();
          count++;
        }
      }
    } catch (_) {}
    return count;
  }
}

/// 宠物头像/照片展示：文件缺失回退到图标占位。
class PetAvatar extends StatelessWidget {
  const PetAvatar({
    super.key,
    this.path,
    this.speciesIcon = Icons.pets,
    this.size = 56,
    this.padding = 0,
  });

  final String? path;

  /// 宠物缺失头像时按物种显示猫/狗图标。
  final IconData speciesIcon;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (ImageStore.exists(path)) {
      final cacheWidth =
          (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(64, 640);
      return ClipOval(
        child: Image.file(
          File(path!),
          width: size,
          height: size,
          cacheWidth: cacheWidth,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(cs),
        ),
      );
    }
    return _fallback(cs);
  }

  Widget _fallback(ColorScheme cs) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(speciesIcon,
            size: size * 0.45, color: cs.outline),
      );
}

/// 方角照片（时间线九宫格用）。
class LocalImage extends StatelessWidget {
  const LocalImage(
    this.path, {
    super.key,
    this.size,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
  });

  final String? path;
  final double? size;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    if (ImageStore.exists(path)) {
      final cacheWidth = size == null
          ? null
          : (size! * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(64, 1440);
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(path!),
          width: size,
          height: size,
          cacheWidth: cacheWidth,
          fit: fit,
          errorBuilder: (_, __, ___) => _fallback(cs),
        ),
      );
    }
    return _fallback(cs);
  }

  Widget _fallback(ColorScheme cs) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(Icons.image_outlined,
            size: size == null ? 24 : size! * 0.3, color: cs.outline),
      );
}
