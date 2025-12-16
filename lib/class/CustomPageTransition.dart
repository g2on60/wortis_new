// ignore_for_file: file_names

import 'package:flutter/material.dart';

class CustomPageTransition extends PageRouteBuilder {
  final Widget page;

  CustomPageTransition({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Animation de slide
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            // Animation d'échelle
            final scaleAnimation = Tween<double>(
              begin: 0.9,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            // Animation d'opacité pour le contenu
            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ));

            // Animation d'overlay
            final overlayAnimation = Tween<double>(
              begin: 0.0,
              end: 0.3,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ));

            return Stack(
              children: [
                // Overlay de fond
                FadeTransition(
                  opacity: overlayAnimation,
                  child: Container(
                    color: Colors.black,
                  ),
                ),
                // Contenu principal avec animations combinées
                SlideTransition(
                  position: slideAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
        );
}

class ServicePageTransition extends PageRouteBuilder {
  final Widget page;

  ServicePageTransition({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Animation de glissement depuis la droite
            final slideAnimation = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            // Animation d'échelle
            final scaleAnimation = Tween<double>(
              begin: 0.9,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            // Animation de fondu
            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ));

            // Animation de l'overlay de fond
            final overlayAnimation = Tween<double>(
              begin: 0.0,
              end: 0.2,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ));

            return Stack(
              children: [
                // Overlay de fond
                FadeTransition(
                  opacity: overlayAnimation,
                  child: Container(
                    color: Colors.black,
                  ),
                ),
                // Contenu principal avec animations combinées
                SlideTransition(
                  position: slideAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
        );
}

// ========== CLASSE LOADINGOVERLAY ==========
class LoadingOverlay extends StatefulWidget {
  final String? mainText;
  final String? subText;
  final bool isVisible;

  const LoadingOverlay({
    super.key,
    this.mainText = 'Chargement des données',
    this.subText = 'Initialisation du système...',
    this.isVisible = true,
  });

  @override
  _LoadingOverlayState createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  static const primaryColor = Color(0xFF006699);
  late AnimationController _progressController;
  late AnimationController _dotsController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _dotsController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedDot(int index) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        double animationValue = (_dotsController.value - (index * 0.15)) % 1.0;
        double opacity = 0.3;
        double scale = 0.8;

        if (animationValue >= 0 && animationValue <= 0.5) {
          opacity = 0.3 + (animationValue * 1.4);
          scale = 0.8 + (animationValue * 0.4);
        } else if (animationValue > 0.5 && animationValue <= 1.0) {
          opacity = 1.0 - ((animationValue - 0.5) * 1.4);
          scale = 1.2 - ((animationValue - 0.5) * 0.4);
        }

        opacity = opacity.clamp(0.3, 1.0);
        scale = scale.clamp(0.8, 1.2);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Container(
      color: Colors.white.withOpacity(0.95),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primaryColor.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône avec animation de pulsation
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: primaryColor
                          .withOpacity(0.08 + (_pulseController.value * 0.04)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.cloud_sync_outlined,
                      color: primaryColor,
                      size: 40,
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),

              // Points de chargement animés
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => _buildAnimatedDot(index)),
              ),
              const SizedBox(height: 32),

              // Texte principal
              Text(
                widget.mainText!,
                style: const TextStyle(
                  color: primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Sous-texte
              Text(
                widget.subText!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Barre de progression moderne
              Container(
                width: double.infinity,
                height: 3,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 3,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor:
                              (0.3 + (_progressController.value * 0.7)),
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
