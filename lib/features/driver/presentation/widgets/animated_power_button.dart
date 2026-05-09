import 'package:flutter/material.dart';

class AnimatedPowerButton extends StatefulWidget {
  final bool isOnline;
  final bool isToggling;
  
  const AnimatedPowerButton({
    super.key,
    required this.isOnline,
    required this.isToggling,
  });
  
  @override
  State<AnimatedPowerButton> createState() => _AnimatedPowerButtonState();
}

class _AnimatedPowerButtonState extends State<AnimatedPowerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      // Default to 1200ms if constant is missing
      duration: const Duration(milliseconds: 1200),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _handleAnimationState();
  }

  // Update animation when status changes
  @override
  void didUpdateWidget(AnimatedPowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline != widget.isOnline) {
      _handleAnimationState();
    }
  }

  void _handleAnimationState() {
    if (widget.isOnline) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        // Only scale if online and not currently toggling
        final scale = (widget.isOnline && !widget.isToggling) 
            ? _pulseAnimation.value 
            : 1.0;
            
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: 70, // Slightly larger for easier tapping while driving
        height: 70,
        decoration: BoxDecoration(
          color: widget.isOnline 
              ? Colors.white.withOpacity(0.25) 
              : Colors.black.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.isOnline ? Colors.white : Colors.white54,
            width: 2.0,
          ),
          boxShadow: widget.isOnline ? [
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ] : [],
        ),
        child: widget.isToggling
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3.0,
                ),
              )
            :const Icon(
                Icons.power_settings_new,
                color: Colors.white,
                size: 32,
              ),
      ),
    );
  }
}