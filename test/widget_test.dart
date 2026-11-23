import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyfind/features/auth/presentation/screens/auth_screen.dart';
import 'package:polyfind/features/auth/presentation/screens/register_screen.dart';
import 'package:polyfind/features/items/presentation/screens/post_item_screen.dart';

void main() {
  testWidgets('login screen offers student registration', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('School Email'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create student account'), findsOneWidget);
  });

  testWidgets('registration form collects admission and school email',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admission Number'), findsOneWidget);
    expect(find.text('School Email'), findsOneWidget);
    expect(find.text('Create Password'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('post item screen offers camera and gallery photo sources',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PostItemScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a photo (optional)'));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
  });
}
