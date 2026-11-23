// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'claim_model.freezed.dart';
part 'claim_model.g.dart';

@freezed
class ClaimModel with _$ClaimModel {
  const factory ClaimModel({
    required String id,
    @JsonKey(name: 'item_id') required String itemId,
    @JsonKey(name: 'claimant_id') required String claimantId,
    @JsonKey(name: 'verification_answer') required String verificationAnswer,
    required String status, // 'pending', 'approved', 'rejected'
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _ClaimModel;

  factory ClaimModel.fromJson(Map<String, dynamic> json) =>
      _$ClaimModelFromJson(json);
}

extension ClaimModelX on ClaimModel {
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
