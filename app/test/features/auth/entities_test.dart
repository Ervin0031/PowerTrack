import 'package:app_flutter/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证领域实体能正确解析后端 JSON（snake_case + 可空字段 + 时间字段）。
void main() {
  group('AuthToken.fromJson', () {
    test('解析完整登录响应', () {
      final token = AuthToken.fromJson(const {
        'access_token': 'access-123',
        'refresh_token': 'refresh-456',
        'token_type': 'bearer',
      });
      expect(token.accessToken, 'access-123');
      expect(token.refreshToken, 'refresh-456');
      expect(token.tokenType, 'bearer');
    });

    test('refresh_token 与 token_type 缺省时兜底', () {
      final token = AuthToken.fromJson(const {'access_token': 'access-123'});
      expect(token.refreshToken, isNull);
      expect(token.tokenType, 'bearer');
    });
  });

  group('UserProfile.fromJson', () {
    test('解析完整用户信息', () {
      final user = UserProfile.fromJson(const {
        'id': 1,
        'username': 'johndoe',
        'email': 'john@example.com',
        'is_active': true,
        'is_verified': true,
        'is_superuser': false,
        'created_at': '2019-08-24T14:15:22Z',
        'updated_at': '2019-08-24T14:15:22Z',
        'last_login_at': '2019-08-24T14:15:22Z',
      });
      expect(user.id, 1);
      expect(user.username, 'johndoe');
      expect(user.email, 'john@example.com');
      expect(user.isSuperuser, isFalse);
      expect(user.lastLoginAt, isNotNull);
    });

    test('last_login_at 为空时不抛错', () {
      final user = UserProfile.fromJson(const {
        'id': 2,
        'username': 'alice',
        'email': 'alice@example.com',
        'is_active': true,
        'is_verified': true,
        'is_superuser': false,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      });
      expect(user.lastLoginAt, isNull);
    });
  });
}
