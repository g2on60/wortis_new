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

    print('🔍 [Monitor $checks] OptedIn: $isOptedIn | Token: ${token != null ? "✅" : "❌"} | ID: ${subscriptionId != null ? "✅" : "❌"}');

    // Si pas abonné, forcer à nouveau
    if (isOptedIn != true || token == null || token.isEmpty) {
      print('   ⚠️ Forçage automatique...');
      OneSignal.User.pushSubscription.optIn();
    }

    // Arrêter après 10 vérifications (30 secondes)
    if (checks >= 10) {
      timer.cancel();
      print('🛑 [Monitor] Arrêt du monitoring après 30 secondes');

      final finalOptedIn = OneSignal.User.pushSubscription.optedIn;
      final finalToken = OneSignal.User.pushSubscription.token;
      print('📊 [Monitor] État final: OptedIn=${finalOptedIn == true ? "✅" : "❌"} | Token=${finalToken != null ? "✅" : "❌"}');
    }
  });
}

// ========== FONCTION POUR FORCER LA SOUSCRIPTION ONESIGNAL ==========
Future<bool> forceOneSignalSubscription() async {
  try {
    print('🔄 [OneSignal] Forçage manuel de la souscription...');

    // Forcer l'opt-in
    OneSignal.User.pushSubscription.optIn();

    // Attendre que l'état soit mis à jour
    await Future.delayed(const Duration(milliseconds: 1000));

    // Vérifier l'état
    final isOptedIn = OneSignal.User.pushSubscription.optedIn;
    final subscriptionId = OneSignal.User.pushSubscription.id;
    final pushToken = OneSignal.User.pushSubscription.token;

    print('📊 [OneSignal] Résultat du forçage:');
    print('   - Abonné: ${isOptedIn == true ? "OUI ✅" : "NON ❌"}');
    print('   - Subscription ID: ${subscriptionId ?? "Non disponible"}');
    print('   - Push Token: ${pushToken ?? "Non disponible"}');

    if (isOptedIn == true && subscriptionId != null) {
      // Sauvegarder le player ID
      await _savePlayerIdToBackend(subscriptionId);
      return true;
    }

    return false;
  } catch (e) {
    print('❌ [OneSignal] Erreur lors du forçage: $e');
    return false;
  }
}

// ========== FONCTION POUR SAUVEGARDER LE PLAYER ID ==========
Future<void> _savePlayerIdToBackend(String playerId) async {
  try {
    print('💾 [OneSignal] Tentative de sauvegarde du Player ID...');

    // Toujours stocker localement le Player ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onesignal_player_id', playerId);
    print('💾 [OneSignal] Player ID stocké localement: $playerId');

    // Récupérer le token utilisateur (qui est aussi l'user_id)
    final userId = await SessionManager.getToken();
    if (userId == null || userId.isEmpty) {
      print('⚠️ [OneSignal] Pas de token utilisateur, envoi au backend reporté à la connexion');
      return;
    }

    print('📤 [OneSignal] Envoi du Player ID au backend pour user: $userId');

    // Envoyer le player_id au backend
    final response = await http.put(
      Uri.parse('https://api.live.wortis.cg/api/apk_update/player_id/$userId'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'player_id': playerId,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ [OneSignal] Player ID sauvegardé avec succès sur le backend');
    } else {
      print('❌ [OneSignal] Erreur sauvegarde: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('❌ [OneSignal] Exception lors de la sauvegarde: $e');
  }
}

// ========== FONCTION POUR ENVOYER LE PLAYER ID LOCAL AU BACKEND ==========
Future<void> sendLocalPlayerIdToBackend() async {
  try {
    // Récupérer le Player ID stocké localement
    final prefs = await SharedPreferences.getInstance();
    final playerId = prefs.getString('onesignal_player_id');

    if (playerId == null || playerId.isEmpty) {

      print('⚠️ [OneSignal] Aucun Player ID local trouvé');
      
      return;
    }

    // Récupérer le token utilisateur
    final userId = await SessionManager.getToken();
    if (userId == null || userId.isEmpty) {
      print('⚠️ [OneSignal] Pas de token utilisateur');
      return;
    }

    print('📤 [OneSignal] Envoi du Player ID local au backend pour user: $userId');

    // Envoyer le player_id au backend
    final response = await http.put(
      Uri.parse('https://api.live.wortis.cg/api/apk_update/player_id/$userId'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'player_id': playerId,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ [OneSignal] Player ID local envoyé avec succès au backend');
    } else {
      print('❌ [OneSignal] Erreur envoi Player ID local: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ [OneSignal] Exception lors de l\'envoi du Player ID local: $e');
  }
}

// ========== FONCTION MAIN OPTIMISÉE AVEC FIREBASE ==========
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 [MAIN] === DÉMARRAGE APPLICATION WORTIS ===');

  // ========== INITIALISATION ONESIGNAL ==========
  try {
    print('🔔 [MAIN] Initialisation OneSignal...');

    // Configuration OneSignal - Un seul App ID pour iOS et Android
    String oneSignalAppId = "e3d84011-ed0b-4f57-ac5c-aad1b7ea10a3";

    print('📱 [OneSignal] Plateforme: ${Platform.isIOS ? "iOS" : "Android"}');
    print('🆔 [OneSignal] App ID: $oneSignalAppId');

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    // Désactiver les In-App Messages (popup "Open Settings")
    OneSignal.InAppMessages.paused(true);

    OneSignal.initialize(oneSignalAppId);

    // Attendre que OneSignal s'initialise complètement
    await Future.delayed(const Duration(milliseconds: 500));

    // Demander la permission pour les notifications UNE SEULE FOIS
    print('📲 [OneSignal] Demande de permission pour les notifications...');
    final permissionGranted = await OneSignal.Notifications.requestPermission(true);
    print('🔔 [OneSignal] Permission accordée: $permissionGranted');

    // Activer la souscription push
    if (permissionGranted) {
      OneSignal.User.pushSubscription.optIn();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    bool? isOptedIn = OneSignal.User.pushSubscription.optedIn;
    String? token = OneSignal.User.pushSubscription.token;

    print('📊 [OneSignal] État d\'abonnement: ${isOptedIn == true ? "ABONNÉ ✅" : "NON ABONNÉ ❌"}');
    print('📝 [OneSignal] Push Token: ${token ?? "NON DISPONIBLE ❌"}');

    // ✅ NOUVEAU: Si pas de token, tentative de réinitialisation
    if (token == null || token.isEmpty) {
      print('🔄 [OneSignal] Pas de token - Tentative de réinitialisation...');
      OneSignal.User.pushSubscription.optOut();
      await Future.delayed(const Duration(milliseconds: 500));
      OneSignal.User.pushSubscription.optIn();
      await Future.delayed(const Duration(milliseconds: 1500));

      token = OneSignal.User.pushSubscription.token;
      isOptedIn = OneSignal.User.pushSubscription.optedIn;
      print('📝 [OneSignal] Nouveau Push Token: ${token ?? "TOUJOURS ABSENT ❌"}');
      print('📊 [OneSignal] Nouvel état: ${isOptedIn == true ? "ABONNÉ ✅" : "NON ABONNÉ ❌"}');
    }

    if (!permissionGranted) {
      print('⚠️ [OneSignal] Permission système refusée - L\'utilisateur doit l\'activer manuellement dans les Paramètres');
    }

    // Écouter les événements de notification
    OneSignal.Notifications.addClickListener((event) {
      print('📬 [OneSignal] Notification cliquée: ${event.notification.body}');
    });

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('📬 [OneSignal] Notification reçue en foreground: ${event.notification.body}');
    });

    // Récupérer le Subscription ID via l'observateur
    OneSignal.User.pushSubscription.addObserver((state) {
      String? subscriptionId = state.current.id;
      if (subscriptionId != null) {
        print('🔑 [OneSignal] Subscription ID: $subscriptionId');
        print('📝 [OneSignal] Push Token: ${state.current.token}');

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
          print('🔄 [OneSignal] Tentatives MULTIPLES de forçage...');

          for (int attempt = 1; attempt <= 5; attempt++) {
            print('   🔁 Tentative $attempt/5');
            await forceOneSignalSubscription();
            await Future.delayed(const Duration(milliseconds: 1500));

            subscriptionId = OneSignal.User.pushSubscription.id;
            pushToken = OneSignal.User.pushSubscription.token;
            optedIn = OneSignal.User.pushSubscription.optedIn;

            // Si succès, sortir de la boucle
            if (optedIn == true && pushToken != null && pushToken.isNotEmpty) {
              print('   ✅ Succès à la tentative $attempt!');
              break;
            }
          }
        }

        print('═══════════════════════════════════════');
        print('📱 [OneSignal] INFORMATIONS UTILISATEUR:');
        print('');

        if (subscriptionId != null && subscriptionId.isNotEmpty) {
          print('🔑 [OneSignal] Subscription ID (Player ID): $subscriptionId');
          print('💡 IMPORTANT: Utilisez ce Subscription ID dans votre API Flask!');
          print('   Exemple: {"player_id": "$subscriptionId"}');
        } else {
          print('⚠️ [OneSignal] Subscription ID pas encore disponible');
          print('   Réessayez dans quelques secondes...');
        }
        print('');

        if (pushToken != null && pushToken.isNotEmpty) {
          print('📝 [OneSignal] Push Token: $pushToken');
        } else {
          print('⚠️ [OneSignal] Push Token pas disponible');
        }
        print('');

        if (optedIn == true) {
          print('✅ [OneSignal] Statut: ABONNÉ - Peut recevoir des notifications');

          // Sauvegarder le player_id si l'utilisateur est abonné
          if (subscriptionId != null && subscriptionId.isNotEmpty) {
            _savePlayerIdToBackend(subscriptionId);
          }
        } else {
          print('❌ [OneSignal] Statut: NON ABONNÉ - Ne peut PAS recevoir de notifications');
          print('   Solution: Relancez l\'app et acceptez les notifications');
          print('   Ou activez manuellement: OneSignal.User.pushSubscription.optIn()');
        }

        print('═══════════════════════════════════════');
      } catch (e) {
        print('❌ [OneSignal] Erreur récupération IDs: $e');
      }
    });

    print('✅ [MAIN] OneSignal initialisé avec succès');
  } catch (e) {
    print('❌ [MAIN] Erreur initialisation OneSignal: $e');
  }

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
  print('🌍 [MAIN] Pré-initialisation géolocalisation...');
  final locationService = LocationService();

  // Lancer l'initialisation en arrière-plan (non-bloquant)
  locationService.initializeLocationOptional().then((result) async {
    print(
        '✅ [MAIN] Géolocalisation pré-initialisée: ${result.country.name} (${result.country.code})');

    // ========== NOUVEAU: VÉRIFIER AVANT DE SAUVEGARDER ==========
    try {
      final token = await SessionManager.getToken();
      final existingZone = await ZoneBenefManager.getZoneBenef();

      if (token == null ||
          token.isEmpty ||
          existingZone == null ||
          existingZone.isEmpty) {
        // Sauvegarder seulement si pas d'utilisateur connecté OU pas de zone
        await ZoneBenefManager.saveZoneBenef(result.country.code.toUpperCase());
        print(
            '💾 [MAIN] Code pays pré-sauvegardé: ${result.country.code.toUpperCase()}');
      } else {
        // Utilisateur connecté avec zone → NE PAS ÉCRASER
        print('🔒 [MAIN] Zone utilisateur préservée: $existingZone');
      }
    } catch (e) {
      print('⚠️ [MAIN] Erreur sauvegarde conditionnelle: $e');
    }
  }).catchError((e) => {
        print('⚠️ [MAIN] Erreur pré-initialisation géolocalisation: $e'),
        ZoneBenefManager.saveZoneBenef('CG')
      });

  // Demander les permissions de base en parallèle (non-bloquant)
  PermissionManager.requestModernPermissions(null);

  final globalNavigatorKey = GlobalKey<NavigatorState>();

  print('📱 [MAIN] Lancement de l\'interface utilisateur...');
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
          themeMode:
              themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40.0,
      ),
    ]).animate(_animationController);

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      print('🔄 [AppStartup] Début initialisation...');

      // 1. Demander l'autorisation ATT en premier sur iOS (non-bloquant)
      _requestTrackingPermission();

      // 2. GÉOLOCALISATION EN ARRIÈRE-PLAN avec sauvegarde automatique
      setState(() => _loadingMessage = 'Géolocalisation en cours...');
      final locationService = LocationService();

      // Attendre que l'initialisation soit complète avec timeout de sécurité
      final locationResult =
          await locationService.waitForInitialization().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print(
              '⚠️ [AppStartup] Timeout géolocalisation - continuation avec Congo par défaut');
          return LocationResult.fallback(
            country: countries.firstWhere((c) => c.code == 'CG',
                orElse: () => countries.first),
            reason: 'Timeout initialisation',
          );
        },
      );

      print(
          '✅ [AppStartup] Géolocalisation garantie prête: ${locationResult.country.name} (${locationResult.country.code})');

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
        print('❌ [AppStartup] Aucun token trouvé');
        _navigateToAuth();
        return;
      }

      print('✅ [AppStartup] Session valide trouvée');

      // 5. INITIALISATION DU DATAPROVIDER (QUI INCLUT MAINTENANT FIREBASE)
      setState(() => _loadingMessage = 'Chargement données...');
      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);

      // Utiliser la méthode initializeApp du DataProvider avec timeout
      await appDataProvider
          .initializeApp(context)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        print(
            '⚠️ [AppStartup] Timeout DataProvider - continuation avec données partielles');
      });

      // 6. CHARGEMENT DES PAYS ÉLIGIBLES (nécessaire pour homepage_dias)
      if (!appDataProvider.isEligibleCountriesLoading) {
        await appDataProvider
            .loadEligibleCountries()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          print('⚠️ [AppStartup] Timeout pays éligibles - continuation');
        });
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
      print('❌ [AppStartup] Erreur: $e');
      // En cas d'erreur, sauvegarder CG par défaut et aller vers auth
      await ZoneBenefManager.saveZoneBenef('CG');
      _navigateToAuth();
    }
  }

  void _requestTrackingPermission() {
    if (Platform.isIOS) {
      print('📱 [AppStartup] Demande permission tracking iOS...');
      AppTrackingTransparency.requestTrackingAuthorization()
          .then((status) => print('✅ [AppStartup] Tracking iOS: $status'))
          .catchError((e) => print('⚠️ [AppStartup] Erreur tracking: $e'));
    }
  }

  Future<bool> _checkUserSession() async {
    try {
      final token = await SessionManager.getToken();
      final isValid = token != null && token.isNotEmpty;
      print('🔍 [AppStartup] Session valide: $isValid');
      return isValid;
    } catch (e) {
      print('❌ [AppStartup] Erreur vérification session: $e');
      return false;
    }
  }

  // ========== MÉTHODE CORRIGÉE: NAVIGATION BASÉE SUR CODES PAYS ==========
  Future<void> _navigateToHomeBasedOnLocation() async {
    try {
      print(
          '🏠 [AppStartup] Détermination navigation basée sur zone_benef_code...');

      final zoneBenefCode = await ZoneBenefManager.getZoneBenef();
      print('🔍 [AppStartup] zone_benef_code récupérée: $zoneBenefCode');

      // ========== CORRECTION: COMPARER AVEC LE CODE PAYS ==========
      String finalCode = zoneBenefCode?.toUpperCase() ?? 'CG';

      if (finalCode == 'CG') {
        // Congo (code CG) -> HomePage original
        print('🇨🇬 [AppStartup] Redirection vers HomePage (Congo - CG)');

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
        print(
            '🌍 [AppStartup] Redirection vers HomePageDias (zone_benef_code: $finalCode)');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const HomePageDias(),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('❌ [AppStartup] Erreur lors de la redirection: $e');
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
        print('🔒 [AppStartup] Zone utilisateur préservée: $existingZone');
      } else {
        // Sauvegarder géolocalisation seulement si pas d'utilisateur/zone
        final countryCode = country.code.toUpperCase();
        await ZoneBenefManager.saveZoneBenef(countryCode);
        print('✅ [AppStartup] Code pays détecté sauvegardé: $countryCode');
      }
    } catch (e) {
      print('❌ [AppStartup] Erreur sauvegarde code pays détecté: $e');
    }
  }

  // ========== NOUVELLE MÉTHODE: VÉRIFICATION COHÉRENCE CODES PAYS ==========
  Future<void> _verifyCountryCodeConsistency() async {
    try {
      final zoneBenef = await ZoneBenefManager.getZoneBenef();
      print('🔍 [AppStartup] Vérification cohérence codes pays...');
      print('   - zone_benef_code stockée: $zoneBenef');

      // Vérifier si c'est un code pays valide (2 lettres majuscules)
      if (zoneBenef != null &&
          zoneBenef.length == 2 &&
          zoneBenef == zoneBenef.toUpperCase()) {
        print('✅ [AppStartup] Code pays valide détecté: $zoneBenef');
      } else {
        print('⚠️ [AppStartup] Code pays invalide, correction en cours...');

        // Si c'est un nom de pays, le convertir en code
        String correctedCode = 'CG'; // Fallback par défaut

        if (zoneBenef != null) {
          final country = countries.firstWhere(
            (c) => c.name.toLowerCase() == zoneBenef.toLowerCase(),
            orElse: () => countries.firstWhere((c) => c.code == 'CG'),
          );
          correctedCode = country.code.toUpperCase();
        }

        print(
            '🔧 [AppStartup] Correction code pays: $zoneBenef -> $correctedCode');
        await ZoneBenefManager.saveZoneBenef(correctedCode);
      }
    } catch (e) {
      print('❌ [AppStartup] Erreur vérification codes pays: $e');
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
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
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
