import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyfind/data/services/notification_service.dart';
import 'package:polyfind/core/router/app_router.dart';
import 'package:polyfind/core/theme/app_theme.dart';
import 'package:polyfind/features/auth/data/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get _hasSupabaseConfiguration {
  final uri = Uri.tryParse(_supabaseUrl);
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      !uri.host.toLowerCase().contains('your_') &&
      !uri.host.toLowerCase().contains('example') &&
      _supabaseAnonKey.isNotEmpty &&
      !_supabaseAnonKey.toLowerCase().contains('your_') &&
      !_supabaseAnonKey.toLowerCase().contains('placeholder');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_hasSupabaseConfiguration) {
    throw StateError(
      'Replace the Supabase URL and anon/publishable key placeholders with '
      'the real values from Supabase Project Settings → API. See README.md.',
    );
  }
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );
  runApp(const ProviderScope(child: PolyFindApp()));
}

class PolyFindApp extends ConsumerWidget {
  const PolyFindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.listen(authStateChangesProvider, (_, next) {
      final userId = next.asData?.value?.uid;
      if (next.hasValue) {
        unawaited(NotificationService.instance.setUser(userId, router));
      }
    });

    return MaterialApp.router(
      title: 'PolyFind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: NotificationService.scaffoldMessengerKey,
      routerConfig: router,
    );
  }
}
