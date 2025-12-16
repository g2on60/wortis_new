// app_rating_manager.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class AppRatingManager {
  static const String _appOpenCountKey = 'app_open_count';
  static const String _hasRatedKey = 'has_rated_app';
  static const String _ratingPromptShownKey = 'rating_prompt_shown';
  static const String _lastPromptDateKey = 'last_prompt_date';
  
  // Seuils pour déclencher la demande de notation
  static const int _triggerCount = 100;
  static const int _laterCount = 50;
  
  // URLs des stores
  static const String _androidPackageName = 'cg.wortispay.wortispay'; // À remplacer par votre package name
  static const String _iosAppId = '123456789'; // À remplacer par votre App ID iOS

  /// Incrémente le compteur d'ouvertures et vérifie si il faut afficher la demande
  static Future<void> incrementAppOpenCount(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifier si l'utilisateur a déjà noté
      final hasRated = prefs.getBool(_hasRatedKey) ?? false;
      if (hasRated) {
        print('📱 [Rating] Utilisateur a déjà noté l\'app');
        return;
      }

      // Récupérer et incrémenter le compteur
      int currentCount = prefs.getInt(_appOpenCountKey) ?? 0;
      currentCount++;
      await prefs.setInt(_appOpenCountKey, currentCount);
      
      print('📱 [Rating] Ouverture n°$currentCount');

      // Vérifier si on doit afficher la demande
      if (currentCount == _triggerCount) {
        await _showRatingDialog(context);
      }
    } catch (e) {
      print('❌ [Rating] Erreur incrémentation compteur: $e');
    }
  }

  /// Affiche le dialogue de demande de notation
  static Future<void> _showRatingDialog(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Marquer que le prompt a été affiché
      await prefs.setBool(_ratingPromptShownKey, true);
      await prefs.setString(_lastPromptDateKey, DateTime.now().toIso8601String());
      
      if (!context.mounted) return;
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const AppRatingDialog(),
      );
    } catch (e) {
      print('❌ [Rating] Erreur affichage dialogue: $e');
    }
  }

  /// Gère l'action "Noter maintenant"
  static Future<void> rateApp(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasRatedKey, true);
      
      // Rediriger vers le store approprié
      if (Platform.isAndroid) {
        await _openPlayStore();
      } else if (Platform.isIOS) {
        await _openAppStore();
      }
      
      print('✅ [Rating] Redirection vers le store');
    } catch (e) {
      print('❌ [Rating] Erreur ouverture store: $e');
    }
  }

  /// Gère l'action "Plus tard"
  static Future<void> rateLater() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remettre le compteur à 25 pour déclencher dans 25 ouvertures
      await prefs.setInt(_appOpenCountKey, _laterCount);
      
      print('📱 [Rating] Report de la notation (compteur remis à $_laterCount)');
    } catch (e) {
      print('❌ [Rating] Erreur report notation: $e');
    }
  }

  /// Ouvre le Play Store
  static Future<void> _openPlayStore() async {
    final Uri playStoreUri = Uri.parse('market://details?id=$_androidPackageName');
    final Uri playStoreWebUri = Uri.parse('https://play.google.com/store/apps/details?id=$_androidPackageName');
    
    try {
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(playStoreWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ [Rating] Erreur ouverture Play Store: $e');
    }
  }

  /// Ouvre l'App Store
  static Future<void> _openAppStore() async {
    final Uri appStoreUri = Uri.parse('itms-apps://itunes.apple.com/app/id$_iosAppId?action=write-review');
    final Uri appStoreWebUri = Uri.parse('https://apps.apple.com/app/id$_iosAppId?action=write-review');
    
    try {
      if (await canLaunchUrl(appStoreUri)) {
        await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(appStoreWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ [Rating] Erreur ouverture App Store: $e');
    }
  }

  /// Méthodes utilitaires pour le debug
  static Future<int> getCurrentCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_appOpenCountKey) ?? 0;
  }

  static Future<bool> hasUserRated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasRatedKey) ?? false;
  }

  static Future<void> resetRatingData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appOpenCountKey);
    await prefs.remove(_hasRatedKey);
    await prefs.remove(_ratingPromptShownKey);
    await prefs.remove(_lastPromptDateKey);
    print('🔄 [Rating] Données de notation réinitialisées');
  }
}

class AppRatingDialog extends StatefulWidget {
  const AppRatingDialog({super.key});

  @override
  State<AppRatingDialog> createState() => _AppRatingDialogState();
}

class _AppRatingDialogState extends State<AppRatingDialog> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  int _selectedStars = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(40),
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icône d'application
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF006699),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center( // <-- Ajouté pour centrer l'image
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/wortisapp.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    
                    const SizedBox(height: 20),
                    
                    // Titre
                    const Text(
                      'Vous aimez Wortis ?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Description
                    const Text(
                      'Prenez un moment pour noter notre application. Votre avis nous aide à nous améliorer !',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Système d'étoiles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedStars = index + 1;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              _selectedStars > index ? Icons.star : Icons.star_border,
                              color: _selectedStars > index 
                                  ? const Color.fromARGB(255, 0, 102, 153)
                                  : const Color(0xFFCCCCCC),
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Boutons d'action
                    Row(
                      children: [
                        // Bouton "Plus tard"
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              await AppRatingManager.rateLater();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Plus tard',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF666666),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Bouton "Noter"
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _selectedStars > 0 ? () async {
                              await AppRatingManager.rateApp(context);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 0, 102, 153),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Noter',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}