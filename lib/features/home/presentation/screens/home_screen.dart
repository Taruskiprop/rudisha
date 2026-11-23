import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:polyfind/core/constants/app_constants.dart';
import 'package:polyfind/data/models/item_model.dart';
import 'package:polyfind/data/repositories/item_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _allCategories = '__all__';

  late TabController _tabController;
  late final ItemRepository _itemRepository;
  late final Stream<List<ItemModel>> _lostItemsStream;
  late final Stream<List<ItemModel>> _foundItemsStream;
  final _searchController = TextEditingController();
  int _selectedIndex = 0;
  String _searchQuery = '';
  String? _selectedCategory;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _itemRepository = ItemRepository();
    _lostItemsStream = _itemRepository.watchItems(AppConstants.itemTypeLost);
    _foundItemsStream = _itemRepository.watchItems(AppConstants.itemTypeFound);
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search items',
                  border: InputBorder.none,
                  filled: false,
                ),
                style: Theme.of(context).appBarTheme.titleTextStyle,
              )
            : const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            tooltip: _searchOpen ? 'Close search' : 'Search items',
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by category',
            onPressed: _showFilters,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lost Items'),
            Tab(text: 'Found Items'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildItemList(_lostItemsStream, AppConstants.itemTypeLost),
          _buildItemList(_foundItemsStream, AppConstants.itemTypeFound),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPostItem,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          switch (index) {
            case 0:
              context.go(AppConstants.routeHome);
              break;
            case 1:
              context.go(AppConstants.routeMyActivity);
              break;
            case 2:
              context.go(AppConstants.routeProfile);
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'My Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _openPostItem() async {
    final posted = await context.push<bool>(AppConstants.routePostItem);
    if (posted == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Your item was posted successfully.')),
        );
    }
  }

  Future<void> _showFilters() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Filter by category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              title: const Text('All categories'),
              trailing:
                  _selectedCategory == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, _allCategories),
            ),
            ...AppConstants.categories.map(
              (category) => ListTile(
                title: Text(category),
                trailing: _selectedCategory == category
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, category),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCategory = selected == _allCategories ? null : selected;
      });
    }
  }

  Widget _buildItemList(Stream<List<ItemModel>> stream, String type) {
    return StreamBuilder<List<ItemModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load items: ${snapshot.error}'),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = (snapshot.data ?? const <ItemModel>[]).where((item) {
          if (_selectedCategory != null && item.category != _selectedCategory) {
            return false;
          }
          if (_searchQuery.isEmpty) return true;
          return [
            item.title,
            item.description,
            item.location,
            item.category,
          ].any((value) => value.toLowerCase().contains(_searchQuery));
        }).toList(growable: false);
        if (items.isEmpty) {
          final hasFilters =
              _searchQuery.isNotEmpty || _selectedCategory != null;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == AppConstants.itemTypeLost
                      ? Icons.search_off
                      : Icons.inventory_2_outlined,
                  size: 80,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  hasFilters
                      ? 'No matching items'
                      : type == AppConstants.itemTypeLost
                          ? 'No lost items yet'
                          : 'No found items yet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasFilters
                      ? 'Try another search or category.'
                      : 'Post an item to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                onTap: () => context.pushNamed(
                  'itemDetail',
                  pathParameters: {'itemId': item.id},
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: item.imageUrl == null
                      ? null
                      : CachedNetworkImageProvider(item.imageUrl!),
                  child: item.imageUrl != null
                      ? null
                      : Icon(
                          item.isLost
                              ? Icons.search
                              : Icons.inventory_2_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),
                title: Text(item.title),
                subtitle: Text(
                  '${item.category} • ${item.location}\n${item.description}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: Text(
                  MaterialLocalizations.of(context).formatShortDate(item.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
