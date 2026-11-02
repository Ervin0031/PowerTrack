import 'package:app_flutter/shared/widgets/app_network_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presigned URL 剥离签名 query，得到稳定缓存键', () {
    expect(
      stableImageCacheKey(
        'http://localhost:9000/powertrack/templates/covers/a.jpg'
        '?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc123&X-Amz-Expires=3600',
      ),
      'http://localhost:9000/powertrack/templates/covers/a.jpg',
    );
  });

  test('稳定端点 URL（含 ?v= 版本参数）原样保留', () {
    expect(
      stableImageCacheKey('http://localhost:8000/api/v1/exercises/1/thumb?v=k2'),
      'http://localhost:8000/api/v1/exercises/1/thumb?v=k2',
    );
  });
}
