import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:polyfind/core/constants/app_constants.dart';
import 'package:polyfind/features/auth/data/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final controllerState = ref.watch(authControllerProvider);
    final currentUser =
        controllerState.asData?.value ?? authState.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (currentUser != null)
            IconButton(
              tooltip: 'Edit profile',
              onPressed: () => _editProfile(context, ref, currentUser.name),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: currentUser == null
          ? authState.when(
              data: (_) => const Center(child: Text('Not signed in')),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load profile: $e')),
            )
          : Builder(
              builder: (context) {
                final user = currentUser;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style:
                            const TextStyle(fontSize: 36, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        user.role.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.history),
                            title: const Text('My Activity'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push(AppConstants.routeMyActivity),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.assignment),
                            title: const Text('My Claims'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(AppConstants.routeClaims),
                          ),
                          if (user.role == 'admin') ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.admin_panel_settings),
                              title: const Text('Admin Panel'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  context.push(AppConstants.routeAdmin),
                            ),
                          ],
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.logout,
                                color: Theme.of(context).colorScheme.error),
                            title: Text(
                              'Sign Out',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                            onTap: () async {
                              try {
                                await ref
                                    .read(authControllerProvider.notifier)
                                    .signOut();
                                if (context.mounted) {
                                  context.go(AppConstants.routeAuth);
                                }
                              } catch (error, stackTrace) {
                                debugPrint(
                                    'ProfileScreen: Sign out failed: $error');
                                debugPrintStack(stackTrace: stackTrace);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Could not sign out: $error'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final nameController = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || !context.mounted) return;

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            name: name,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('ProfileScreen: Profile update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile: $error')),
        );
      }
    }
  }
}
