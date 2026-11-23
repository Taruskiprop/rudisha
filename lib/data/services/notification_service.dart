import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:polyfind/core/constants/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  RealtimeChannel? _claimsChannel;
  String? _registeredUserId;
  GoRouter? _router;

  Future<void> setUser(String? userId, GoRouter router) async {
    _router = router;
    if (userId == _registeredUserId) return;

    final oldChannel = _claimsChannel;
    _claimsChannel = null;
    _registeredUserId = userId;
    if (oldChannel != null) {
      await Supabase.instance.client.removeChannel(oldChannel);
    }
    if (userId == null) return;

    _claimsChannel =
        Supabase.instance.client.channel('claims:$userId').onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'claims',
              callback: (payload) => _onClaimChange(payload, userId),
            )..subscribe((status, error) {
            if (error != null) {
              debugPrint('Supabase Realtime subscription failed: $error');
            } else {
              debugPrint('Supabase Realtime claims channel: $status');
            }
          });
  }

  void _onClaimChange(PostgresChangePayload payload, String userId) {
    final record = payload.newRecord;
    if (record.isEmpty) return;

    final claimantId = record['claimant_id'] as String?;
    final status = record['status'] as String?;
    String? message;
    if (payload.eventType == PostgresChangeEvent.insert &&
        claimantId != null &&
        claimantId != userId) {
      message = 'Someone submitted a claim on your item.';
    } else if (payload.eventType == PostgresChangeEvent.update &&
        claimantId == userId &&
        status != 'pending') {
      message = status == 'approved'
          ? 'Your item claim was approved.'
          : 'Your item claim was declined.';
    }
    if (message == null) return;

    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => _router?.go(AppConstants.routeClaims),
          ),
        ),
      );
  }
}
