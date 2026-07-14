// lib/features/driver/presentation/driver_welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../features/driver/models/driver_types.dart';
import '../../../../app/app_routes.dart';

/// A brief, premium "Welcome aboard" moment shown right after a driver is
/// approved and taps "Start Driving". Animates in over ~1.2s, then reveals a
/// "Let's go" button that takes the driver into the shell.
class DriverWelcomeScreen extends StatefulWidget {
  final String? driverName;
  final DriverProfile profile; // ← add this
  const DriverWelcomeScreen({super.key, this.driverName, required this.profile});

  @override
  State<DriverWelcomeScreen> createState() => _DriverWelcomeScreenState();
}

class _DriverWelcomeScreenState extends State<DriverWelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _badgeScale;
  late final Animation<double> _fadeIn;
  late final Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Badge pops in with an elastic feel.
    _badgeScale = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
    );

    // Text fades + rises.
    _fadeIn = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
    );

    // Button fades in last.
    _buttonFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );

    _entrance.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _enterShell() {
  HapticFeedback.lightImpact();
  Navigator.pushNamedAndRemoveUntil(
    context,
    AppRoutes.driverShell,
    (_) => false,
    arguments: widget.profile, // ← pass it here
  );
}

  @override
  Widget build(BuildContext context) {
    final name = (widget.driverName ?? '').trim();
    final firstName = name.isNotEmpty ? name.split(' ').first : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00A86B),
              Color(0xFF00C97E),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),

                // ── Animated verified badge ──
                ScaleTransition(
                  scale: _badgeScale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF00A86B),
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Welcome text ──
                FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(_fadeIn),
                    child: Column(
                      children: [
                        Text(
                          firstName != null
                              ? 'Welcome aboard,\n$firstName! 🎉'
                              : 'Welcome aboard! 🎉',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Your account is verified.\nYou\'re all set to start earning.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 4),

                // ── "Let's go" button (fades in last) ──
                FadeTransition(
                  opacity: _buttonFade,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _enterShell,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF00A86B),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Let's go",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00A86B),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded,
                              color: Color(0xFF00A86B), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}