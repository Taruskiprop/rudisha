// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    @JsonKey(name: 'id') required String uid,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('')
    String email,
    required String name,
    required String role,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromProfile(
    Map<String, dynamic> data, {
    required String email,
  }) {
    return UserModel(
      uid: data['id'] as String,
      name: data['name'] as String,
      email: email,
      role: data['role'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}

extension UserModelX on UserModel {
  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';
  bool get isStudent => role == 'student';
}
