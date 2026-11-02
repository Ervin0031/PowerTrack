/// 注册请求数据实体。
///
/// 由 `freezed` + `json_serializable` 代码生成（`register_model.freezed.dart` / `register_model.g.dart`），
/// 字段与后端 `UserCreate` Schema 对应（backend/app/schemas/user.py）。
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'register_model.freezed.dart';
part 'register_model.g.dart';

/// 注册表单数据。
@freezed
abstract class RegisterModel with _$RegisterModel {
  const factory RegisterModel({required String email, required String username, required String password}) =
      _RegisterModel;

  factory RegisterModel.fromJson(Map<String, dynamic> json) => _$RegisterModelFromJson(json);
}
