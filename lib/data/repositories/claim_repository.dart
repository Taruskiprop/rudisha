import 'package:polyfind/core/constants/app_constants.dart';
import 'package:polyfind/data/models/claim_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClaimRepository {
  ClaimRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<ClaimModel>> watchMyClaims(String userId) {
    return _client
        .from('claims')
        .stream(primaryKey: ['id'])
        .eq('claimant_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ClaimModel.fromJson).toList(growable: false));
  }

  Stream<List<ClaimModel>> watchClaimsForItem(String itemId) {
    return _client
        .from('claims')
        .stream(primaryKey: ['id'])
        .eq('item_id', itemId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ClaimModel.fromJson).toList(growable: false));
  }

  Stream<List<ClaimModel>> watchAllClaims() {
    return _client
        .from('claims')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ClaimModel.fromJson).toList(growable: false));
  }

  Stream<ClaimModel?> watchMyClaim(String itemId, String claimantId) {
    return _client
        .from('claims')
        .stream(primaryKey: ['id'])
        .eq('item_id', itemId)
        .map((rows) {
          final matches = rows.where((row) => row['claimant_id'] == claimantId);
          return matches.isEmpty ? null : ClaimModel.fromJson(matches.first);
        });
  }

  Future<void> createClaim({
    required String itemId,
    required String claimantId,
    required String verificationAnswer,
  }) async {
    final item = await _client
        .from('items')
        .select('status, posted_by')
        .eq('id', itemId)
        .maybeSingle();
    if (item == null || item['status'] != AppConstants.itemStatusOpen) {
      throw StateError('This item is no longer available to claim.');
    }
    if (item['posted_by'] == claimantId) {
      throw StateError('You cannot submit a claim on your own item.');
    }

    await _client.from('claims').insert({
      'item_id': itemId,
      'claimant_id': claimantId,
      'verification_answer': verificationAnswer.trim(),
    });
  }

  Future<void> reviewClaim({
    required ClaimModel claim,
    required bool approve,
  }) async {
    await _client.rpc(
      'review_claim',
      params: {
        'p_claim_id': claim.id,
        'p_approve': approve,
      },
    );
  }
}
