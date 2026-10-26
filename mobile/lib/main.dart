import 'package:flutter/material.dart';
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
  await ApiService.loadCredentials();
  runApp(const AkremJobHunterApp());
}

class AkremJobHunterApp extends StatelessWidget {
  const AkremJobHunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'akremjobhunter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
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
    final screens = [
      DashboardScreen(onNavigateTab: (index) => setState(() => _currentIndex = index)),
      const ReviewScreen(),
      const ApplicationsScreen(),
      const CvVaultScreen(),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.touch_app_outlined),
            activeIcon: Icon(Icons.touch_app_rounded),
            label: 'Review',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_toggle_off_rounded),
            label: 'Memory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_copy_outlined),
            activeIcon: Icon(Icons.folder_copy_rounded),
            label: 'CV Vault',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            activeIcon: Icon(Icons.analytics_rounded),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_rounded),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
