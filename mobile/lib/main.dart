import 'screens/ai_assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'screens/applications_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/cv_vault_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/review_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageController.instance.init();
  await ApiService.loadCredentials();
  runApp(const VisaJobApp());
}

class VisaJobApp extends StatelessWidget {
  const VisaJobApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        final currentLocale = LanguageController.instance.currentLocale;

        return MaterialApp(
          title: 'VisaJob AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          locale: currentLocale,
          supportedLocales: AppLanguage.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback? onDisconnect;
  const MainShell({super.key, this.onDisconnect});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final screens = [
      DashboardScreen(onNavigateTab: (index) => setState(() => _currentIndex = index)),
      const ReviewScreen(),
      const ApplicationsScreen(),
      const CvVaultScreen(),
      const AiAssistantScreen(),
      const InsightsScreen(),
      SettingsScreen(
        onDisconnect: widget.onDisconnect ??
            () async {
              await ApiService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard_rounded),
            label: l10n.t('nav_dashboard'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.touch_app_outlined),
            activeIcon: const Icon(Icons.touch_app_rounded),
            label: l10n.t('nav_review'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_rounded),
            activeIcon: const Icon(Icons.history_toggle_off_rounded),
            label: l10n.t('nav_memory'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder_copy_outlined),
            activeIcon: const Icon(Icons.folder_copy_rounded),
            label: l10n.t('nav_cv_vault'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.smart_toy_outlined),
            activeIcon: const Icon(Icons.smart_toy_rounded),
            label: l10n.t('nav_ai_assistant'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_rounded),
            activeIcon: const Icon(Icons.analytics_rounded),
            label: l10n.t('nav_insights'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.tune_rounded),
            activeIcon: const Icon(Icons.settings_rounded),
            label: l10n.t('nav_settings'),
          ),
        ],
      ),
    );
  }
}


typedef AkremJobHunterApp = VisaJobApp;
