// lib/features/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_colors.dart';
import '../../core/startup/startup_resolver.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _navigateToNext();
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final destination = await StartupResolver.resolve();

    if (!mounted) return;

    // pushReplacementNamed carries the DriverProfile (or null) argument
    // straight into onGenerateRoute — no extra wiring needed.
    Navigator.pushReplacementNamed(
      context,
      destination.route,
      arguments: destination.arguments,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color midnightDark = Color(0xFF0B1019);
    const Color midnightLight = Color(0xFF161D29);

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light
            .copyWith(statusBarColor: Colors.transparent),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [midnightLight, midnightDark],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildCenterLogo(),
              _buildBottomIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterLogo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Hero(
              tag: 'app_logo',
              child: Image.asset(
                'assets/logos/logo.png',
                width: 160,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.local_taxi_rounded,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Text(
                AppStrings.appName.toUpperCase(),
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w200,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 1,
                color: AppColors.primaryColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomIndicator() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 40,
      child: Column(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Ghana's Choice for Logistics".toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: Colors.white24,
              letterSpacing: 1.5,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}
