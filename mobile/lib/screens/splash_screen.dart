import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _timer;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
    _startTransitionTimer();
  }

  void _startTransitionTimer() {
    _timer = Timer(const Duration(milliseconds: 2400), () async {
      if (!mounted) return;

      bool canAutoLogin = false;
      if (ApiService.isAuthenticated) {
        canAutoLogin = await ApiService.testConnection();
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => canAutoLogin
              ? const MainShell()
              : const AuthScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Official Hooded Character Branding Asset
          Image.asset(
            'assets/branding/hooded_hunter.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppTheme.bgDark),
          ),

          // 2. 70% Dark Overlay & Subtle Cyber Vignette
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.bgDark.withValues(alpha: 0.65),
                  AppTheme.bgDark.withValues(alpha: 0.85),
                  AppTheme.bgDark.withValues(alpha: 0.96),
                ],
              ),
            ),
          ),

          // 3. Central Brand Identity with Smooth Fade & Scale Animation
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing Emblem Border
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surface.withValues(alpha: 0.7),
                          border: Border.all(color: AppTheme.primary, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.45),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/branding/app_badge.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.radar_rounded,
                              size: 42,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Application Title
                      const Text(
                        'VisaJob AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        'Your Global AI Employment & Immigration Agent',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Author Attribution
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'by Akrem Hidouri',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Subtle Loading Indicator
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
