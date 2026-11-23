// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:polyfind/core/constants/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'item_model.freezed.dart';
part 'item_model.g.dart';

@freezed
class ItemModel with _$ItemModel {
  const factory ItemModel({
    required String id,
    required String type, // 'lost' or 'found'
    required String title,
    required String description,
    required String category,
    required String location,
    required DateTime date,
    @JsonKey(name: 'image_path') String? imagePath,
    required String status, // 'open', 'claimed', 'returned', 'archived'
    @JsonKey(name: 'posted_by') required String postedBy,
    @JsonKey(name: 'held_at') String? heldAt, // For found items
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _ItemModel;

  factory ItemModel.fromJson(Map<String, dynamic> json) =>
      _$ItemModelFromJson(json);
}

extension ItemModelX on ItemModel {
  String? get imageUrl => imagePath == null
      ? null
      : Supabase.instance.client.storage
          .from(AppConstants.itemPhotosBucket)
          .getPublicUrl(imagePath!);

  bool get isLost => type == 'lost';
  bool get isFound => type == 'found';
  bool get isOpen => status == 'open';
  bool get isClaimed => status == 'claimed';
  bool get isReturned => status == 'returned';
  bool get isArchived => status == 'archived';

  bool get canBeClaimed => isOpen;
  bool get canBeArchived => DateTime.now().difference(createdAt).inDays >= 60;
}
