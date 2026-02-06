// ignore_for_file: unused_field, deprecated_member_use, unused_element, duplicate_ignore, unnecessary_null_comparison, empty_catches, unrelated_type_equality_checks, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wortis/class/CustomPageTransition.dart';
import 'package:wortis/class/form_service.dart';
import 'package:wortis/class/catalog_service.dart';
import 'package:wortis/pages/reservation_service.dart';
import 'package:wortis/class/icon_utils.dart';
import 'package:wortis/class/webviews.dart';
import 'package:wortis/pages/allservice.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:wortis/pages/moncompte.dart';
import 'package:wortis/pages/news.dart';
import 'package:wortis/pages/notifications.dart';
import 'package:wortis/pages/subscriptionfamlink.dart';
import 'package:wortis/pages/transaction.dart';
import 'package:wortis/class/dataprovider.dart';
import 'package:wortis/class/class.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wortis/main.dart' as main_lib show sendLocalPlayerIdToBackend;

void main() {
  runApp(const WortisApp());
}

class WortisApp extends StatelessWidget {
  const WortisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wortis',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const HomePageDias(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Configuration constants
class AppConfig {
  static const primaryColor = Color(0xFF006699);
  static const animationDuration = Duration(milliseconds: 300);
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const String baseUrl = "https://api.live.wortis.cg";
}

// Service pour mise à jour de zone
class ZoneUpdateService {
  static Future<Map<String, dynamic>> updateUserZone(
      String userId, String zoneBenef, String zoneBenefCode) async {
    try {
      print(
          '🔄 Mise à jour zone: $zoneBenef ($zoneBenefCode) pour utilisateur: $userId');

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/update_user_zone'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'zone_benef': zoneBenef,
          'zone_benef_code': zoneBenefCode,
        }),
      );

      //print('📡 Réponse API: ${response.statusCode}');
      //print('📄 Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['Code'] == 200) {
          //print('✅ Zone mise à jour avec succès');
          return {
            'success': true,
            'message': responseData['message'],
            'user': responseData['user'],
          };
        } else {
          //print('⚠️ Échec côté serveur: ${responseData['message']}');
          return {
            'success': false,
            'message': responseData['message'],
          };
        }
      } else {
        //print('❌ Échec HTTP: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Erreur HTTP: ${response.statusCode}',
        };
      }
    } catch (e) {
      //print('❌ Erreur lors de la mise à jour: $e');
      return {
        'success': false,
        'message': 'Erreur: ${e.toString()}',
      };
    }
  }
}

// Classe pour les transitions de page personnalisées
class ServicePageTransitionDias extends PageRouteBuilder {
  final Widget page;

  ServicePageTransitionDias({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var slideAnimation = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            var fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            ));

            var scaleAnimation = Tween<double>(
              begin: 0.8,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ));

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              ),
            );
          },
        );
}

class CustomPageTransitionDias extends PageRouteBuilder {
  final Widget page;

  CustomPageTransitionDias({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var slideAnimation = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutExpo,
            ));

            var fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            ));

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
        );
}

class HomePageDias extends StatefulWidget {
  final RouteObserver<PageRoute>? routeObserver;

  const HomePageDias({super.key, this.routeObserver});

  @override
  State<HomePageDias> createState() => _HomePageDiasState();
}

class _HomePageDiasState extends State<HomePageDias>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  late Timer _timer;
  int _currentPage = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _filteredServices = [];

  // ========== AJOUT DES VARIABLES MANQUANTES COMME DANS home_page.dart ==========
  List<Map<String, dynamic>> _selectedServices = [];
  bool _showAllServices = false;

  // Variables pour la sélection de pays
  String _selectedCountry = "";
  String _selectedFlag = "";
  String _selectedDialCode = "";
  List<Map<String, dynamic>> _availableCountries = [];
  List<Map<String, dynamic>> _countryFilteredServices = [];
  final bool _isUpdatingZone = false;
  bool _isTokenPresent = false;
  bool _isCountryChanging = false;
  bool _showCountryChangeOverlay = false;
  String? _newSelectedCountry;
  int _currentStep = 0;
  bool _hasRestoredCountry = false;
  final List<String> _progressSteps = [
    'Mise à jour serveur',
    'Sauvegarde locale',
    'Rechargement données',
    'Finalisation'
  ];

  bool _showTimeoutPopup = false;
  Timer? _loadingTimeoutTimer;

  final bool _isReloadingData =
      false; // Ajouter cette variable si pas déjà présente
  Timer? _debugTimer;

  // Animation controllers
  late AnimationController _bannerAnimationController;
  late AnimationController _sectorsAnimationController;
  late AnimationController _searchAnimationController;
  late AnimationController _bottomNavAnimationController;
  late AnimationController _searchResultsController;
  late AnimationController _navItemAnimationController;
  late AnimationController _fullscreenServicesController; // AJOUT

  // Animations
  late Animation<Offset> _bannerSlideAnimation;
  late Animation<double> _bannerFadeAnimation;
  late Animation<double> _sectorsFadeAnimation;
  late Animation<Offset> _bottomNavSlideAnimation;
  late Animation<double> _searchResultsScale;
  late Animation<double> _searchResultsOpacity;
  late Animation<double> _navItemBounceAnimation;
  late Animation<double> _fullscreenServicesScale; // AJOUT
  late Animation<double> _fullscreenServicesOpacity; // AJOUT

  @override
  void initState() {
    super.initState();

    // ✅ NOUVEAU: Envoyer le Player ID OneSignal au backend
    main_lib.sendLocalPlayerIdToBackend();

    // ✅ OPTIMISATION: Timer de debug désactivé en production
    // Décommentez uniquement pour le débogage
    // _debugTimer = Timer.periodic(Duration(seconds: 5), (timer) {
    //   if (mounted) {
    //     final provider = Provider.of<AppDataProvider>(context, listen: false);
    //     print( '🔍 [DEBUG Periodic] isDataReady: ${provider.isDataReady}, isLoading: ${provider.isLoading}');
    //   }
    // });

    // Enregistrer que nous sommes sur HOMEPAGE_DIAS
    NavigationManager.setCurrentHomePage('HomePageDias');
    _searchController.addListener(() {
      setState(() {
        // Force le rebuild pour mettre à jour l'affichage de l'icône
      });
    });

    // Initialize animation controllers
    _initializeAnimationControllers();

    // Configure animations
    _configureAnimations();

    // Start setup
    _initializeBasicSetup();

    // Vérifier le token
    _checkToken();

    // Start animation sequence
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ✅ OPTIMISATION: Exécuter en parallèle les tâches indépendantes
      await Future.wait([
        _restoreCountryOnce(),
        _checkToken(),
      ]);

      // Démarrer l'animation et charger les données en parallèle
      _startAnimationSequence();
      _loadDataFromProvider(); // Non-bloquant
      ConnectivityManager(context).initConnectivity();
    });
  }

  // Méthode pour vérifier le token
  Future<void> _checkToken() async {
    final token = await SessionManager.getToken();
    setState(() {
      _isTokenPresent = token != null && token.isNotEmpty;
    });
  }

  Future<void> _restoreCountryOnce() async {
    // Ne faire la restauration qu'une seule fois
    if (_hasRestoredCountry) {
      //print('🔒 [HomePageDias] Restauration déjà effectuée, ignorée');
      return;
    }

    try {
      //print('🔄 [HomePageDias] Restauration initiale du pays...');

      final zoneBenefCode = await ZoneBenefManager.getZoneBenef();
      //print('📱 zone_benef_code: $zoneBenefCode');

      if (zoneBenefCode != null && zoneBenefCode.isNotEmpty) {
        final matchingCountry = countries.firstWhere(
          (country) =>
              country.code.toUpperCase() == zoneBenefCode.toUpperCase(),
          orElse: () => const Country(
              name: 'Sénégal',
              code: 'SN',
              dialCode: '+221',
              flag: '🇸🇳',
              region: 'Afrique de l\'Ouest'),
        );

        // Mise à jour SANS setState pour éviter le flash visuel
        _selectedCountry = matchingCountry.name;
        _selectedFlag = matchingCountry.flag;
        _selectedDialCode = matchingCountry.dialCode;

        print(
            '✅ Pays restauré silencieusement: ${matchingCountry.name} ${matchingCountry.flag}');
      } else {
        // Fallback discret vers Sénégal
        _selectedCountry = "Sénégal";
        _selectedFlag = "🇸🇳";
        _selectedDialCode = "+221";
        //print('⚠️ Fallback vers Sénégal');
      }

      // Marquer comme fait pour éviter les répétitions
      _hasRestoredCountry = true;
    } catch (e) {
      //print('❌ Erreur restauration pays: $e');
      // En cas d'erreur, utiliser Sénégal par défaut
      _selectedCountry = "Sénégal";
      _selectedFlag = "🇸🇳";
      _selectedDialCode = "+221";
      _hasRestoredCountry = true;
    }
  }

  void _initializeAnimationControllers() {
    _bannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _sectorsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _bottomNavAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _searchResultsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _navItemAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // ========== AJOUT DU CONTROLLER FULLSCREEN ==========
    _fullscreenServicesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  void _configureAnimations() {
    _bannerSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _bannerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bannerAnimationController,
      curve: Curves.easeIn,
    ));

    _sectorsFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sectorsAnimationController,
      curve: Curves.easeIn,
    ));

    _bottomNavSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bottomNavAnimationController,
      curve: Curves.easeOutExpo,
    ));

    _searchResultsScale = CurvedAnimation(
      parent: _searchResultsController,
      curve: Curves.easeInOut,
    );

    _searchResultsOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchResultsController,
      curve: Curves.easeIn,
    ));

    _navItemBounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _navItemAnimationController,
      curve: Curves.easeInOut,
    ));

    // ========== AJOUT DES ANIMATIONS FULLSCREEN ==========
    _fullscreenServicesScale = CurvedAnimation(
      parent: _fullscreenServicesController,
      curve: Curves.easeInOut,
    );

    _fullscreenServicesOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fullscreenServicesController,
      curve: Curves.easeIn,
    ));
  }

  Future<void> _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _bannerAnimationController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _sectorsAnimationController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    _bottomNavAnimationController.forward();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;

      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);
      if (_currentPage < appDataProvider.banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _initializeBasicSetup() async {
    if (!mounted) return;

    setState(() {
      _filteredServices = [];
    });

    _startAutoScroll();
  }

  // ========== AJOUT DE LA MÉTHODE _selectRandomServices COMME DANS home_page.dart ==========
  void _selectRandomServices() {
    if (!mounted) return;

    final appDataProvider =
        Provider.of<AppDataProvider>(context, listen: false);

    // Vérifier que les services sont disponibles
    if (appDataProvider.services.isEmpty) {
      return;
    }

    try {
      final random = Random();
      final servicesCopy = List.from(appDataProvider.services);
      _selectedServices = [];

      while (_selectedServices.length < 4 && servicesCopy.isNotEmpty) {
        final index = random.nextInt(servicesCopy.length);
        final service = servicesCopy[index] as Map<String, dynamic>;

        // S'assurer que le service a tous les champs nécessaires
        if (service.containsKey('name') && service.containsKey('icon')) {
          _selectedServices.add(service);
        }

        servicesCopy.removeAt(index);
      }

      // Forcer la mise à jour de l'UI si des services ont été trouvés
      if (_selectedServices.isNotEmpty) {
        setState(() {});
      }
    } catch (e) {
      //print('❌ Erreur sélection services: $e');
    }
  }

  // ========== AJOUT DE LA MÉTHODE _onServicesPressed COMME DANS home_page.dart ==========
  void _onServicesPressed(BuildContext context) {
    setState(() {
      _showAllServices = true;
    });
    _fullscreenServicesController.forward();
  }

  // Chargement des données depuis DataProvider
  Future<void> _loadDataFromProvider() async {
    try {
      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);

      // ✅ OPTIMISATION: Démarrer le chargement en parallèle si possible
      final loadFuture = appDataProvider.loadEligibleCountries();

      // Afficher immédiatement l'UI avec un état de chargement
      if (mounted) {
        setState(() {
          // Déclencher le rendu avec un indicateur de chargement
        });
      }

      // Attendre que les données soient chargées
      await loadFuture;

      if (mounted) {
        _buildAvailableCountriesList(appDataProvider);
        _filterServicesByCountry(appDataProvider);
        await _prioritizeStoredCountryInList();

        // Mise à jour finale de l'UI avec les données
        setState(() {
          // Cette mise à jour déclenchera le rendu avec les bonnes valeurs
        });

        // Sélectionner les services aléatoirement (non-bloquant)
        _selectRandomServices();
      }
    } catch (e) {
      //print('❌ Erreur chargement données: $e');
      if (mounted) {
        setState(() {
          // Afficher l'erreur à l'utilisateur
        });
      }
    }
  }

  // Construction de la liste des pays
  void _buildAvailableCountriesList(AppDataProvider appDataProvider) {
    final eligibleCountries = appDataProvider.eligibleCountries;
    _availableCountries.clear();

    //print('🔍 [HomePage] Mapping des codes pays avec la liste countries');
    //print('📋 Codes pays éligibles reçus: $eligibleCountries');

    // Mapping avec la liste des pays de class.dart en utilisant le champ 'code'
    for (String countryCode in eligibleCountries) {
      final matchingCountry = countries.firstWhere(
        (country) => country.code.toUpperCase() == countryCode.toUpperCase(),
        orElse: () => const Country(
            name: '', code: '', dialCode: '', flag: '', region: ''),
      );

      if (matchingCountry.name.isNotEmpty) {
        _availableCountries.add({
          "name": matchingCountry.name,
          "flag": matchingCountry.flag,
          "dialCode": matchingCountry.dialCode,
          "code": matchingCountry.code,
        });

        print(
            '✅ Pays trouvé: ${matchingCountry.name} (${matchingCountry.code}) ${matchingCountry.flag}');
      } else {
        //print('⚠️ Pays non trouvé pour le code: $countryCode');
      }
    }

    // Définir le pays par défaut
    if (_availableCountries.isNotEmpty && !_hasRestoredCountry) {
      final defaultCountry = _availableCountries.first;
      _selectedCountry = defaultCountry["name"];
      _selectedFlag = defaultCountry["flag"];
      _selectedDialCode = defaultCountry["dialCode"];
      print(
          '🏠 Pays par défaut (aucune restauration): ${defaultCountry["name"]} ${defaultCountry["flag"]}');
    } else if (_hasRestoredCountry) {
      //print('🔒 Pays déjà restauré, pas de modification par défaut');
    }

    //print('🌍 Pays disponibles: ${_availableCountries.length}');
  }

  // Filtrage des services par pays
  void _filterServicesByCountry(AppDataProvider appDataProvider) {
    final allServices = appDataProvider.services;

    _countryFilteredServices = allServices
        .where((service) {
          final serviceMap = service as Map<String, dynamic>;
          final eligibleCountries =
              serviceMap['eligible_countries'] as String? ?? '';

          // Vérifier si le pays sélectionné est dans la liste des pays éligibles du service
          return eligibleCountries
              .toLowerCase()
              .contains(_selectedCountry.toLowerCase());
        })
        .map((service) => service as Map<String, dynamic>)
        .toList();

    print(
        '🔍 Services pour $_selectedCountry: ${_countryFilteredServices.length}');

    if (mounted) {
      setState(() {});
    }
  }

  int _getServicesCountForCountry(String countryName) {
    final appDataProvider =
        Provider.of<AppDataProvider>(context, listen: false);

    // Compter tous les services dans tous les secteurs disponibles
    int totalServices = 0;

    for (final secteur in appDataProvider.secteurs) {
      // Pour chaque secteur, compter ses services
      final sectorServices = appDataProvider.services
          .where((service) =>
              (service as Map<String, dynamic>)['SecteurActivite'] ==
              secteur.name)
          .length;

      totalServices += sectorServices;
    }

    print(
        '🔢 [HomePage] Services pour $countryName: $totalServices (via secteurs)');

    return totalServices;
  }

  void _animateNavItemAndNavigate(int index, Widget page) async {
    if (mounted) {
      setState(() => _selectedIndex = index);

      // Animation de rebond
      await _navItemAnimationController.forward();
      await _navItemAnimationController.reverse();

      // Feedback haptique
      HapticFeedback.lightImpact();

      // Navigation
      if (mounted) {
        Navigator.push(
          context,
          CustomPageTransitionDias(page: page),
        );
      }
    }
  }

  // Retourner à la bonne page d'accueil
  void _returnToCorrectHomePage() {
    if (!mounted) return;

    final currentHomeType = NavigationManager.getCurrentHomePage();

    //print('🏠 [HomePageDias] Type de page actuel: $currentHomeType');

    if (currentHomeType == 'HomePageDias') {
      // Nous sommes déjà sur HomePageDias, ne rien faire
      //print('✅ [HomePageDias] Déjà sur HomePageDias - pas de redirection');
    } else {
      // Rediriger vers HomePage original
      //print('🔄 [HomePageDias] Redirection vers HomePage');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => HomePage(
                routeObserver:
                    widget.routeObserver ?? RouteObserver<PageRoute>())),
      );
    }
  }

  @override
  void dispose() {
    _debugTimer?.cancel();
    _bannerAnimationController.stop();
    _sectorsAnimationController.stop();
    _searchAnimationController.stop();
    _bottomNavAnimationController.stop();
    _searchResultsController.stop();
    _navItemAnimationController.stop();
    _fullscreenServicesController.stop(); // AJOUT

    _timer.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _bannerAnimationController.dispose();
    _sectorsAnimationController.dispose();
    _searchAnimationController.dispose();
    _bottomNavAnimationController.dispose();
    _searchResultsController.dispose();
    _navItemAnimationController.dispose();
    _fullscreenServicesController.dispose(); // AJOUT
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<AppDataProvider>(
      builder: (context, appDataProvider, child) {
        // NOUVEAU: Debug des états
        // print( '🏠 [DEBUG HomePage] isDataReady: ${appDataProvider.isDataReady}');
        //print('🏠 [DEBUG HomePage] isLoading: ${appDataProvider.isLoading}');
        // print(  '🏠 [DEBUG HomePage] isInitialized: ${appDataProvider.isInitialized}');
        //print('🏠 [DEBUG HomePage] error: "${appDataProvider.error}"');
        //print('🏠 [DEBUG HomePage] banners: ${appDataProvider.banners.length}');
        //print(  '🏠 [DEBUG HomePage] secteurs: ${appDataProvider.secteurs.length}');
        //print('🏠 [DEBUG HomePage] _isReloadingData: $_isReloadingData');

        final screenWidth = MediaQuery.of(context).size.width;
        final cardWidth = screenWidth * 0.4;

        if ((!appDataProvider.isDataReady || appDataProvider.isLoading)) {
          // Démarrer le timer pour le timeout si pas encore démarré
          _loadingTimeoutTimer ??= Timer(const Duration(seconds: 30), () {
            if (mounted &&
                (!appDataProvider.isDataReady || appDataProvider.isLoading)) {
              //print('⚠️ [DEBUG HomePage] Timeout détecté - forçage refresh');

              // NOUVEAU: Forcer un refresh et réessayer
              setState(() {
                _showTimeoutPopup = true;
              });

              // Auto-refresh après 3 secondes
              Timer(Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _showTimeoutPopup = false;
                  });
                  appDataProvider.refreshAllData();
                }
              });
            }
          });

          return _buildLoadingScreen(appDataProvider);
        }

        return WillPopScope(
          onWillPop: () async {
            // Empêcher le retour pendant le changement de pays
            if (_showCountryChangeOverlay) return false;
            return true;
          },
          child: Scaffold(
            appBar: _buildAnimatedAppBar(),
            body: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Contenu principal
                  Positioned.fill(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // Banner animé
                          SlideTransition(
                            position: _bannerSlideAnimation,
                            child: FadeTransition(
                              opacity: _bannerFadeAnimation,
                              child: _buildBannerSlider(appDataProvider),
                            ),
                          ),

                          // Secteurs d'activité animés
                          FadeTransition(
                            opacity: _sectorsFadeAnimation,
                            child: _buildActivitySectors(appDataProvider),
                          ),

                          const SizedBox(height: 20),

                          // Widget Miles
                          _buildMilesWidget(context),

                          const SizedBox(height: 20),

                          // ========== SERVICES AVEC LA LOGIQUE IDENTIQUE À home_page.dart ==========
                          FadeTransition(
                            opacity: _sectorsFadeAnimation,
                            child: _buildServices(appDataProvider),
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),

                  // Overlay de recherche
                  if (_isSearching && _searchController.text.isNotEmpty)
                    Positioned.fill(
                      child: _buildAnimatedSearchOverlay(),
                    ),

                  // ========== AJOUT: OVERLAY FULLSCREEN SERVICES ==========
                  if (_showAllServices)
                    Positioned.fill(
                      child: _buildFullscreenServices(appDataProvider),
                    ),

                  // Overlay de changement de pays
                  if (_showCountryChangeOverlay)
                    Positioned.fill(
                      child: _buildCountryChangeOverlay(),
                    ),
                ],
              ),
            ),
            bottomNavigationBar: SlideTransition(
              position: _bottomNavSlideAnimation,
              child: _buildBottomNavigationBar(),
            ),
          ),
        );
      },
    );
  }

  // ========== MÉTHODE _buildServices IDENTIQUE À home_page.dart ==========
  Widget _buildServices(AppDataProvider appDataProvider) {
    if (appDataProvider.isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (appDataProvider.services.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _onServicesPressed(context),
                  label: const Text('Voir',
                      style: TextStyle(color: Color(0xFF006699))),
                  icon: const Icon(Icons.add, color: Color(0xFF006699)),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 48),
                    SizedBox(height: 8),
                    Text(
                      "Aucun service disponible",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Si aucun service n'est sélectionné, essayer d'en sélectionner maintenant
    if (_selectedServices.isEmpty) {
      // CORRECTION: Ne pas appeler setState dans build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectRandomServices();
      });
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _onServicesPressed(context),
                label: const Text('Voir',
                    style: TextStyle(color: Color(0xFF006699))),
                icon: const Icon(Icons.add, color: Color(0xFF006699)),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 360;
              final screenWidth = MediaQuery.of(context).size.width;
              final itemWidth = screenWidth / (isSmallScreen ? 4.5 : 4.2);
              final iconSize = itemWidth * 0.25;
              final fontSize = itemWidth * 0.1;

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
                child: _selectedServices.isEmpty
                    ? Center(
                        child: Text(
                          "Chargement des services...",
                          style: TextStyle(
                            fontSize: fontSize * 1.2,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _selectedServices.map((service) {
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 4 : 8),
                              child: SizedBox(
                                width: itemWidth,
                                child: _buildServiceCard(
                                  iconName: service['icon'],
                                  label: service['name'],
                                  logo: service['logo'],
                                  iconSize: iconSize,
                                  cardWidth: itemWidth,
                                  fontSize: fontSize,
                                  status: service['status'],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String iconName,
    required String label,
    required double iconSize,
    required double cardWidth,
    required double fontSize,
    bool? status, // status est optionnel avec une valeur par défaut true
    String? logo, // Ajout du paramètre logo
  }) {
    final bool isActive =
        status ?? true; // Valeur par défaut true si status est null
    final bool hasLogo = logo != null && logo.isNotEmpty;
    final cardOpacity = isActive ? 1.0 : 0.5;
    final iconColor = isActive ? const Color(0xFF006699) : Colors.grey;

    return Opacity(
      opacity: cardOpacity,
      child: GestureDetector(
        onTap: isActive
            ? () async {
                print('👆 [HomePageDias] CLIC DÉTECTÉ sur: $label');
                if (!mounted) return;

                final appDataProvider =
                    Provider.of<AppDataProvider>(context, listen: false);
                final service = appDataProvider.services.firstWhere(
                    (s) => s['name'] == label,
                    orElse: () => {'Type_Service': '', 'link_view': ''});

                if (!mounted) return;

                // Debug: afficher les données du service
                print('🔍 [HomePageDias] Service: $label');
                print('🔍 [HomePageDias] Type_Service: "${service['Type_Service']}"');
                print('🔍 [HomePageDias] Service complet: $service');

                try {
                  final String typeService = (service['Type_Service'] ?? '').toString().trim().toLowerCase();

                  if (typeService == "webview") {
                    print('➡️ [HomePageDias] Navigation vers WebView');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ServiceWebView(
                          url: service['link_view'] ?? '',
                        ),
                      ),
                    );
                  } else if (typeService == "catalog") {
                    print('➡️ [HomePageDias] Navigation vers CatalogService');
                    await SessionManager.checkSessionAndNavigate(
                      context: context,
                      authenticatedRoute: ServicePageTransitionDias(
                        page: CatalogService(serviceName: label),
                      ),
                      unauthenticatedRoute: const AuthentificationPage(),
                    );
                  } else if (typeService == "reservationservice") {
                    print('➡️ [HomePageDias] Navigation vers ReservationService');
                    await SessionManager.checkSessionAndNavigate(
                      context: context,
                      authenticatedRoute: ServicePageTransitionDias(
                        page: ReservationService(serviceName: label),
                      ),
                      unauthenticatedRoute: const AuthentificationPage(),
                    );
                  } else {
                    print('➡️ [HomePageDias] Navigation vers FormService (default)');
                    await SessionManager.checkSessionAndNavigate(
                      context: context,
                      authenticatedRoute: ServicePageTransitionDias(
                        page: FormService(serviceName: label),
                      ),
                      unauthenticatedRoute: const AuthentificationPage(),
                    );
                  }
                } catch (e) {
                  print('❌ [HomePageDias] Erreur navigation: $e');
                }
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconSize * 1.5,
                height: iconSize * 1.5,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF006699).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: hasLogo
                      ? Image.network(
                          Uri.encodeFull(logo),
                          width: iconSize,
                          height: iconSize,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;

                            // Animation de pulsation subtile pendant le chargement
                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.6, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeInOut,
                              builder: (context, value, _) {
                                return Opacity(
                                  opacity: 0.7,
                                  child: Icon(
                                    IconUtils.getIconData(iconName),
                                    size: iconSize *
                                        value, // Effet subtil de pulsation
                                    color: iconColor.withOpacity(value),
                                  ),
                                );
                              },
                              // Répéter l'animation
                              // ignore: unnecessary_null_comparison
                              onEnd: () => loadingProgress != null
                                  ? null
                                  : setState(() {}),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback à l'icône en cas d'erreur
                            return Icon(
                              IconUtils.getIconData(iconName),
                              size: iconSize,
                              color: iconColor,
                            );
                          },
                        )
                      : Icon(
                          IconUtils.getIconData(iconName),
                          size: iconSize,
                          color: iconColor,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: isActive ? null : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== AJOUT: MÉTHODE _buildFullscreenServices IDENTIQUE À home_page.dart ==========
  Widget _buildFullscreenServices(AppDataProvider appDataProvider) {
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount;
    if (screenWidth < 600) {
      crossAxisCount = 3;
    } else if (screenWidth < 900) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 5;
    }

    return ScaleTransition(
      scale: _fullscreenServicesScale,
      child: FadeTransition(
        opacity: _fullscreenServicesOpacity,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tous les services',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          _fullscreenServicesController.reverse().then((_) {
                            setState(() {
                              _showAllServices = false;
                            });
                          });
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(top: 16.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16.0,
                        mainAxisSpacing: 16.0,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: appDataProvider.services.length,
                      itemBuilder: (context, index) {
                        final service = appDataProvider.services[index];
                        return _buildServiceGridItem(service);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== AJOUT: MÉTHODE _buildServiceGridItem POUR LA GRID FULLSCREEN ==========
  Widget _buildServiceGridItem(Map<String, dynamic> service) {
    final bool isActive = service['status'] ?? true;

    return GestureDetector(
      onTap: isActive
          ? () async {
              if (!mounted) return;

              // Fermer l'overlay fullscreen
              _fullscreenServicesController.reverse().then((_) {
                setState(() {
                  _showAllServices = false;
                });
              });

              // Redirection selon le type de service
              await _redirectToService(service);
            }
          : null,
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppConfig.primaryColor.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: _buildServiceLogo(
                  logoUrl: service['logo']?.toString(),
                  iconName: service['icon'] ?? 'business_center',
                  size: 28,
                  iconColor: isActive ? AppConfig.primaryColor : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  service['name'] ?? 'Service',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive ? const Color(0xFF333333) : Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceLogo({
    required String? logoUrl,
    required String? iconName,
    required double size,
    Color? iconColor,
  }) {
    // Vérifier si on a une URL de logo
    if (logoUrl != null && logoUrl.isNotEmpty) {
      // Déterminer le type de fichier
      final lowercaseUrl = logoUrl.toLowerCase();

      if (lowercaseUrl.endsWith('.svg')) {
        // Afficher SVG
        return SvgPicture.network(
          Uri.encodeFull(logoUrl),
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => Icon(
            IconUtils.getIconData(iconName ?? 'business_center'),
            size: size,
            color: iconColor ?? AppConfig.primaryColor,
          ),
          errorBuilder: (context, error, stackTrace) => Icon(
            IconUtils.getIconData(iconName ?? 'business_center'),
            size: size,
            color: iconColor ?? AppConfig.primaryColor,
          ),
        );
      } else {
        // Afficher PNG/JPG
        return Image.network(
          Uri.encodeFull(logoUrl),
          width: size,
          height: size,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    iconColor ?? AppConfig.primaryColor,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Icon(
            IconUtils.getIconData(iconName ?? 'business_center'),
            size: size,
            color: iconColor ?? AppConfig.primaryColor,
          ),
        );
      }
    } else {
      // Pas de logo, afficher l'icône par défaut
      return Icon(
        IconUtils.getIconData(iconName ?? 'business_center'),
        size: size,
        color: iconColor ?? AppConfig.primaryColor,
      );
    }
  }

  Widget _buildLoadingScreen(AppDataProvider appDataProvider) {
    return Scaffold(
      backgroundColor: const Color(0xFF006699),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF006699),
              Color(0xFF004466),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Interface de base (optionnel - structure vide)
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: const Color(0xFF006699),
                elevation: 0,
                title: Row(
                  children: [
                    Image.asset(
                      'assets/wortisapp.png',
                      height: 50,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'W',
                              style: TextStyle(
                                color: Color(0xFF006699),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(40)),
                ),
              ),
              body: const SizedBox.shrink(),
            ),

            // Overlay de chargement - REMPLACÉ PAR LoadingOverlay
            LoadingOverlay(
              mainText: 'Chargement des données',
              subText: 'Préparation de votre espace personnel',
              isVisible: true,
            ),

            // Pop-up de timeout
            if (_showTimeoutPopup)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          color: Colors.orange,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Problème de connexion',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Vérifiez votre connexion internet et réessayez',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showTimeoutPopup = false;
                            });
                            _loadingTimeoutTimer?.cancel();
                            _loadingTimeoutTimer = null;
                            // Forcer le rechargement des données
                            appDataProvider.refreshAllData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006699),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Réessayer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilesWidget(BuildContext context) {
    return Consumer<AppDataProvider>(
      builder: (context, provider, child) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF006699), Color(0xFF006699)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mes Miles',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () => provider.refreshMiles(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeInOut,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: provider.milesLoading
                      ? Container(
                          key: const ValueKey('loading'),
                          height: 24,
                          alignment: Alignment.centerLeft,
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : Container(
                          key: ValueKey<int>(provider.miles),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${NumberFormat("#,###", "fr_FR").format(provider.miles).replaceAll(',', ' ')} Mls',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Les autres méthodes restent identiques (construction secteurs, search, navigation, etc.)
  // Je vais seulement inclure les méthodes essentielles pour éviter la répétition

  // Redirection vers service
  Future<void> _redirectToService(Map<String, dynamic> service) async {
    print(service);
    if (!mounted || !context.mounted) return;

    // Logique de redirection selon le type et secteur
    final serviceType = service['Type_Service']?.toString();
    final secteurActivite = service['SecteurActivite']?.toString();

    // Nouveau : Vérifier si c'est un service "Service Internet"
    if (secteurActivite == "Service Internet") {
      // Service Internet → WebView avec paramètres
      await _openInternetServiceWebView(service);
    } else if (serviceType == "WebView") {
      // Type WebView → ServiceWebView classique
      Navigator.push(
        context,
        ServicePageTransitionDias(
          page: ServiceWebView(
            url: service['link_view'] ?? '',
          ),
        ),
      );
    } else if (serviceType == "Catalog") {
      // Type Catalog → CatalogService
      await SessionManager.checkSessionAndNavigate(
        context: context,
        authenticatedRoute: ServicePageTransitionDias(
          page: CatalogService(serviceName: service['name']),
        ),
        unauthenticatedRoute: const AuthentificationPage(),
      );
    } else {
      // Autres types → FormService
      await SessionManager.checkSessionAndNavigate(
        context: context,
        authenticatedRoute: ServicePageTransitionDias(
          page: FormService(serviceName: service['name']),
        ),
        unauthenticatedRoute: const AuthentificationPage(),
      );
    }
  }

  // Fonction pour construire l'URL complète
  Future<String> _buildCompleteServiceUrl({
    required String serviceName,
    required String token,
    required String countries,
    required String logo,
  }) async {
    try {
      // Étape 1: Vérifier l'API get_services_test
      //print('🔍 Vérification API get_services_test pour token: $token');

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/get_services_test/$token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout API get_services_test'),
      );

      //print('📊 Status Code: ${response.statusCode}');
      //print('📄 Response Body: ${response.body}');

      bool shouldUseWebView = true; // Par défaut = WebView normale

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Vérifier si la clé 'webview' existe et récupérer sa valeur
        if (responseData.containsKey('webview')) {
          final webviewValue = responseData['webview'];
          print(
              '🔑 Valeur webview trouvée: $webviewValue (${webviewValue.runtimeType})');

          // Conversion sécurisée en booléen
          if (webviewValue is bool) {
            shouldUseWebView = webviewValue;
          } else if (webviewValue is String) {
            shouldUseWebView = webviewValue.toLowerCase() == 'true';
          } else if (webviewValue is int) {
            shouldUseWebView = webviewValue == 1;
          } else {
            print(
                '⚠️ Type inattendu pour webview: ${webviewValue.runtimeType}');
            // Garder la valeur par défaut (true)
          }
        } else {
          //print('⚠️ Clé "webview" non trouvée dans la réponse');
          // Garder la valeur par défaut (true)
        }
      } else {
        //print('❌ Erreur HTTP ${response.statusCode}: ${response.reasonPhrase}');
        // Garder la valeur par défaut (true)
      }

      // Étape 2: Construire l'URL selon la réponse
      if (shouldUseWebView) {
        // webview: true → URL normale vers wortis.fr/famlink_apk
        //print('✅ webview: true → URL WebView normale');

        const baseUrl = "https://wortis.fr/famlink_apk";
        final uri = Uri.parse(baseUrl).replace(queryParameters: {
          'service': Uri.encodeComponent(serviceName),
          'token': token,
          'countries': Uri.encodeComponent(countries),
          'logo': Uri.encodeComponent(logo),
          'source': 'mobile_app',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        });

        return uri.toString();
      } else {
        // webview: false → URL spéciale pour indiquer WortisSubscriptionPage
        //print('📱 webview: false → Indicateur pour WortisSubscriptionPage');

        // Retourner une URL spéciale que l'appelant peut détecter
        return 'wortis://subscription?service=${Uri.encodeComponent(serviceName)}&token=$token&countries=${Uri.encodeComponent(countries)}&logo=${Uri.encodeComponent(logo)}&source=mobile_app&timestamp=${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      // Erreur: Retourner l'URL par défaut en cas de problème
      //print('❌ Erreur lors de la vérification webview: $e');
      //print('🔄 Utilisation de l\'URL par défaut');

      const baseUrl = "https://wortis.fr/famlink_apk";
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'service': Uri.encodeComponent(serviceName),
        'token': token,
        'countries': Uri.encodeComponent(countries),
        'logo': Uri.encodeComponent(logo),
        'source': 'mobile_app',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      return uri.toString();
    }
  }

  // Fonction _openInternetServiceWebView simplifiée
  Future<void> _openInternetServiceWebView(Map<String, dynamic> service) async {
    try {
      final token = await SessionManager.getToken();
      print(
          '############################ Token ############################ $token');

      if (token == null || token.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthentificationPage()),
        );
        return;
      }

      // Récupérer les infos service
      final serviceName = service['name'] ?? '';
      final eligibleCountries = service['eligible_countries'] ?? '';
      final logo = service['logo'] ?? '';

      // Appeler la fonction qui contient toute la logique
      final resultUrl = await _buildCompleteServiceUrl(
        serviceName: serviceName,
        token: token,
        countries: eligibleCountries,
        logo: logo,
      );

      //print('🔗 URL résultante: $resultUrl');

      // Analyser l'URL pour déterminer l'action
      if (resultUrl.startsWith('wortis://subscription')) {
        // URL spéciale → Ouvrir WortisSubscriptionPage
        //print('📱 Redirection vers WortisSubscriptionPage');

        final uri = Uri.parse(resultUrl);
        final params = {
          'service': uri.queryParameters['service'] ?? '',
          'token': uri.queryParameters['token'] ?? '',
          'countries': uri.queryParameters['countries'] ?? '',
          'logo': uri.queryParameters['logo'] ?? '',
          'source': uri.queryParameters['source'] ?? 'mobile_app',
          'timestamp': uri.queryParameters['timestamp'] ?? '',
        };

        Navigator.push(
          context,
          ServicePageTransitionDias(
            page: WortisSubscriptionPage(params: params),
          ),
        );
      } else {
        // URL normale → Ouvrir ServiceWebView
        //print('🌐 Ouverture ServiceWebView');

        Navigator.push(
          context,
          ServicePageTransitionDias(
            page: ServiceWebView(url: resultUrl),
          ),
        );
      }
    } catch (e) {
      //print('❌ Erreur Service Internet: $e');
      _showErrorSnackBar('Impossible d\'ouvrir le service Internet');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Construction des secteurs d'activité (méthode simplifiée)
  Widget _buildActivitySectors(AppDataProvider appDataProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              double screenWidth = MediaQuery.of(context).size.width;
              double spacing = screenWidth > 600 ? 16 : 8;
              double padding = screenWidth > 600 ? 16 : 8;
              double iconSize = screenWidth > 600 ? 30 : 24;
              double fontSize = screenWidth > 600 ? 12 : 10;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.all(padding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                ),
                itemCount: appDataProvider.secteurs.length,
                itemBuilder: (context, index) {
                  final secteur = appDataProvider.secteurs[index];
                  return GestureDetector(
                    onTap: () =>
                        _showSectorModal(context, secteur.name, secteur.icon),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildServiceLogo(
                            logoUrl: secteur.icon,
                            iconName: secteur.icon,
                            size: iconSize,
                            iconColor: AppConfig.primaryColor,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            secteur.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // Méthode _showSectorModal simplifiée
  void _showSectorModal(BuildContext context, String name, String icon) {
    final appDataProvider =
        Provider.of<AppDataProvider>(context, listen: false);

    final sectorServices = appDataProvider.services
        .where((service) =>
            (service as Map<String, dynamic>)['SecteurActivite'] == name)
        .map((service) => service as Map<String, dynamic>)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sectorServices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun service disponible\npour ce secteur',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: sectorServices.length,
                        itemBuilder: (context, index) {
                          return _buildServiceGridItem(sectorServices[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Méthodes simplifiées pour AppBar, Navigation, etc. (identiques aux versions précédentes)
  PreferredSizeWidget _buildAnimatedAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: AnimatedBuilder(
        animation: _bannerAnimationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -80 * (1 - _bannerAnimationController.value)),
            child: _buildAppBar(),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 80,
      backgroundColor: AppConfig.primaryColor,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: AppConfig.animationDuration,
            width: _isSearching ? 0 : 50,
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _isSearching ? 0.0 : 1.0,
              child: Image.asset(
                'assets/wortisapp.png',
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'W',
                        style: TextStyle(
                          color: AppConfig.primaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_isSearching)
            Expanded(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 800),
                offset: Offset(_isSearching ? 0.0 : 1.0, 0.0),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 800),
                  opacity: _isSearching ? 1.0 : 0.0,
                  child: _buildSearchField(),
                ),
              ),
            ),
        ],
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      actions: _buildAppBarActions(),
    );
  }

  List<Widget> _buildAppBarActions() {
    return _isTokenPresent
        ? [
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _filteredServices.clear();
                  });
                },
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
              Consumer<AppDataProvider>(
                builder: (context, provider, child) {
                  final unreadCount = provider.unreadNotificationsCount;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications,
                            color: Colors.white),
                        onPressed: () async {
                          final token = await SessionManager.getToken();
                          if (!context.mounted) return;

                          if (token != null) {
                            Navigator.push(
                              context,
                              CustomPageTransitionDias(
                                  page: const NotificationPage()),
                            ).then((_) {
                              if (mounted) {
                                Future.microtask(() {
                                  provider.refreshNotifications();
                                });
                              }
                            });
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AuthentificationPage(),
                              ),
                            );
                          }
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            // Logo pays
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: _showCountryModal,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _selectedFlag,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
            ),
          ]
        : [];
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _searchController,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher un service...',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[600],
            size: 24,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _filteredServices.clear();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        onChanged: (value) {
          setState(() {
            if (value.isEmpty) {
              _filteredServices.clear();
              _searchResultsController.reverse();
            } else {
              final appDataProvider =
                  Provider.of<AppDataProvider>(context, listen: false);
              if (value.length == 1) {
                // Afficher tous les services au premier caractère
                _filteredServices = appDataProvider.services
                    .map((service) => service as Map<String, dynamic>)
                    .where((service) => service['status'] ?? true)
                    .toList();
                _searchResultsController.forward();
              } else {
                // Filtrer par nom de service
                _filteredServices = appDataProvider.services
                    .map((service) => service as Map<String, dynamic>)
                    .where((service) {
                  final serviceName = service['name'].toString().toLowerCase();
                  final isActive = service['status'] ?? true;
                  return serviceName.contains(value.toLowerCase()) && isActive;
                }).toList();
              }
            }
          });
        },
      ),
    );
  }

  Widget _buildBannerSlider(AppDataProvider appDataProvider) {
    if (appDataProvider.banners.isEmpty) {
      return _buildEmptyBannerSlider();
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: PageView.builder(
                controller: _pageController,
                itemCount: appDataProvider.banners.length,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  final banner = appDataProvider.banners[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: Colors.grey[200]),
                        Image.network(
                          Uri.encodeFull(banner.imageUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.error_outline,
                                    color: Colors.red, size: 40),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              appDataProvider.banners.length,
                              (i) => Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                width: i == index ? 16 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: i == index
                                      ? const Color(0xFF006699)
                                      : Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyBannerSlider() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF006699)),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Chargement...",
                      style: TextStyle(
                        color: Color(0xFF006699),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAnimatedSearchOverlay() {
    return ScaleTransition(
      scale: _searchResultsScale,
      child: FadeTransition(
        opacity: _searchResultsOpacity,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Résultats de la recherche',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          _searchResultsController.reverse().then((_) {
                            setState(() {
                              _isSearching = false;
                              _searchController.clear();
                              _filteredServices.clear();
                            });
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_filteredServices.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.white70,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Aucun résultat trouvé',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.only(top: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _filteredServices.length,
                        itemBuilder: (context, index) {
                          final service = _filteredServices[index];
                          return _buildSearchResultItem(service);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> service) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          if (!mounted) return;

          setState(() {
            _searchController.text = service['name'];
            _filteredServices.clear();
            _isSearching = false;
          });

          if (!mounted) return;

          if (service['Type_Service'] == "WebView") {
            if (mounted && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServiceWebView(
                    url: service['link_view'] ?? '',
                  ),
                ),
              );
            }
          } else if (service['Type_Service'] == "Catalog") {
            if (mounted && context.mounted) {
              await SessionManager.checkSessionAndNavigate(
                context: context,
                authenticatedRoute: ServicePageTransitionDias(
                  page: CatalogService(serviceName: service['name']),
                ),
                unauthenticatedRoute: const AuthentificationPage(),
              );
            }
          } else if (service['Type_Service'] == "ReservationService") {
            if (mounted && context.mounted) {
              await SessionManager.checkSessionAndNavigate(
                context: context,
                authenticatedRoute: ServicePageTransitionDias(
                  page: ReservationService(serviceName: service['name']),
                ),
                unauthenticatedRoute: const AuthentificationPage(),
              );
            }
          } else {
            if (mounted && context.mounted) {
              await SessionManager.checkSessionAndNavigate(
                context: context,
                authenticatedRoute: ServicePageTransitionDias(
                  page: FormService(serviceName: service['name']),
                ),
                unauthenticatedRoute: const AuthentificationPage(),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: _buildServiceLogo(
                  logoUrl: service['logo']?.toString(),
                  iconName: service['icon'] ?? 'business_center',
                  size: 28,
                  iconColor: AppConfig.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  service['name'] ?? 'Service',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryModal() {
    if (_availableCountries.isEmpty) {
      _showSnackBar("Aucun pays disponible");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      ),
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * 400),
            child: Opacity(
              opacity: value,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppConfig.primaryColor, Color(0xFF004d7a)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sélectionnez votre zone',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _availableCountries.length,
                        itemBuilder: (context, index) {
                          final country = _availableCountries[index];
                          final isSelected =
                              country['name'] == _selectedCountry;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    country['flag'],
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              title: Text(
                                country['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    country['dialCode'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                ],
                              ),
                              onTap: () async {
                                if (mounted &&
                                    country['name'] != _selectedCountry) {
                                  Navigator.pop(context);

                                  // Utiliser _handleCountryChange au lieu de _updateUserZone
                                  await _handleCountryChange(country['name']);

                                  // Mettre à jour l'affichage local
                                  setState(() {
                                    _selectedFlag = country['flag'];
                                    _selectedDialCode = country['dialCode'];
                                  });
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Méthode principale pour changer de pays
  Future<void> _handleCountryChange(String newCountry) async {
    if (_isCountryChanging || newCountry == _selectedCountry) return;

    //print('🌍 [HomePage] Changement de pays: $_selectedCountry → $newCountry');

    // Récupérer le code du pays une seule fois
    final selectedCountryData = _availableCountries.firstWhere(
      (country) => country["name"] == newCountry,
      orElse: () => {},
    );

    final countryCode = selectedCountryData["code"] as String? ?? '';

    if (countryCode.isEmpty) {
      _showCountryChangeError('Code pays non trouvé pour: $newCountry');
      return;
    }

    setState(() {
      _isCountryChanging = true;
      _showCountryChangeOverlay = true;
      _newSelectedCountry = newCountry;
      _currentStep = 0;
    });

    try {
      // Étape 1: Mise à jour via API
      await _updateProgressStep(0, 'Mise à jour du serveur...');
      await _updateUserZoneViaAPI(newCountry, countryCode);

      // Étape 2: Sauvegarde locale (utiliser countryCode déjà récupéré)
      await _updateProgressStep(1, 'Sauvegarde locale...');
      await ZoneBenefManager.saveZoneBenef(countryCode);

      // Étape 3: Rechargement des données
      await _updateProgressStep(2, 'Rechargement des données...');
      await _reloadPageDataForNewCountry(newCountry);

      // Étape 4: Finalisation
      await _updateProgressStep(3, 'Finalisation...');
      setState(() {
        _selectedCountry = newCountry;
      });

      // Petit délai pour voir la completion
      await Future.delayed(const Duration(milliseconds: 800));

      // Masquer l'overlay avant redirection
      if (mounted) {
        setState(() {
          _isCountryChanging = false;
          _showCountryChangeOverlay = false;
          _newSelectedCountry = null;
          _currentStep = 0;
        });
      }

      // Attendre que l'overlay disparaisse
      await Future.delayed(const Duration(milliseconds: 500));

      // Redirection intelligente
      if (mounted && context.mounted) {
        if (countryCode.toUpperCase() == 'CG') {
          // Congo → HomePage original
          //print('🇨🇬 Redirection vers HomePage (Congo - CG)');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                  routeObserver:
                      widget.routeObserver ?? RouteObserver<PageRoute>()),
            ),
            (route) => false,
          );
        } else {
          // Autres pays → Rester sur HomePageDias et afficher succès
          //print('🌍 Reste sur HomePageDias (Code: $countryCode)');
          _showCountryChangeSuccess(newCountry);
        }
      }
    } catch (e) {
      //print('❌ [HomePage] Erreur changement pays: $e');
      _showCountryChangeError(e.toString());

      // Masquer overlay en cas d'erreur
      if (mounted) {
        setState(() {
          _isCountryChanging = false;
          _showCountryChangeOverlay = false;
          _newSelectedCountry = null;
          _currentStep = 0;
        });
      }
    }
  }

  void _showCountryChangeError(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Erreur: $error',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _updateProgressStep(int step, String message) async {
    if (mounted) {
      setState(() {
        _currentStep = step;
      });
    }

    //print('📋 [HomePage] Étape $step: $message');

    // Délai pour voir la progression
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Mise à jour via API
  Future<void> _updateUserZoneViaAPI(
      String newCountry, String countryCode) async {
    try {
      final token = await SessionManager.getToken();
      if (token == null) {
        throw Exception('Token non trouvé');
      }

      //print('📡 [HomePage] Appel API update_user_zone');
      //print('🔑 Token: $token');
      //print('🌍 Zone: $newCountry');
      //print('🏷️ Code: $countryCode');

      final result = await ZoneUpdateService.updateUserZone(
          token, newCountry, countryCode);

      if (result['success']) {
        //print('✅ Zone mise à jour avec succès via API');

        if (result.containsKey('user')) {
          await _updateLocalUserInfo(result['user']);
        }
      } else {
        throw Exception(result['message'] ?? 'Erreur serveur');
      }
    } catch (e) {
      //print('❌ [HomePage] Erreur API update_user_zone: $e');
      rethrow;
    }
  }

  Future<void> _prioritizeStoredCountryInList() async {
    try {
      // 1. Récupérer le code pays stocké
      final storedCountryCode = await ZoneBenefManager.getZoneBenef();

      if (storedCountryCode == null ||
          storedCountryCode.isEmpty ||
          _availableCountries.isEmpty) {
        //print('⚠️ [HomePage] Aucun pays stocké ou liste vide');
        return;
      }

      //print('🔍 [HomePage] Code pays stocké: $storedCountryCode');

      // 2. Trouver le pays correspondant dans la liste
      final storedCountryIndex = _availableCountries.indexWhere((country) =>
          country["code"]?.toUpperCase() == storedCountryCode.toUpperCase());

      if (storedCountryIndex != -1) {
        // 3. Extraire le pays trouvé
        final storedCountry = _availableCountries[storedCountryIndex];

        // 4. Réorganiser la liste : pays stocké en premier
        final reorganizedList = <Map<String, dynamic>>[];

        // Ajouter le pays stocké en premier
        reorganizedList.add(storedCountry);

        // Ajouter tous les autres pays (en excluant celui déjà ajouté)
        for (int i = 0; i < _availableCountries.length; i++) {
          if (i != storedCountryIndex) {
            reorganizedList.add(_availableCountries[i]);
          }
        }

        // 5. Remplacer la liste et mettre à jour la sélection
        setState(() {
          _availableCountries = reorganizedList;
          _selectedCountry = storedCountry["name"];
          _selectedFlag = storedCountry["flag"];
          _selectedDialCode = storedCountry["dialCode"];
        });

        print(
            '✅ [HomePage] ${storedCountry["name"]} ${storedCountry["flag"]} mis en premier');
      } else {
        //print('⚠️ [HomePage] Pays stocké non trouvé dans la liste éligible');
      }
    } catch (e) {
      //print('❌ [HomePage] Erreur priorité pays stocké: $e');
    }
  }

  // Mise à jour des infos utilisateur locales
  Future<void> _updateLocalUserInfo(Map<String, dynamic> updatedUser) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingInfosJson = prefs.getString('user_infos');
      Map<String, dynamic> userInfos = {};

      if (existingInfosJson != null) {
        userInfos = jsonDecode(existingInfosJson);
      }

      userInfos.addAll(updatedUser);
      await prefs.setString('user_infos', jsonEncode(userInfos));

      //print('💾 [HomePage] Infos utilisateur mises à jour localement');
    } catch (e) {
      //print('❌ [HomePage] Erreur mise à jour infos locales: $e');
    }
  }

  // Rechargement des données de la page
  Future<void> _reloadPageDataForNewCountry(String newCountry) async {
    try {
      print(
          '🔄 [HomePage] Rechargement OPTIMISÉ des données pour: $newCountry');

      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);

      // 1. RECHARGEMENT COMPLET avec initializeApp()
      //print('📦 [HomePage] Initialisation complète du DataProvider...');
      await appDataProvider.initializeApp(context).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print(
              '⚠️ [HomePage] Timeout DataProvider - continuation avec données partielles');
        },
      );

      // 2. SEULEMENT recharger les MILES (pas inclus dans initializeApp)
      //print('🏃 [HomePage] Rechargement miles utilisateur...');
      await appDataProvider.refreshMiles().timeout(
            const Duration(seconds: 3),
            onTimeout: () => print('⚠️ [HomePage] Timeout miles'),
          );

      // 3. METTRE À JOUR L'UI avec toutes les nouvelles données
      if (mounted) {
        setState(() {
          // Force la reconstruction avec toutes les nouvelles données
        });

        // Recharger aussi la liste des pays disponibles pour le sélecteur
        _buildAvailableCountriesList(appDataProvider);
        _filterServicesByCountry(appDataProvider);

        // Resélectionner les services aléatoirement
        _selectRandomServices();
      }

      //print('✅ [HomePage] TOUTES les données rechargées pour: $newCountry');
      //print('📊 Statistiques après rechargement:');
      //print('  - Bannières: ${appDataProvider.banners.length}');
      //print('  - Services: ${appDataProvider.services.length}');
      //print('  - Secteurs: ${appDataProvider.secteurs.length}');
      //print('  - Pays éligibles: ${appDataProvider.eligibleCountries.length}');
      //print('  - Miles: ${appDataProvider.miles}');
      //print('  - Notifications: ${appDataProvider.notifications.length}');
    } catch (e) {
      //print('❌ [HomePage] Erreur rechargement optimisé: $e');

      // En cas d'erreur, au moins essayer le minimum
      try {
        final appDataProvider =
            Provider.of<AppDataProvider>(context, listen: false);
        await appDataProvider.refreshAll();
        if (mounted) setState(() {});
      } catch (fallbackError) {
        //print('❌ [HomePage] Erreur fallback: $fallbackError');
      }

      rethrow;
    }
  }

  // Messages de feedback
  void _showCountryChangeSuccess(String newCountry) {
    if (!mounted) return;

    final selectedCountryData = _availableCountries.firstWhere(
      (country) => country["name"] == newCountry,
      orElse: () => {},
    );

    final flag = selectedCountryData["flag"] ?? "🌍";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                newCountry,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Widget overlay transparent
  Widget _buildCountryChangeOverlay() {
    if (!_showCountryChangeOverlay) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animation de chargement
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF006699).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF006699)),
                    strokeWidth: 3,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Titre
              const Text(
                'Changement de pays',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                'Mise à jour vers ${_newSelectedCountry ?? "nouveau pays"}...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Étapes de progression
              _buildProgressSteps(),
            ],
          ),
        ),
      ),
    );
  }

  // Étapes de progression
  Widget _buildProgressSteps() {
    return Column(
      children: _progressSteps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = index < _currentStep;
        final isCurrent = index == _currentStep;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : isCurrent
                          ? const Color(0xFF006699)
                          : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : isCurrent
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            )
                          : Container(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step,
                  style: TextStyle(
                    fontSize: 13,
                    color: isCompleted || isCurrent
                        ? const Color(0xFF2D3748)
                        : Colors.grey[500],
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavBarItem(0, Icons.list, "Services", () {
                _animateNavItemAndNavigate(0, const AllServicesPage());
              }),
              _buildNavBarItem(1, Icons.article, "Actualités", () {
                _animateNavItemAndNavigate(1, const NewsPage());
              }),
              _buildNavBarItem(2, Icons.history, "Historique", () {
                _animateNavItemAndNavigate(
                    2,
                    const TransactionHistoryPage(
                        sourcePageType: 'homepage_dias'));
              }),
              _buildNavBarItem(3, Icons.person, "Compte", () {
                _animateNavItemAndNavigate(3, const MonComptePage());
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(
      int index, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _navItemBounceAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween<double>(
                    begin: 1.0,
                    end: 1.0,
                  ),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFF006699),
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF006699),
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConfig.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
