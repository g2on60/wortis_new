// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// NOUVELLES IMPORTS FIREBASE
// import 'package:firebase_core/firebase_core.dart';

import 'package:wortis/class/dataprovider.dart';
import 'package:wortis/class/permission_manager.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart';
import 'package:wortis/class/theme_provider.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:wortis/pages/homepage_dias.dart';
import 'package:wortis/pages/app_rating_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// ========== FONCTION POUR MONITORER ONESIGNAL EN CONTINU ==========
void _startOneSignalMonitoring() {
  // Vérifier l'état toutes les 3 secondes pendant 30 secondes
  int checks = 0;
  Timer.periodic(const Duration(seconds: 3), (timer) {
    checks++;

    final isOptedIn = OneSignal.User.pushSubscription.optedIn;
    final token = OneSignal.User.pushSubscription.token;
    final subscriptionId = OneSignal.User.pushSubscription.id;

    // Si pas abonné, forcer à nouveau
    if (isOptedIn != true || token == null || token.isEmpty) {
      OneSignal.User.pushSubscription.optIn();
    }

    // Arrêter après 10 vérifications (30 secondes)
    if (checks >= 10) {
      timer.cancel();

      final finalOptedIn = OneSignal.User.pushSubscription.optedIn;
      final finalToken = OneSignal.User.pushSubscription.token;
    }
  });
}

// ========== FONCTION POUR FORCER LA SOUSCRIPTION ONESIGNAL ==========
Future<bool> forceOneSignalSubscription() async {
  try {
    // Forcer l'opt-in
    OneSignal.User.pushSubscription.optIn();

    // Attendre que l'état soit mis à jour
    await Future.delayed(const Duration(milliseconds: 1000));

    // Vérifier l'état
    final isOptedIn = OneSignal.User.pushSubscription.optedIn;
    final subscriptionId = OneSignal.User.pushSubscription.id;
    final pushToken = OneSignal.User.pushSubscription.token;

    if (isOptedIn == true && subscriptionId != null) {
      // Sauvegarder le player ID
      await _savePlayerIdToBackend(subscriptionId);
      return true;
    }

    return false;
  } catch (e) {
    return false;
  }
}

// ========== FONCTION POUR SAUVEGARDER LE PLAYER ID ==========
Future<void> _savePlayerIdToBackend(String playerId) async {
  try {
    // Toujours stocker localement le Player ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onesignal_player_id', playerId);

    // Récupérer le token utilisateur (qui est aussi l'user_id)
    final userId = await SessionManager.getToken();
    if (userId == null || userId.isEmpty) {
      return;
    }

    // Envoyer le player_id au backend
    final response = await http.put(
      Uri.parse('https://api.live.wortis.cg/api/apk_update/player_id/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'player_id': playerId}),
    );

    if (response.statusCode == 200) {
    } else {}
  } catch (e) {}
}

// ========== FONCTION POUR ENVOYER LE PLAYER ID LOCAL AU BACKEND ==========
Future<void> sendLocalPlayerIdToBackend() async {
  try {
    // Récupérer le Player ID stocké localement
    final prefs = await SharedPreferences.getInstance();
    final playerId = prefs.getString('onesignal_player_id');

    if (playerId == null || playerId.isEmpty) {
      return;
    }

    // Récupérer le token utilisateur
    final userId = await SessionManager.getToken();
    if (userId == null || userId.isEmpty) {
      return;
    }

    // Envoyer le player_id au backend
    final response = await http.put(
      Uri.parse('https://api.live.wortis.cg/api/apk_update/player_id/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'player_id': playerId}),
    );

    if (response.statusCode == 200) {
    } else {}
  } catch (e) {}
}

// ========== FONCTION MAIN OPTIMISÉE AVEC FIREBASE ==========
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ========== INITIALISATION ONESIGNAL ==========
  try {
    // Configuration OneSignal - Un seul App ID pour iOS et Android
    String oneSignalAppId = "e3d84011-ed0b-4f57-ac5c-aad1b7ea10a3";

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    // Désactiver les In-App Messages (popup "Open Settings")
    OneSignal.InAppMessages.paused(true);

    OneSignal.initialize(oneSignalAppId);

    // Attendre que OneSignal s'initialise complètement
    await Future.delayed(const Duration(milliseconds: 500));

    // Demander la permission pour les notifications UNE SEULE FOIS
    final permissionGranted = await OneSignal.Notifications.requestPermission(
      true,
    );

    // Activer la souscription push
    if (permissionGranted) {
      OneSignal.User.pushSubscription.optIn();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    bool? isOptedIn = OneSignal.User.pushSubscription.optedIn;
    String? token = OneSignal.User.pushSubscription.token;

    // ✅ NOUVEAU: Si pas de token, tentative de réinitialisation
    if (token == null || token.isEmpty) {
      OneSignal.User.pushSubscription.optOut();
      await Future.delayed(const Duration(milliseconds: 500));
      OneSignal.User.pushSubscription.optIn();
      await Future.delayed(const Duration(milliseconds: 1500));

      token = OneSignal.User.pushSubscription.token;
      isOptedIn = OneSignal.User.pushSubscription.optedIn;
    }

    if (!permissionGranted) {}

    // Écouter les événements de notification
    OneSignal.Notifications.addClickListener((event) {});

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {});

    // Récupérer le Subscription ID via l'observateur
    OneSignal.User.pushSubscription.addObserver((state) {
      String? subscriptionId = state.current.id;
      if (subscriptionId != null) {
        // Envoyer le Subscription ID au backend
        _savePlayerIdToBackend(subscriptionId);
      }
    });

    // ✅ NOUVEAU: Monitoring continu avec plusieurs tentatives
    _startOneSignalMonitoring();

    // Récupérer les IDs OneSignal après un délai plus long et forcer si nécessaire
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        // Subscription ID (équivalent du Player ID - c'est ce qu'il faut utiliser)
        String? subscriptionId = OneSignal.User.pushSubscription.id;

        // Push Token (token du device Apple/Google)
        String? pushToken = OneSignal.User.pushSubscription.token;

        // Opted In status
        bool? optedIn = OneSignal.User.pushSubscription.optedIn;

        // ✅ NOUVEAU: Si pas encore abonné OU pas de token, forcer avec insistance
        if (optedIn != true || pushToken == null || pushToken.isEmpty) {
          for (int attempt = 1; attempt <= 5; attempt++) {
            await forceOneSignalSubscription();
            await Future.delayed(const Duration(milliseconds: 1500));

            subscriptionId = OneSignal.User.pushSubscription.id;
            pushToken = OneSignal.User.pushSubscription.token;
            optedIn = OneSignal.User.pushSubscription.optedIn;

            // Si succès, sortir de la boucle
            if (optedIn == true && pushToken != null && pushToken.isNotEmpty) {
              break;
            }
          }
        }

        if (subscriptionId != null && subscriptionId.isNotEmpty) {
        } else {}

        if (pushToken != null && pushToken.isNotEmpty) {
        } else {}

        if (optedIn == true) {
          // Sauvegarder le player_id si l'utilisateur est abonné
          if (subscriptionId != null && subscriptionId.isNotEmpty) {
            _savePlayerIdToBackend(subscriptionId);
          }
        } else {}
      } catch (e) {}
    });
  } catch (e) {}

  // ========== NOUVELLE ÉTAPE : INITIALISATION FIREBASE ==========
  // try {
  //   print('🔥 [MAIN] Initialisation Firebase...');
  //   await Firebase.initializeApp(
  //     options: DefaultFirebaseOptions.currentPlatform,
  //   );
  //   print('✅ [MAIN] Firebase initialisé avec succès');
  // } catch (e) {
  //   print('❌ [MAIN] Erreur initialisation Firebase: $e');
  //   // Continuer sans Firebase en cas d'erreur
  // }

  // GÉOLOCALISATION EN ARRIÈRE-PLAN avec sauvegarde automatique du code pays
  final locationService = LocationService();

  // Lancer l'initialisation en arrière-plan (non-bloquant)
  locationService
      .initializeLocationOptional()
      .then((result) async {
        // ========== NOUVEAU: VÉRIFIER AVANT DE SAUVEGARDER ==========
        try {
          final token = await SessionManager.getToken();
          final existingZone = await ZoneBenefManager.getZoneBenef();

          if (token == null ||
              token.isEmpty ||
              existingZone == null ||
              existingZone.isEmpty) {
            // Sauvegarder seulement si pas d'utilisateur connecté OU pas de zone
            await ZoneBenefManager.saveZoneBenef(
              result.country.code.toUpperCase(),
            );
          } else {
            // Utilisateur connecté avec zone → NE PAS ÉCRASER
          }
        } catch (e) {}
      })
      .catchError((e) => {ZoneBenefManager.saveZoneBenef('CG')});

  // Demander les permissions de base en parallèle (non-bloquant)
  PermissionManager.requestModernPermissions(null);

  final globalNavigatorKey = GlobalKey<NavigatorState>();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppDataProvider(navigatorKey: globalNavigatorKey),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(navigatorKey: globalNavigatorKey),
    ),
  );
}

// ========== APPLICATION PRINCIPALE ==========
class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({required this.navigatorKey, super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Wortis',
          debugShowCheckedModeBanner: false,
          navigatorObservers: [routeObserver],
          theme: themeProvider.getLightTheme(),
          darkTheme: themeProvider.getDarkTheme(),
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const AppStartupPage(),
          // Routes pour optimisation
          routes: {
            '/home': (context) => HomePage(routeObserver: routeObserver),
            '/home_dias': (context) => const HomePageDias(),
            '/auth': (context) => const AuthentificationPage(),
          },
        );
      },
    );
  }
}

// ========== PAGE DE DÉMARRAGE AVEC INTÉGRATION DATAPROVIDER ==========
class AppStartupPage extends StatefulWidget {
  const AppStartupPage({super.key});

  @override
  State<AppStartupPage> createState() => _AppStartupPageState();
}

class _AppStartupPageState extends State<AppStartupPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _loadingMessage = 'Initialisation...';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeApp();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40.0,
      ),
    ]).animate(_animationController);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Demander l'autorisation ATT en premier sur iOS (non-bloquant)
      _requestTrackingPermission();

      // 2. GÉOLOCALISATION EN ARRIÈRE-PLAN avec sauvegarde automatique
      setState(() => _loadingMessage = 'Géolocalisation en cours...');
      final locationService = LocationService();

      // Attendre que l'initialisation soit complète avec timeout de sécurité
      final locationResult = await locationService
          .waitForInitialization()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              return LocationResult.fallback(
                country: countries.firstWhere(
                  (c) => c.code == 'CG',
                  orElse: () => countries.first,
                ),
                reason: 'Timeout initialisation',
              );
            },
          );

      // ========== NOUVEAU: SAUVEGARDER AUTOMATIQUEMENT LE CODE PAYS DÉTECTÉ ==========
      await _saveDetectedZoneWithManager(locationResult.country);

      // 3. Vérifier la cohérence des codes pays existants
      await _verifyCountryCodeConsistency();

      // 4. Vérifier la session utilisateur
      setState(() => _loadingMessage = 'Vérification session...');
      await Future.delayed(const Duration(milliseconds: 500));

      final hasValidSession = await _checkUserSession();

      if (!hasValidSession) {
        // Pas de token = redirection vers authentification
        _navigateToAuth();
        return;
      }

      // 5. INITIALISATION DU DATAPROVIDER (QUI INCLUT MAINTENANT FIREBASE)
      setState(() => _loadingMessage = 'Chargement données...');
      final appDataProvider = Provider.of<AppDataProvider>(
        context,
        listen: false,
      );

      // Utiliser la méthode initializeApp du DataProvider avec timeout
      await appDataProvider
          .initializeApp(context)
          .timeout(const Duration(seconds: 10), onTimeout: () {});

      // 6. CHARGEMENT DES PAYS ÉLIGIBLES (nécessaire pour homepage_dias)
      if (!appDataProvider.isEligibleCountriesLoading) {
        await appDataProvider.loadEligibleCountries().timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      }

      // 7. Navigation basée sur zone_benef_code (maintenant garanti d'être sauvegardé)
      setState(() => _loadingMessage = 'Finalisation...');
      await _navigateToHomeBasedOnLocation();

      // NOUVEAU : Après l'initialisation complète
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        await AppRatingManager.incrementAppOpenCount(context);
      }
    } catch (e) {
      // En cas d'erreur, sauvegarder CG par défaut et aller vers auth
      await ZoneBenefManager.saveZoneBenef('CG');
      _navigateToAuth();
    }
  }

  void _requestTrackingPermission() {
    if (Platform.isIOS) {
      AppTrackingTransparency.requestTrackingAuthorization()
          .then((status) => {})
          .catchError((e) => {});
    }
  }

  Future<bool> _checkUserSession() async {
    try {
      final token = await SessionManager.getToken();
      final isValid = token != null && token.isNotEmpty;
      return isValid;
    } catch (e) {
      return false;
    }
  }

  // ========== MÉTHODE CORRIGÉE: NAVIGATION BASÉE SUR CODES PAYS ==========
  Future<void> _navigateToHomeBasedOnLocation() async {
    try {
      final zoneBenefCode = await ZoneBenefManager.getZoneBenef();

      // ========== CORRECTION: COMPARER AVEC LE CODE PAYS ==========
      String finalCode = zoneBenefCode?.toUpperCase() ?? 'CG';

      if (finalCode == 'CG') {
        // Congo (code CG) -> HomePage original

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(routeObserver: routeObserver),
            ),
            (route) => false,
          );
        }
      } else {
        // Autres zones -> HomePageDias

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePageDias()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      // En cas d'erreur, rediriger vers HomePage par défaut avec fallback CG
      await ZoneBenefManager.saveZoneBenef('CG');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(routeObserver: routeObserver),
          ),
          (route) => false,
        );
      }
    }
  }

  // ========== MÉTHODE CORRIGÉE: SAUVEGARDE CODE PAYS ==========
  Future<void> _saveDetectedZoneWithManager(Country country) async {
    try {
      // Vérifier si utilisateur connecté avec zone existante
      final token = await SessionManager.getToken();
      final existingZone = await ZoneBenefManager.getZoneBenef();

      if (token != null &&
          token.isNotEmpty &&
          existingZone != null &&
          existingZone.isNotEmpty) {
        // NE PAS ÉCRASER la zone utilisateur
      } else {
        // Sauvegarder géolocalisation seulement si pas d'utilisateur/zone
        final countryCode = country.code.toUpperCase();
        await ZoneBenefManager.saveZoneBenef(countryCode);
      }
    } catch (e) {}
  }

  // ========== NOUVELLE MÉTHODE: VÉRIFICATION COHÉRENCE CODES PAYS ==========
  Future<void> _verifyCountryCodeConsistency() async {
    try {
      final zoneBenef = await ZoneBenefManager.getZoneBenef();

      // Vérifier si c'est un code pays valide (2 lettres majuscules)
      if (zoneBenef != null &&
          zoneBenef.length == 2 &&
          zoneBenef == zoneBenef.toUpperCase()) {
      } else {
        // Si c'est un nom de pays, le convertir en code
        String correctedCode = 'CG'; // Fallback par défaut

        if (zoneBenef != null) {
          final country = countries.firstWhere(
            (c) => c.name.toLowerCase() == zoneBenef.toLowerCase(),
            orElse: () => countries.firstWhere((c) => c.code == 'CG'),
          );
          correctedCode = country.code.toUpperCase();
        }

        await ZoneBenefManager.saveZoneBenef(correctedCode);
      }
    } catch (e) {
      // En cas d'erreur, forcer Congo par défaut
      await ZoneBenefManager.saveZoneBenef('CG');
    }
  }

  void _navigateToSpecificHome(Widget homeWidget) {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => homeWidget,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _navigateToAuth() {
    if (!mounted) return;

    print('🔐 [AppStartup] Navigation vers AuthentificationPage');
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF006699),
      body: Stack(
        children: [
          _buildBackground(),
          _buildLogo(),
          if (_isLoading) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF006699),
            const Color(0xFF006699).withOpacity(0.8),
            const Color(0xFF006699).withOpacity(0.6),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'assets/wortisapp.png',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _loadingMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
