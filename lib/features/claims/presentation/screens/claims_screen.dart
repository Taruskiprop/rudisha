import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:polyfind/data/models/claim_model.dart';
import 'package:polyfind/data/models/item_model.dart';
import 'package:polyfind/data/models/user_model.dart';
import 'package:polyfind/data/repositories/claim_repository.dart';
import 'package:polyfind/data/repositories/item_repository.dart';
import 'package:polyfind/features/auth/data/auth_providers.dart';
import 'package:polyfind/features/items/presentation/widgets/item_title.dart';

class ClaimsScreen extends ConsumerWidget {
  const ClaimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateChangesProvider);
    final user = userState.asData?.value;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Claims'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Claims'),
              Tab(text: 'Received'),
            ],
          ),
        ),
        body: userId == null || user == null
            ? userState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : const Center(child: Text('Sign in to view claims.'))
            : TabBarView(
                children: [
                  _ClaimStreamList(
                    stream: ClaimRepository().watchMyClaims(userId),
                  ),
                  user.isAdmin
                      ? _ClaimStreamList(
                          stream: ClaimRepository().watchAllClaims(),
                          canReviewAll: true,
                        )
                      : _ReceivedClaims(userId: userId),
                ],
              ),
      ),
    );
  }
}

class _ReceivedClaims extends StatelessWidget {
  const _ReceivedClaims({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ItemModel>>(
      stream: ItemRepository().watchItemsByOwner(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessageState(
              message: 'Could not load your items: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <ItemModel>[];
        if (items.isEmpty) {
          return const _MessageState(
            message: 'Claims on your posted items will appear here.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in items) _ItemClaimsSection(item: item),
          ],
        );
      },
    );
  }
}

class _ItemClaimsSection extends StatefulWidget {
  const _ItemClaimsSection({
    required this.item,
  });

  final ItemModel item;

  @override
  State<_ItemClaimsSection> createState() => _ItemClaimsSectionState();
}

class _ItemClaimsSectionState extends State<_ItemClaimsSection> {
  late Stream<List<ClaimModel>> _claimsStream;

  @override
  void initState() {
    super.initState();
    _claimsStream = ClaimRepository().watchClaimsForItem(widget.item.id);
  }

  @override
  void didUpdateWidget(_ItemClaimsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _claimsStream = ClaimRepository().watchClaimsForItem(widget.item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClaimModel>>(
      stream: _claimsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            title: Text(widget.item.title),
            subtitle: Text('Could not load claims: ${snapshot.error}'),
          );
        }
        final claims = snapshot.data ?? const <ClaimModel>[];
        if (claims.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(widget.item.title,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final claim in claims)
              _ClaimCard(
                claim: claim,
                canReview: true,
                showAnswer: true,
              ),
          ],
        );
      },
    );
  }
}

class _ClaimStreamList extends StatelessWidget {
  const _ClaimStreamList({
    required this.stream,
    this.canReviewAll = false,
  });

  final Stream<List<ClaimModel>> stream;
  final bool canReviewAll;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClaimModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessageState(
              message: 'Could not load claims: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final claims = snapshot.data ?? const <ClaimModel>[];
        if (claims.isEmpty) {
          return const _MessageState(message: 'No claims yet.');
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final claim in claims)
              _ClaimCard(
                claim: claim,
                canReview: canReviewAll,
                showAnswer: true,
              ),
          ],
        );
      },
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({
    required this.claim,
    required this.canReview,
    required this.showAnswer,
  });

  final ClaimModel claim;
  final bool canReview;
  final bool showAnswer;

  Future<void> _review(
    BuildContext context, {
    required bool approve,
  }) async {
    try {
      await ClaimRepository().reviewClaim(
        claim: claim,
        approve: approve,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Claim approved.' : 'Claim declined.'),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('ClaimsScreen: Could not review claim: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update claim: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemTitle(
              itemId: claim.itemId,
              fallback: 'Item claim',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Status: ${claim.status}'),
            if (showAnswer) ...[
              const SizedBox(height: 8),
              Text(
                'Verification: ${claim.verificationAnswer}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (canReview && claim.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _review(context, approve: false),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _review(context, approve: true),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
