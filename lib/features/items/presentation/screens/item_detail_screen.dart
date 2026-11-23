import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:polyfind/core/constants/app_constants.dart';
import 'package:polyfind/data/models/claim_model.dart';
import 'package:polyfind/data/models/item_model.dart';
import 'package:polyfind/data/repositories/claim_repository.dart';
import 'package:polyfind/data/repositories/item_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _items = ItemRepository();
  final _claims = ClaimRepository();
  bool _isSubmitting = false;
  late final Stream<ItemModel?> _itemStream;
  String? _currentUserId;
  Stream<ClaimModel?>? _myClaimStream;

  @override
  void initState() {
    super.initState();
    _itemStream = _items.watchItem(widget.itemId);
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (_currentUserId != null) {
      _myClaimStream = _claims.watchMyClaim(widget.itemId, _currentUserId!);
    }
  }

  Future<void> _submitClaim(ItemModel item) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showMessage('Please sign in again to submit a claim.');
      return;
    }

    final answerController = TextEditingController();
    final answer = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim this item'),
        content: TextField(
          controller: answerController,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'How can you verify this is yours?',
            hintText: 'Describe a detail not shown in the post',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (answerController.text.trim().isNotEmpty) {
                Navigator.pop(context, answerController.text.trim());
              }
            },
            child: const Text('Submit claim'),
          ),
        ],
      ),
    );
    answerController.dispose();
    if (answer == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await _claims.createClaim(
        itemId: item.id,
        claimantId: user.id,
        verificationAnswer: answer,
      );
      if (mounted) _showMessage('Your claim was sent to the item owner.');
    } catch (error, stackTrace) {
      debugPrint('ItemDetailScreen: Could not submit claim: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _markReturned(ItemModel item) async {
    try {
      await _items.markItemReturned(item.id);
      if (mounted) _showMessage('Item marked as returned.');
    } catch (error, stackTrace) {
      debugPrint('ItemDetailScreen: Could not mark item returned: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showMessage('Could not update item status. $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: StreamBuilder<ItemModel?>(
        stream: _itemStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Could not load item: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = snapshot.data;
          if (item == null) {
            return const Center(
                child: Text('This item is no longer available.'));
          }

          final currentUser = Supabase.instance.client.auth.currentUser;
          final isOwner = currentUser?.id == item.postedBy;
          final isOpen = item.status == AppConstants.itemStatusOpen;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (item.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    height: 260,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      height: 160,
                      alignment: Alignment.center,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Chip(
                    label: Text(item.type.toUpperCase()),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Chip(label: Text(item.status.toUpperCase())),
                ],
              ),
              Text(item.title,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(item.category,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 20),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: item.location,
              ),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: item.isLost ? 'Date lost' : 'Date found',
                value: MaterialLocalizations.of(context)
                    .formatMediumDate(item.date),
              ),
              if (item.heldAt?.isNotEmpty == true)
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: 'Held at',
                  value: item.heldAt!,
                ),
              const SizedBox(height: 16),
              Text('Description',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(item.description),
              const SizedBox(height: 28),
              if (isOwner && item.status == AppConstants.itemStatusClaimed)
                FilledButton.icon(
                  onPressed: () => _markReturned(item),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as returned'),
                )
              else if (isOwner)
                OutlinedButton.icon(
                  onPressed: () => context.push(AppConstants.routeClaims),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Review claims'),
                )
              else if (isOpen && _currentUserId != null)
                StreamBuilder<ClaimModel?>(
                  stream: _myClaimStream,
                  builder: (context, claimSnapshot) {
                    final claim = claimSnapshot.data;
                    if (claimSnapshot.hasError) {
                      return Text(
                        'Could not check claim status: ${claimSnapshot.error}',
                      );
                    }
                    if (claim != null) {
                      return Chip(
                        label: Text('Claim ${claim.status}'),
                        avatar: const Icon(Icons.assignment_turned_in_outlined),
                      );
                    }
                    return FilledButton.icon(
                      onPressed:
                          _isSubmitting ? null : () => _submitClaim(item),
                      icon: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.assignment_outlined),
                      label: Text(
                          _isSubmitting ? 'Sending...' : 'Claim this item'),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
