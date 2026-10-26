import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:akremjobhunter/main.dart';
import 'package:akremjobhunter/l10n/app_localizations.dart';
import 'package:akremjobhunter/screens/about_screen.dart';
import 'package:akremjobhunter/screens/auth_screen.dart';
import 'package:akremjobhunter/screens/splash_screen.dart';
import 'package:akremjobhunter/widgets/language_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LanguageController.instance.init();
  });

  testWidgets('Full End-to-End App Flow Test', (WidgetTester tester) async {
    // 1. Launch App
    await tester.pumpWidget(const AkremJobHunterApp());
    expect(find.byType(AkremJobHunterApp), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);

    // 2. Allow splash transition timer to complete
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 3. Verify AuthScreen is displayed
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('akremjobhunter'), findsAtLeastNWidgets(1));

    // 4. Test Language Switching to Arabic (RTL)
    await LanguageController.instance.setLanguage('ar');
    await tester.pumpAndSettle();

    expect(LanguageController.instance.isRtl, isTrue);
    expect(find.text('تسجيل الدخول'), findsAtLeastNWidgets(1));
    expect(find.text('إنشاء حساب جديد'), findsAtLeastNWidgets(1));

    // 5. Switch to Create Account Tab in Arabic
    await tester.tap(find.text('إنشاء حساب جديد').first);
    await tester.pumpAndSettle();

    // 6. Test Password Strength Meter
    final passField = find.widgetWithText(TextField, 'اختر كلمة السر *');
    expect(passField, findsOneWidget);

    // Enter weak password
    await tester.enterText(passField, '123');
    await tester.pumpAndSettle();
    expect(find.text('ضعيفة'), findsOneWidget);

    // Enter strong password
    await tester.enterText(passField, 'SecureHunter@2026!');
    await tester.pumpAndSettle();
    expect(find.text('قوية جداً'), findsOneWidget);

    // 7. Test Language Switching to French
    await LanguageController.instance.setLanguage('fr');
    await tester.pumpAndSettle();

    expect(LanguageController.instance.isRtl, isFalse);
    expect(find.text('Se connecter'), findsAtLeastNWidgets(1));
    expect(find.text('Créer un compte'), findsAtLeastNWidgets(1));

    // 8. Test Language Switching to English
    await LanguageController.instance.setLanguage('en');
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsAtLeastNWidgets(1));
    expect(find.text('Create Account'), findsAtLeastNWidgets(1));

    // 9. Verify LanguageSelectorSheet displays options
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => LanguageSelectorSheet.show(ctx),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // 10. Verify AboutScreen renders cleanly
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('akremjobhunter'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });
}
