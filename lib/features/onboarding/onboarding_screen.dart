// features/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../app/app_routes.dart';
import '../../shared/widgets/buttons/primary_button.dart';
import 'onboarding_model.dart';
import '../../core/services/local/onboarding_local_service.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Setting system overlay for a seamless "Full Screen" look
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    // Haptic feedback provides a premium feel when swiping
    HapticFeedback.selectionClick();
  }

  void _nextPage() {
    if (_currentPage < onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut, // Custom smooth curve
      );
    } else {
      _finish();
    }
  }

Future<void> _finish() async {
  await OnboardingLocalService.markCompleted();

  if (!mounted) return;
  Navigator.of(context).pushReplacementNamed(AppRoutes.signup,
  arguments: {'fromOnboarding': true}
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          // 1. Background Content (Immersive)
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: onboardingPages.length,
            itemBuilder: (context, index) {
              return _OnboardingBody(model: onboardingPages[index]);
            },
          ),

          // 2. Top Header (Skip Action)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: AnimatedOpacity(
              opacity: _currentPage == onboardingPages.length - 1 ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  AppStrings.onboardingSkip,
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom persistent controls
          Positioned(
            bottom: 50,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Modernized Progress Indicator (Dashes > Dots)
                Row(
                  children: List.generate(
                    onboardingPages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      width: _currentPage == index ? 40 : 12,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _currentPage == index 
                            ? AppColors.primaryColor 
                            : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Primary Action
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: PrimaryButton(
                    label: _currentPage == onboardingPages.length - 1
                        ? AppStrings.onboardingGetStarted
                        : AppStrings.onboardingNext,
                    onPressed: _nextPage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBody extends StatelessWidget {
  final OnboardingModel model;

  const _OnboardingBody({required this.model});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image Layer with Gradient Overlay
        Positioned.fill(
          child: Image.asset(model.imagePath, fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 0.9],
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  AppColors.backgroundColor, // Fades into the UI color
                ],
              ),
            ),
          ),
        ),
        
        // Text Content Layer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.title,
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 40),
                child: Text(
                  model.subtitle,
                  style: AppTextStyles.subtitle.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 18,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 200), // Space for bottom controls
            ],
          ),
        ),
      ],
    );
  }
}