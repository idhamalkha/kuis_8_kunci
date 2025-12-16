/// Home Screen - Playful & Gamified Entry Point
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'player_join_screen.dart';
import 'admin_login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Responsive sizes
    final contentWidth = math.min(600.0, screenWidth * 0.92);
    final logoSize = math.min(160.0, screenWidth * 0.38);
    final titleFontSize = screenWidth < 360 ? 28.0 : (screenWidth < 520 ? 40.0 : 48.0);
    final verticalSpacerSmall = math.max(12.0, screenHeight * 0.02);
    final verticalSpacerLarge = math.max(24.0, screenHeight * 0.04);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple[600]!,
              Colors.blue[500]!,
              Colors.cyan[400]!,
            ],
          ),
        ),
          child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 16 : 24, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 500),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      horizontalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      // ========== ANIMATED LOGO ==========
                      Container(
                        width: logoSize,
                        height: logoSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.yellow[300]!, Colors.orange[400]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange[400]!.withValues(alpha: 0.7),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                          child: Center(
                          child: Text(
                            '🎯',
                            style: TextStyle(fontSize: math.max(48, logoSize * 0.55)),
                          )
                              .animate(onPlay: (controller) => controller.repeat())
                              .scaleXY(begin: 1.0, end: 1.08, duration: 1.5.seconds),
                        ),
                      ),
                      SizedBox(height: verticalSpacerLarge),

                      // ========== COLORFUL TITLE ==========
                      SizedBox(
                        height: math.max(56, titleFontSize * 1.6),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            ColorizeAnimatedText(
                              'KUIS 8 KUNCI',
                              textStyle: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                              colors: [
                                Colors.yellow[300]!,
                                Colors.orange[400]!,
                                Colors.pink[400]!,
                                Colors.purple[400]!,
                              ],
                            ),
                          ],
                          repeatForever: true,
                        ),
                      ),
                      SizedBox(height: verticalSpacerSmall),

                      // ========== SUBTITLE WITH BADGE ==========
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: math.max(16, screenWidth * 0.06),
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          '🌟 Belajar Sambil Bermain! 🎮',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      SizedBox(height: verticalSpacerLarge),

                      // ========== MENU BUTTONS ==========
                      SizedBox(
                        width: contentWidth,
                        child: _MenuButtonPlayful(
                        icon: Icons.play_circle_fill,
                        label: 'Mainkan Kuis',
                        subtitle: 'Mulai petualangan!',
                        gradient: LinearGradient(
                          colors: [Colors.green[600]!, Colors.teal[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PlayerJoinScreen(),
                            ),
                          );
                        },
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: contentWidth,
                        child: _MenuButtonPlayful(
                        icon: Icons.school,
                        label: 'Admin Panel',
                        subtitle: 'Kelola kuis',
                        gradient: LinearGradient(
                          colors: [Colors.indigo[600]!, Colors.blue[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminLoginScreen(),
                            ),
                          );
                        },
                        ),
                      ),

                      SizedBox(height: verticalSpacerLarge),

                      // ========== FOOTER BADGE ==========
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: math.max(12, screenWidth * 0.04),
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Text(
                              '✨ Platform Pembelajaran Menyenangkan ✨',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 1500.ms)
                              .shimmer(duration: 2500.ms, delay: 500.ms),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Playful Menu Button dengan Hover & Tap Effects
class _MenuButtonPlayful extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback onPressed;

  const _MenuButtonPlayful({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onPressed,
  });

  @override
  State<_MenuButtonPlayful> createState() => _MenuButtonPlayfulState();
}

class _MenuButtonPlayfulState extends State<_MenuButtonPlayful>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _elevationAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.colors.last.withValues(alpha: 0.5),
                  blurRadius: 20 + _elevationAnimation.value,
                  spreadRadius: 2,
                  offset: Offset(0, 8 + _elevationAnimation.value),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.white.withValues(alpha: 0.3),
                highlightColor: Colors.white.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                widget.icon,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.label,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 44),
                            child: Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 24,
                      ).animate()
                        .slideX(
                          begin: 0,
                          end: 0.3,
                          duration: 800.ms,
                        )
                        .then()
                        .slideX(begin: 0.3, end: 0, duration: 800.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
