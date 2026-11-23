import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:polyfind/data/models/claim_model.dart';
import 'package:polyfind/data/models/item_model.dart';
import 'package:polyfind/data/repositories/claim_repository.dart';
import 'package:polyfind/data/repositories/item_repository.dart';
import 'package:polyfind/features/items/presentation/widgets/item_title.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyActivityScreen extends StatelessWidget {
  const MyActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Activity'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Posts'),
              Tab(text: 'My Claims'),
            ],
          ),
        ),
        body: userId == null
            ? const Center(child: Text('Sign in to view your activity.'))
            : TabBarView(
                children: [
                  _ItemsActivity(userId: userId),
                  _ClaimsActivity(userId: userId),
                ],
              ),
      ),
    );
  }
}

class _ItemsActivity extends StatelessWidget {
  const _ItemsActivity({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ItemModel>>(
      stream: ItemRepository().watchItemsByOwner(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ActivityMessage(
              message: 'Could not load posts: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <ItemModel>[];
        if (items.isEmpty) {
          return const _ActivityMessage(
              message: 'Your posts will appear here.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                leading: item.imageUrl == null
                    ? const Icon(Icons.inventory_2_outlined)
                    : CircleAvatar(
                        backgroundImage:
                            CachedNetworkImageProvider(item.imageUrl!),
                      ),
                title: Text(item.title),
                subtitle:
                    Text('${item.type} • ${item.status} • ${item.location}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  'itemDetail',
                  pathParameters: {'itemId': item.id},
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ClaimsActivity extends StatelessWidget {
  const _ClaimsActivity({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClaimModel>>(
      stream: ClaimRepository().watchMyClaims(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ActivityMessage(
              message: 'Could not load claims: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final claims = snapshot.data ?? const <ClaimModel>[];
        if (claims.isEmpty) {
          return const _ActivityMessage(
              message: 'Your claims will appear here.');
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final claim in claims)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: ItemTitle(
                    itemId: claim.itemId,
                    fallback: 'Item claim',
                  ),
                  subtitle: Text('Status: ${claim.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(
                    'itemDetail',
                    pathParameters: {'itemId': claim.itemId},
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActivityMessage extends StatelessWidget {
  const _ActivityMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
