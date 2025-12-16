// ignore_for_file: unused_field, deprecated_member_use, unused_element, library_private_types_in_public_api
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/class/dataprovider.dart';
import 'package:wortis/pages/homepage_dias.dart';

// Configuration constants
class AppConfig {
  static const primaryColor = Color(0xFF006699);
  static const animationDuration = Duration(milliseconds: 300);
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
}

class WelcomeZoneSelectionPage extends StatefulWidget {
  final String userName;
  final Function(Map<String, dynamic>) onZoneSelected;

  const WelcomeZoneSelectionPage({
    super.key,
    required this.userName,
    required this.onZoneSelected,
  });

  @override
  _WelcomeZoneSelectionPageState createState() =>
      _WelcomeZoneSelectionPageState();
}

class _WelcomeZoneSelectionPageState extends State<WelcomeZoneSelectionPage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedZone;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredZones = [];
  List<Map<String, dynamic>> _zones = [];
  bool _isSearching = false;

  // Animation controllers
  late AnimationController _welcomeAnimationController;
  late AnimationController _logoAnimationController;
  late AnimationController _listAnimationController;
  late AnimationController _buttonAnimationController;
  late AnimationController _searchAnimationController;

  // Animations
  late Animation<double> _welcomeFadeAnimation;
  late Animation<Offset> _welcomeSlideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _listFadeAnimation;
  late Animation<Offset> _listSlideAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _searchFadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
    _searchController.addListener(_onSearchChanged);
    _initializeAnimationControllers();
    _configureAnimations();

    // ========== CHARGEMENT UNIFIÉ POUR TOUS LES FLUX ==========
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureUnifiedDataLoading();
    });
  }

  void _initializeAnimationControllers() {
    _welcomeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void _configureAnimations() {
    _welcomeFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _welcomeAnimationController,
      curve: Curves.easeOut,
    ));

    _welcomeSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _welcomeAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    _logoRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeInOut,
    ));

    _listFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _listAnimationController,
      curve: Curves.easeIn,
    ));

    _listSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _listAnimationController,
      curve: Curves.easeOutQuart,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeInOut,
    ));

    _searchFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeIn,
    ));
  }

  Future<void> _startAnimationSequence() async {
    if (mounted) {
      _logoAnimationController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _welcomeAnimationController.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _listAnimationController.forward();
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _searchAnimationController.forward();
    }
  }

  // ========== NOUVEAU : Chargement unifié pour tous les flux d'inscription ==========

  // ========== NOUVEAU : Chargement unifié pour tous les flux d'inscription ==========
  Future<void> _ensureUnifiedDataLoading() async {
    try {
      setState(() {
        _isLoading = true;
      });

      print('🔄 [Welcome] Chargement unifié des données...');

      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);

      // ========== ÉTAPE 1: FORCER LE RECHARGEMENT COMPLET SI NÉCESSAIRE ==========
      if (appDataProvider.eligibleCountries.isEmpty ||
          appDataProvider.services.isEmpty) {
        print(
            '📡 [Welcome] Données incomplètes détectées, rechargement complet...');

        try {
          await appDataProvider
              .initializeApp(context)
              .timeout(const Duration(seconds: 12), onTimeout: () {
            print(
                '⚠️ [Welcome] Timeout rechargement complet - continuation partielle');
          });
          print('✅ [Welcome] Rechargement complet terminé');
        } catch (e) {
          print('⚠️ [Welcome] Erreur rechargement complet (non-critique): $e');
        }
      }

      // ========== ÉTAPE 2: TENTATIVE DE CHARGEMENT SPÉCIFIQUE DES PAYS ==========
      if (appDataProvider.eligibleCountries.isEmpty) {
        print(
            '📍 [Welcome] Tentative de chargement spécifique des pays éligibles...');

        try {
          await appDataProvider
              .loadEligibleCountries()
              .timeout(const Duration(seconds: 8), onTimeout: () {
            print('⚠️ [Welcome] Timeout pays éligibles - utilisation fallback');
          });
          print(
              '✅ [Welcome] Chargement spécifique pays terminé: ${appDataProvider.eligibleCountries.length}');
        } catch (e) {
          print('⚠️ [Welcome] Erreur chargement pays spécifique: $e');
        }
      }

      // ========== ÉTAPE 3: CHARGEMENT DES ZONES ==========
      await _loadZonesWithUnifiedFallback();

      setState(() {
        _isLoading = false;
      });

      // Démarrer les animations après chargement
      _startAnimationSequence();
    } catch (e) {
      print('❌ [Welcome] Erreur chargement unifié: $e');
      setState(() {
        _isLoading = false;
      });
      _useUniversalDefaultZones();
      _startAnimationSequence();
    }
  }

// ========== MÉTHODE DE CHARGEMENT AVEC FALLBACK UNIFIÉ ==========
  Future<void> _loadZonesWithUnifiedFallback() async {
    try {
      print('🌍 [Welcome] Chargement zones avec fallback unifié...');

      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);
      final eligibleCountries = appDataProvider.eligibleCountries;

      print(
          '📋 [Welcome] Pays éligibles disponibles: ${eligibleCountries.length}');

      _zones.clear();

      if (eligibleCountries.isNotEmpty) {
        // ========== MAPPING AVEC PAYS DE L'API ==========
        await _mapCountriesFromAPI(eligibleCountries);
      }

      // ========== FALLBACK UNIFIÉ SI PAS ASSEZ DE PAYS ==========
      if (_zones.length < 8) {
        // Seuil minimum pour une bonne expérience
        print(
            '⚠️ [Welcome] Pas assez de pays (${_zones.length}), ajout de pays supplémentaires...');
        _addEssentialCountries();
      }

      // ========== ASSURER LES PAYS CRITIQUES ==========
      // _ensureCriticalCountries();

      // ========== TRI FINAL ==========
      _sortZonesByRegionAndName();

      setState(() {
        _filteredZones = List.from(_zones);
      });

      print(
          '✅ [Welcome] ${_zones.length} zones finales avec drapeaux et noms complets');
    } catch (e) {
      print('❌ [Welcome] Erreur chargement avec fallback: $e');
      _useUniversalDefaultZones();
    }
  }

// ========== MAPPING AMÉLIORÉ AVEC L'API ==========
  Future<void> _mapCountriesFromAPI(List<String> eligibleCountries) async {
    for (String countryIdentifier in eligibleCountries) {
      Country? matchingCountry;

      // Essai 1: Par code pays (2 lettres)
      if (countryIdentifier.length == 2) {
        matchingCountry = countries.firstWhere(
          (country) =>
              country.code.toUpperCase() == countryIdentifier.toUpperCase(),
          orElse: () => const Country(
              name: '', code: '', dialCode: '', flag: '', region: ''),
        );
      }

      // Essai 2: Par nom si pas trouvé
      if (matchingCountry?.name.isEmpty ?? true) {
        matchingCountry = countries.firstWhere(
          (country) => _isCountryMatch(country.name, countryIdentifier),
          orElse: () => const Country(
              name: '', code: '', dialCode: '', flag: '', region: ''),
        );
      }

      if (matchingCountry?.name.isNotEmpty ?? false) {
        // Éviter les doublons
        bool alreadyExists =
            _zones.any((zone) => zone['code'] == matchingCountry!.code);
        if (!alreadyExists) {
          _zones.add({
            "name": matchingCountry!.name,
            "flag": matchingCountry.flag,
            "dialCode": matchingCountry.dialCode,
            "region": matchingCountry.region,
            "code": matchingCountry.code,
          });

          print(
              '✅ [Welcome] API→Zone: ${matchingCountry.name} ${matchingCountry.flag} (${matchingCountry.code})');
        }
      } else {
        print('⚠️ [Welcome] Pays API non mappé: $countryIdentifier');
      }
    }
  }

// ========== AJOUT DES PAYS ESSENTIELS MANQUANTS ==========
  void _addEssentialCountries() {
    final essentialCountries = [
      'CG',
      'CD',
      'CM',
      'GA',
      'CF',
      'TD',
      'SN',
      'CI',
      'ML',
      'BF',
      'GH',
      'NG',
      'BJ',
      'TG',
      'FR',
      'BE',
      'CH',
      'CA',
      'MA',
      'TN'
    ];

    for (String code in essentialCountries) {
      // Vérifier si déjà présent
      bool exists = _zones.any((zone) => zone['code'] == code);
      if (!exists) {
        final country = countries.firstWhere(
          (c) => c.code == code,
          orElse: () => const Country(
              name: '', code: '', dialCode: '', flag: '', region: ''),
        );

        if (country.name.isNotEmpty) {
          _zones.add({
            "name": country.name,
            "flag": country.flag,
            "dialCode": country.dialCode,
            "region": country.region,
            "code": country.code,
          });
          print(
              '➕ [Welcome] Pays essentiel ajouté: ${country.name} ${country.flag}');
        }
      }
    }
  }

// ========== TRI AMÉLIORÉ ==========
  void _sortZonesByRegionAndName() {
    _zones.sort((a, b) {
      // Congo toujours en premier
      if (a["code"] == "CG") return -1;
      if (b["code"] == "CG") return 1;

      // Puis par région
      int regionComparison = a["region"].compareTo(b["region"]);
      if (regionComparison != 0) return regionComparison;

      // Puis par nom
      return a["name"].compareTo(b["name"]);
    });
  }

  bool _isCountryMatch(String countryFromList, String countryFromAPI) {
    String normalize(String name) {
      return name
          .toLowerCase()
          .replaceAll(RegExp(r'[àáâãäå]'), 'a')
          .replaceAll(RegExp(r'[èéêë]'), 'e')
          .replaceAll(RegExp(r'[ìíîï]'), 'i')
          .replaceAll(RegExp(r'[òóôõö]'), 'o')
          .replaceAll(RegExp(r'[ùúûü]'), 'u')
          .replaceAll(RegExp(r'[ç]'), 'c')
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    String normalizedFromList = normalize(countryFromList);
    String normalizedFromAPI = normalize(countryFromAPI);

    if (normalizedFromList == normalizedFromAPI) return true;

    Map<String, List<String>> specialCases = {
      'congo': ['congo', 'republicofcongo', 'congobrazzaville'],
      'congordc': [
        'congordc',
        'democraticrepublicofcongo',
        'congokinshasa',
        'rdc'
      ],
      'cotedivoire': ['cotedivoire', 'ivorycoast'],
      'etatsunis': ['etatsunis', 'unitedstates', 'usa', 'us'],
      'royaumeuni': ['royaumeuni', 'unitedkingdom', 'uk', 'grandebretagne'],
    };

    for (String key in specialCases.keys) {
      if (specialCases[key]!.contains(normalizedFromList) &&
          specialCases[key]!.contains(normalizedFromAPI)) {
        return true;
      }
    }

    return false;
  }

  // ========== FALLBACK UNIVERSEL (utilisé en cas d'échec total) ==========
  void _useUniversalDefaultZones() {
    _zones = [
      // Afrique Centrale
      {
        "name": "Congo",
        "flag": "🇨🇬",
        "dialCode": "+242",
        "region": "Afrique Centrale",
        "code": "CG"
      },
      {
        "name": "République Démocratique du Congo",
        "flag": "🇨🇩",
        "dialCode": "+243",
        "region": "Afrique Centrale",
        "code": "CD"
      },
      {
        "name": "Cameroun",
        "flag": "🇨🇲",
        "dialCode": "+237",
        "region": "Afrique Centrale",
        "code": "CM"
      },
      {
        "name": "Gabon",
        "flag": "🇬🇦",
        "dialCode": "+241",
        "region": "Afrique Centrale",
        "code": "GA"
      },
      {
        "name": "République Centrafricaine",
        "flag": "🇨🇫",
        "dialCode": "+236",
        "region": "Afrique Centrale",
        "code": "CF"
      },
      {
        "name": "Tchad",
        "flag": "🇹🇩",
        "dialCode": "+235",
        "region": "Afrique Centrale",
        "code": "TD"
      },

      // Afrique de l'Ouest
      {
        "name": "Sénégal",
        "flag": "🇸🇳",
        "dialCode": "+221",
        "region": "Afrique de l'Ouest",
        "code": "SN"
      },
      {
        "name": "Côte d'Ivoire",
        "flag": "🇨🇮",
        "dialCode": "+225",
        "region": "Afrique de l'Ouest",
        "code": "CI"
      },
      {
        "name": "Mali",
        "flag": "🇲🇱",
        "dialCode": "+223",
        "region": "Afrique de l'Ouest",
        "code": "ML"
      },
      {
        "name": "Burkina Faso",
        "flag": "🇧🇫",
        "dialCode": "+226",
        "region": "Afrique de l'Ouest",
        "code": "BF"
      },
      {
        "name": "Ghana",
        "flag": "🇬🇭",
        "dialCode": "+233",
        "region": "Afrique de l'Ouest",
        "code": "GH"
      },
      {
        "name": "Nigeria",
        "flag": "🇳🇬",
        "dialCode": "+234",
        "region": "Afrique de l'Ouest",
        "code": "NG"
      },
      {
        "name": "Bénin",
        "flag": "🇧🇯",
        "dialCode": "+229",
        "region": "Afrique de l'Ouest",
        "code": "BJ"
      },
      {
        "name": "Togo",
        "flag": "🇹🇬",
        "dialCode": "+228",
        "region": "Afrique de l'Ouest",
        "code": "TG"
      },

      // Europe
      {
        "name": "France",
        "flag": "🇫🇷",
        "dialCode": "+33",
        "region": "Europe",
        "code": "FR"
      },
      {
        "name": "Belgique",
        "flag": "🇧🇪",
        "dialCode": "+32",
        "region": "Europe",
        "code": "BE"
      },
      {
        "name": "Suisse",
        "flag": "🇨🇭",
        "dialCode": "+41",
        "region": "Europe",
        "code": "CH"
      },
      {
        "name": "Allemagne",
        "flag": "🇩🇪",
        "dialCode": "+49",
        "region": "Europe",
        "code": "DE"
      },
      {
        "name": "Espagne",
        "flag": "🇪🇸",
        "dialCode": "+34",
        "region": "Europe",
        "code": "ES"
      },
      {
        "name": "Italie",
        "flag": "🇮🇹",
        "dialCode": "+39",
        "region": "Europe",
        "code": "IT"
      },

      // Amérique du Nord
      {
        "name": "Canada",
        "flag": "🇨🇦",
        "dialCode": "+1",
        "region": "Amérique du Nord",
        "code": "CA"
      },
      {
        "name": "États-Unis",
        "flag": "🇺🇸",
        "dialCode": "+1",
        "region": "Amérique du Nord",
        "code": "US"
      },

      // Afrique du Nord
      {
        "name": "Maroc",
        "flag": "🇲🇦",
        "dialCode": "+212",
        "region": "Afrique du Nord",
        "code": "MA"
      },
      {
        "name": "Tunisie",
        "flag": "🇹🇳",
        "dialCode": "+216",
        "region": "Afrique du Nord",
        "code": "TN"
      },
      {
        "name": "Algérie",
        "flag": "🇩🇿",
        "dialCode": "+213",
        "region": "Afrique du Nord",
        "code": "DZ"
      },
    ];

    _sortZonesByRegionAndName();

    setState(() {
      _filteredZones = List.from(_zones);
    });

    print('🛡️ [Welcome] Fallback universel activé (${_zones.length} pays)');
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredZones = List.from(_zones);
      } else {
        _filteredZones = _zones.where((zone) {
          return zone["name"].toLowerCase().contains(query) ||
              zone["region"].toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _selectZone(Map<String, dynamic> zone) {
    setState(() {
      _selectedZone = zone;
    });

    HapticFeedback.selectionClick();
    print('🎯 Zone sélectionnée: ${zone["name"]}');
  }

  Future<void> _confirmSelection() async {
    if (_selectedZone == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Récupérer le token utilisateur
      final token = await SessionManager.getToken();
      if (token == null) {
        throw Exception('Token utilisateur non trouvé');
      }

      print(
          '🔄 [Welcome] Définition de la zone bénéficiaire: ${_selectedZone!["name"]}');

      // 2. Appel API pour mettre à jour la zone
      final response = await http
          .post(
            Uri.parse('$baseUrl/update_user_zone'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': token,
              'zone_benef': _selectedZone!["name"],
              'zone_benef_code': _selectedZone!["code"],
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 [Welcome] Réponse API: ${response.statusCode}');
      print('📡 [Welcome] Information Zone : $_selectedZone');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['Code'] == 200) {
          // 3. Sauvegarder localement
          await ZoneBenefManager.saveZoneBenef(_selectedZone!['code']);

          print('✅ [Welcome] Zone bénéficiaire définie avec succès');

          // 4. ========== NOUVEAU : RECHARGEMENT DES DONNÉES POUR LA NOUVELLE ZONE ==========
          final appDataProvider =
              Provider.of<AppDataProvider>(context, listen: false);
          try {
            print(
                '🔄 [Welcome] Rechargement des données pour la nouvelle zone...');
            await appDataProvider
                .initializeApp(context)
                .timeout(const Duration(seconds: 8), onTimeout: () {
              print(
                  '⚠️ [Welcome] Timeout rechargement données zone - continuation');
            });
            print('✅ [Welcome] Données rechargées pour la nouvelle zone');
          } catch (e) {
            print('⚠️ [Welcome] Erreur rechargement données zone: $e');
          }

          // 5. Afficher message de succès
          if (mounted) {
            CustomOverlay.showInfo(context,
                message:
                    "Parfait ! Vous pouvez maintenant aider vos proches au ${_selectedZone!["name"]}");
          }

          // 6. Redirection vers homepage_dias
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePageDias(),
              ),
              (route) => false,
            );
          }
        } else {
          throw Exception(
              responseData['message'] ?? 'Erreur lors de la mise à jour');
        }
      } else {
        final responseData = json.decode(response.body);
        print("Message erreur : $responseData['message']");
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [Welcome] Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > AppConfig.tabletBreakpoint;
    final isMobile = screenSize.width < AppConfig.mobileBreakpoint;

    return Scaffold(
      backgroundColor: AppConfig.primaryColor,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF006699),
              Color(0xFF004466),
              Color(0xFF002233),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // En-tête avec logo et titre
              _buildHeader(isTablet, isMobile),

              // Zone de recherche
              _buildSearchSection(isTablet, isMobile),

              // Liste des zones
              _buildZonesList(isTablet, isMobile),

              // Bouton de confirmation
              _buildConfirmButton(isTablet, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet, bool isMobile) {
    return SlideTransition(
      position: _welcomeSlideAnimation,
      child: FadeTransition(
        opacity: _welcomeFadeAnimation,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            children: [
              SizedBox(height: isMobile ? 16 : 24),

              // Message de bienvenue
              Text(
                'Bienvenue ${widget.userName}!',
                style: TextStyle(
                  fontSize: isMobile ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isMobile ? 8 : 12),

              Text(
                'Choisissez votre zone bénéficiaire',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isMobile ? 6 : 8),

              Text(
                'Sélectionnez le pays où vivent vos proches\npour leur envoyer de l\'argent et payer leurs services',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(bool isTablet, bool isMobile) {
    return FadeTransition(
      opacity: _searchFadeAnimation,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16.0 : 24.0,
          vertical: 8.0,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Rechercher le pays de vos proches...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white.withOpacity(0.7),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 12 : 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZonesList(bool isTablet, bool isMobile) {
    return Expanded(
      child: SlideTransition(
        position: _listSlideAnimation,
        child: FadeTransition(
          opacity: _listFadeAnimation,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 24.0),
            child: ListView.builder(
              itemCount: _filteredZones.length,
              itemBuilder: (context, index) {
                final zone = _filteredZones[index];
                final isSelected = _selectedZone != null &&
                    _selectedZone!["name"] == zone["name"];

                return AnimatedContainer(
                  duration: AppConfig.animationDuration,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.6)
                          : Colors.white.withOpacity(0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => _selectZone(zone),
                    leading: Text(
                      zone["flag"],
                      style: TextStyle(fontSize: isMobile ? 24 : 28),
                    ),
                    title: Text(
                      zone["name"],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: isMobile ? 16 : 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${zone["region"]} • ${zone["dialCode"]}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                        Text(
                          'Aidez vos proches dans ce pays',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: isMobile ? 12 : 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: isMobile ? 24 : 28,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(bool isTablet, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Center(
        // Centrer le bouton
        child: ScaleTransition(
          scale: _buttonScaleAnimation,
          child: SizedBox(
            width: isMobile ? 280 : 320, // Largeur réduite
            height: isMobile ? 50 : 60,
            child: ElevatedButton(
              onPressed: _selectedZone != null && !_isLoading
                  ? _confirmSelection
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppConfig.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: isMobile ? 20 : 24,
                      height: isMobile ? 20 : 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppConfig.primaryColor),
                      ),
                    )
                  : Text(
                      'CONFIRMER', // Texte réduit
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _welcomeAnimationController.dispose();
    _logoAnimationController.dispose();
    _listAnimationController.dispose();
    _buttonAnimationController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }
}
