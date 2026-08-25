import 'package:chongji/core/utils/photo_exif.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseExifDate', () {
    test('EXIF 标准格式 yyyy:MM:dd HH:mm:ss', () {
      final d = PhotoExifReader.parseExifDate('2026:08:20 14:30:05');
      expect(d, DateTime(2026, 8, 20, 14, 30, 5));
    });

    test('带尾缀 / 异常返回 null 或尽力解析', () {
      expect(PhotoExifReader.parseExifDate(''), isNull);
      expect(PhotoExifReader.parseExifDate('垃圾数据'), isNull);
    });
  });

  group('parseGpsDms', () {
    test('度分秒（分数形式）北纬东经', () {
      // 31/1 + 14/60 + 52.68/3600 ≈ 31.2480
      final v = PhotoExifReader.parseGpsDms('[31/1, 14/1, 5268/100]', 'N');
      expect(v!, closeTo(31.2480, 0.001));
    });

    test('南纬取负', () {
      final v = PhotoExifReader.parseGpsDms('[10/1, 30/1, 0/1]', 'S');
      expect(v!, closeTo(-10.5, 0.0001));
    });

    test('西经取负（W）', () {
      final v = PhotoExifReader.parseGpsDms('120/1', 'W');
      expect(v, -120.0);
    });

    test('无法解析返回 null', () {
      expect(PhotoExifReader.parseGpsDms('abc', 'N'), isNull);
    });
  });
}
