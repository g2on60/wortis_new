// ignore_for_file: unused_field, empty_catches, deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:wortis/class/icon_utils.dart';
import 'package:wortis/class/webviews.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:wortis/pages/homepage_dias.dart';

class MonComptePage extends StatefulWidget {
  const MonComptePage({super.key});

  @override
  _MonComptePageState createState() => _MonComptePageState();
}

enum AppLanguage { french, english }

class _MonComptePageState extends State<MonComptePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController scrollController; // Ajout du ScrollController

  Map<String, dynamic>? _userInfo;
  final Map<String, TextEditingController> _controllers = {};
  bool _isEditing = false;
  bool _isCardLoading = true;
  bool _isLoadingFields = true;
  int _miles = 0;
  final AppLanguage _currentLanguage = AppLanguage.french;
  final AppLanguage _activeLanguage = AppLanguage.french;
  Widget? _currentSettingView;
  List<ProfileField>? _profileFields;

  // Variables pour QR code / code-barres
  bool _showCode = false;
  bool _isQRCode = true; // true = QR code, false = code-barres
  String _codeData = '';
  bool _isLoadingCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
    scrollController = ScrollController(); // Initialisation du ScrollController

    _tabController = TabController(length: 2, vsync: this);
    _loadUserInfoFromStorage();
    _loadMiles();
    _loadProfileFieldsSafely(); // Version non-bloquante
    _loadCodeData();
  }

  Future<void> _loadUserInfoFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoString = prefs.getString('user_infos');

      if (userInfoString != null) {
        // AJOUT DE LA VÉRIFICATION MOUNTED
        if (!mounted) return;

        setState(() {
          _userInfo = jsonDecode(userInfoString);
        });
      }
    } catch (e) {
      // Gestion d'erreur silencieuse
    }
  }

  Future<void> _loadMiles() async {
    try {
      final token = await SessionManager.getToken();
      if (token != null) {
        final response = await http.get(
          Uri.parse('$baseUrl/get_user_apk_wpay_v3_test/$token'),
          headers: {"Content-Type": "application/json"},
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⏱️ Timeout lors du chargement des miles');
            throw TimeoutException('Timeout lors du chargement des miles');
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // AJOUT DE LA VÉRIFICATION MOUNTED
          if (!mounted) return;

          setState(() {
            _miles = data['miles'] as int;
            _isCardLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Erreur chargement miles: $e');
      // AJOUT DE LA VÉRIFICATION MOUNTED
      if (!mounted) return;

      setState(() => _isCardLoading = false);
    }
  }

  /// Version non-bloquante de _loadProfileFields avec timeout
  Future<void> _loadProfileFieldsSafely() async {
    try {
      // Timeout de 3 secondes pour ne pas bloquer l'UI
      await _loadProfileFields().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⏱️ Timeout lors du chargement des champs profil');
          if (mounted) {
            setState(() => _isLoadingFields = false);
          }
        },
      );
    } catch (e) {
      print('❌ Erreur lors du chargement des champs profil: $e');
      if (mounted) {
        setState(() => _isLoadingFields = false);
      }
    }
  }

  Future<void> _loadProfileFields() async {
    try {
      final fields = await ProfileFieldsService.getProfileFields();

      // VÉRIFICATION DÉJÀ PRÉSENTE - BIEN !
      if (!mounted) return;

      setState(() {
        _profileFields = fields;
        _isLoadingFields = false;

        // Initialiser les contrôleurs pour chaque champ
        for (var field in fields) {
          if (!_controllers.containsKey(field.name)) {
            _controllers[field.name] = TextEditingController(
              text: _userInfo?[field.name] ?? field.value ?? '',
            );
          }
        }
      });
    } catch (e) {
      // AJOUT DE LA VÉRIFICATION MOUNTED
      if (!mounted) return;

      print('⚠️ Erreur chargement champs profil: $e');

      setState(() => _isLoadingFields = false);

      // Ne pas afficher d'erreur si c'est un problème de réseau
      // L'utilisateur pourra quand même voir ses données locales
      if (mounted && !e.toString().contains('SocketException')) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors du chargement des champs du profil',
        );
      }
    }
  }

  /// Charge les données pour le QR code / code-barres
  Future<void> _loadCodeData() async {
    setState(() {
      _isLoadingCode = true;
    });

    try {
      // Récupérer les données utilisateur sauvegardées
      var userData = await SessionManager.getAllUserInfo();

      print('🔍 [Code] Données récupérées du storage:');
      print('   offline_user_data: ${userData.keys.toList()}');

      // Fallback vers user_infos si offline_user_data est vide
      if (userData.isEmpty) {
        print('⚠️ [Code] offline_user_data vide, essai avec user_infos');
        final prefs = await SharedPreferences.getInstance();
        final userInfosJson = prefs.getString('user_infos');

        if (userInfosJson != null && userInfosJson.isNotEmpty) {
          userData = jsonDecode(userInfosJson) as Map<String, dynamic>;
          print('✅ [Code] Données récupérées depuis user_infos');

          // Sauvegarder dans offline_user_data pour la prochaine fois
          await SessionManager.saveAllUserInfo(userData);
        }
      }

      if (userData.isNotEmpty) {
        // Extraire les informations essentielles
        final nom = userData['nom']?.toString() ??
                    userData['name']?.toString() ??
                    userData['lastname']?.toString() ?? '';
        final prenom = userData['prenom']?.toString() ??
                       userData['firstname']?.toString() ??
                       userData['first_name']?.toString() ?? '';
        final email = userData['email']?.toString() ??
                     userData['mail']?.toString() ?? '';
        final telephone = userData['phone_number']?.toString() ??
                         userData['phone']?.toString() ??
                         userData['telephone']?.toString() ??
                         userData['user_id']?.toString() ?? '';

        // Créer les données du code
        final userInfo = {
          'nom': nom,
          'prenom': prenom,
          'telephone': telephone,
          'email': email,
          'app': 'Wortis',
        };

        _codeData = jsonEncode(userInfo);
        print('✅ [Code] Données générées avec succès');
      } else {
        print('⚠️ [Code] Pas de données disponibles');
        // Fallback
        final fallbackInfo = {
          'message': 'Données utilisateur',
          'app': 'Wortis',
          'generated_at': DateTime.now().toIso8601String(),
        };
        _codeData = jsonEncode(fallbackInfo);
      }
    } catch (e) {
      print('❌ [Code] Erreur chargement: $e');
      // Fallback
      final fallbackInfo = {
        'message': 'Erreur chargement données',
        'app': 'Wortis',
      };
      _codeData = jsonEncode(fallbackInfo);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCode = false;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    try {
      Map<String, dynamic> updatedData = {};
      bool hasChanges = false;

      // Valider les champs requis
      for (var field in _profileFields ?? []) {
        if (field.isRequired) {
          final value = _controllers[field.name]?.text.trim() ?? '';
          if (value.isEmpty) {
            CustomOverlay.showError(
              context,
              message: 'Le champ ${field.label} est requis',
            );
            return;
          }
        }

        // Valider avec regex si défini
        if (field.validationRegex != null) {
          final value = _controllers[field.name]?.text.trim() ?? '';
          final regex = RegExp(field.validationRegex!);
          if (value.isNotEmpty && !regex.hasMatch(value)) {
            CustomOverlay.showError(
              context,
              message:
                  field.validationMessage ??
                  'Format invalide pour ${field.label}',
            );
            return;
          }
        }
      }

      _controllers.forEach((key, controller) {
        final currentValue = _userInfo?[key]?.toString() ?? '';
        final newValue = controller.text.trim();

        if (currentValue != newValue) {
          updatedData[key] = newValue;
          hasChanges = true;
        }
      });

      if (!hasChanges) {
        CustomOverlay.showInfo(
          context,
          message: 'Aucune modification à enregistrer',
        );
        return;
      }

      CustomOverlay.showLoading(context, message: 'Mise à jour en cours...');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('user_token');

      if (token == null) throw Exception('Session expirée');

      final response = await http.put(
        Uri.parse('$baseUrl/update_user_apk_wpay_v2_test/$token'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updatedData),
      );

      // AJOUT DE LA VÉRIFICATION MOUNTED
      if (!mounted) return;

      CustomOverlay.hide();

      final result = jsonDecode(response.body);

      if (result['Code'] == 200) {
        final existingUserInfo = _userInfo ?? {};
        final updatedUserInfo = {...existingUserInfo, ...updatedData};
        await prefs.setString('user_infos', jsonEncode(updatedUserInfo));

        // Sauvegarder aussi dans offline_user_data
        await SessionManager.saveAllUserInfo(updatedUserInfo);

        // AJOUT DE LA VÉRIFICATION MOUNTED
        if (!mounted) return;

        setState(() {
          _userInfo = updatedUserInfo;
          _isEditing = false;
        });

        // VÉRIFICATION DÉJÀ PRÉSENTE - BIEN !
        if (!mounted) return;
        CustomOverlay.showSuccess(
          context,
          message: 'Profil mis à jour avec succès',
        );
      } else {
        throw Exception(result['messages'] ?? 'Erreur lors de la mise à jour');
      }
    } catch (e) {
      // AJOUT DE LA VÉRIFICATION MOUNTED
      if (!mounted) return;

      CustomOverlay.hide();
      CustomOverlay.showError(context, message: e.toString());
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // VÉRIFICATION DÉJÀ PRÉSENTE - BIEN !
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthentificationPage()),
        (route) => false,
      );
    } catch (e) {
      // AJOUT DE LA VÉRIFICATION MOUNTED
      if (!mounted) return;

      CustomOverlay.showError(
        context,
        message: 'Erreur lors de la déconnexion',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          _buildAppBar(),
          _buildTabBar(),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildProfileTab(), _buildSettingsTab()],
        ),
      ),
    );
  }

  void _returnToHomePage() {
    final homeType = NavigationManager.getCurrentHomePage();

    if (homeType == 'HomePageDias') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePageDias()),
        (route) => false,
      );
    } else {
      final routeObserver = RouteObserver<PageRoute>();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(routeObserver: routeObserver),
        ),
        (route) => false,
      );
    }
  }

  Widget _buildAppBar() {
    final userName = _userInfo?['nom'] ?? 'Utilisateur';
    final userProfile = _userInfo?['google_picture'];

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF006699),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => _returnToHomePage(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF006699), Color(0xFF004466)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (userProfile != null)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(userProfile),
                  backgroundColor: Colors.white.withOpacity(0.2),
                )
              else
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
              const SizedBox(height: 8),
              Text(
                userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showLogoutConfirmation(context),
                icon: const Icon(Icons.logout, color: Colors.white70, size: 16),
                label: const Text(
                  'Se déconnecter',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF006699),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF006699),
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profil'),
            Tab(icon: Icon(Icons.settings), text: 'Paramètres'),
          ],
        ),
      ),
    );
  }

  Widget _buildMilesWidget() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF006699),
                    const Color(0xFF006699).withOpacity(0.8),
                  ],
                  stops: const [0.3, 0.9],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF006699).withOpacity(0.3 * value),
                    blurRadius: 15,
                    offset: Offset(0, 5 * value),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -60,
                    left: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Image.asset(
                              'assets/wortisapp.png',
                              height: 40,
                              color: Colors.white,
                            ),
                            const Icon(
                              Icons.wifi,
                              color: Colors.white70,
                              size: 24,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 42,
                          alignment: Alignment.centerLeft,
                          child: _isCardLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  '${NumberFormat("#,###", "fr_FR").format(_miles).replaceAll(',', ' ')} Mls',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SOLDE DISPONIBLE',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  'MILES CARD',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                            // Nouveau bouton Dépenser mes miles
                            if (!_isCardLoading && _miles > 100)
                              ElevatedButton.icon(
                                onPressed: () => _navigateToMilesService(),
                                icon: const Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 16,
                                  color: Color(0xFF006699),
                                ),
                                label: const Text(
                                  'Dépenser',
                                  style: TextStyle(
                                    color: Color(0xFF006699),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF006699),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Widget pour afficher/masquer le QR code ou code-barres
  Widget _buildCodeDisplayWidget() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF006699).withOpacity(0.15 * value),
                    blurRadius: 15,
                    offset: Offset(0, 5 * value),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Bouton pour afficher/masquer le code
                  if (!_showCode)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showCode = true;
                          });
                        },
                        icon: const Icon(Icons.qr_code_2, size: 24),
                        label: const Text(
                          'Afficher mon code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006699),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),

                  // Zone d'affichage du code
                  if (_showCode)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Header avec switch QR/Barcode
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isQRCode ? 'QR Code' : 'Code-barres',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF006699),
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.qr_code_2,
                                    color: _isQRCode
                                        ? const Color(0xFF006699)
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  Switch(
                                    value: !_isQRCode,
                                    onChanged: (value) {
                                      setState(() {
                                        _isQRCode = !value;
                                      });
                                    },
                                    activeColor: const Color(0xFF006699),
                                  ),
                                  Icon(
                                    Icons.view_stream,
                                    color: !_isQRCode
                                        ? const Color(0xFF006699)
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Affichage du code
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF006699).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: _isLoadingCode
                                ? const SizedBox(
                                    width: 200,
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF006699),
                                      ),
                                    ),
                                  )
                                : _isQRCode
                                    ? _buildQRCode()
                                    : _buildBarcode(),
                          ),

                          const SizedBox(height: 15),

                          // Description
                          Text(
                            _isQRCode
                                ? 'Scannez ce QR code pour accéder à mes informations'
                                : 'Scannez ce code-barres pour accéder à mes informations',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 15),

                          // Bouton Masquer
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showCode = false;
                              });
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text(
                              'Masquer',
                              style: TextStyle(fontSize: 14),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF006699),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Widget QR Code
  Widget _buildQRCode() {
    return QrImageView(
      data: _codeData.isNotEmpty
          ? _codeData
          : jsonEncode({'error': 'Données non disponibles'}),
      version: QrVersions.auto,
      size: 200,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      padding: const EdgeInsets.all(10),
    );
  }

  /// Widget Code-barres
  Widget _buildBarcode() {
    // Pour le code-barres, on utilise le téléphone comme donnée
    String barcodeData = _userInfo?['phone_number']?.toString() ??
                         _userInfo?['telephone']?.toString() ??
                         '0000000000';

    // S'assurer que la donnée a au moins 8 chiffres pour le code-barres
    if (barcodeData.length < 8) {
      barcodeData = barcodeData.padRight(8, '0');
    }

    return BarcodeWidget(
      barcode: Barcode.code128(),
      data: barcodeData,
      width: 250,
      height: 100,
      drawText: true,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      controller: scrollController,
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.manual, // Changé à manual

      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildMilesWidget(),
                const SizedBox(height: 5),
                _buildCodeDisplayWidget(),
                const SizedBox(height: 10),
                if (_userInfo != null)
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF006699),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'Mes coordonnées',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _isEditing ? Icons.edit_off : Icons.edit,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() => _isEditing = !_isEditing);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ..._buildUserInfoFields(),
                          if (_isEditing)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _saveChanges,
                                  icon: const Icon(
                                    Icons.save,
                                    color: Colors.white,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF006699),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                  ),
                                  label: const Text(
                                    'Enregistrer les modifications',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 200), // Espace en bas pour le clavier
        ],
      ),
    );
  }

  Widget _buildSpendOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF006699).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF006699), size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // Nouvelle méthode pour naviguer vers test.wortispay.cg
  Future<void> _navigateToMilesService() async {
    try {
      final token = await SessionManager.getToken();

      if (token == null || token.isEmpty) {
        CustomOverlay.showError(context, message: 'Session expirée');
        return;
      }

      // Construire l'URL vers test.wortispay.cg avec les paramètres miles
      const baseUrl = "https://faouzy.wortis.cg/miles";
      final uri = Uri.parse(baseUrl).replace(queryParameters: {'token': token});

      final fullUrl = uri.toString();

      print('🌐 Navigation vers miles service: $fullUrl');

      // Ouvrir dans ServiceWebView (comme dans homepage_dias.dart)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ServiceWebView(url: fullUrl)),
      );
    } catch (e) {
      print('❌ Erreur navigation miles service: $e');
      CustomOverlay.showError(
        context,
        message: 'Erreur lors de l\'ouverture du service',
      );
    }
  }

  // Modifiez les champs pour inclure le scroll automatique
  List<Widget> _buildUserInfoFields() {
    if (_isLoadingFields) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: Color(0xFF006699)),
          ),
        ),
      ];
    }

    // Si aucun champ n'est encore chargé depuis l'API, afficher les champs de base
    if (_profileFields == null || _profileFields!.isEmpty) {
      final baseFields = [
        {'name': 'nom', 'label': 'Nom complet', 'icon': Icons.person},
        {'name': 'phone_number', 'label': 'Téléphone', 'icon': Icons.phone},
        {'name': 'address', 'label': 'Adresse', 'icon': Icons.location_on},
        {
          'name': 'subscription_number',
          'label': 'Numéro d\'abonnement',
          'icon': Icons.card_membership,
        },
        {
          'name': 'e2c_number',
          'label': 'Numéro client E2C',
          'icon': Icons.credit_card,
        },
      ];

      return baseFields.map((field) {
        final name = field['name'] as String;
        if (!_controllers.containsKey(name)) {
          _controllers[name] = TextEditingController(
            text: _userInfo?[name] ?? '',
          );
        }

        return _buildFormField(
          name: name,
          label: field['label'] as String,
          icon: field['icon'] as IconData,
          keyboardType: name == 'phone_number'
              ? TextInputType.phone
              : (name == 'e2c_number' || name == 'subscription_number')
              ? TextInputType.number
              : TextInputType.text,
        );
      }).toList();
    }

    return _profileFields!.map((field) {
      if (!_controllers.containsKey(field.name)) {
        _controllers[field.name] = TextEditingController(
          text: _userInfo?[field.name] ?? field.value ?? '',
        );
      }

      return _buildFormField(
        name: field.name,
        label: field.label + (field.isRequired ? ' *' : ''),
        icon: field.icon,
        keyboardType: _getKeyboardType(field.fieldType),
        placeholder: field.placeholder,
        isEditable: field.isEditable,
      );
    }).toList();
  }

  Widget _buildFormField({
    required String name,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? placeholder,
    bool isEditable = true,
  }) {
    // Vérifier si c'est le dernier champ
    bool isLastField =
        (_profileFields != null && name == _profileFields!.last.name) ||
        (name == 'e2c_number');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF006699), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF006699),
                  ),
                ),
                const SizedBox(height: 4),
                if (_isEditing && isEditable)
                  Focus(
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          // AJOUT DE LA VÉRIFICATION MOUNTED
                          if (!mounted) return;

                          final RenderObject? renderObject = context
                              .findRenderObject();
                          if (renderObject != null) {
                            scrollController.position.ensureVisible(
                              renderObject,
                              alignment: 0.2,
                              duration: const Duration(milliseconds: 300),
                            );
                          }
                        });
                      }
                    },
                    child: TextFormField(
                      controller: _controllers[name],
                      keyboardType: keyboardType,
                      enabled: isEditable,
                      textInputAction: isLastField
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onFieldSubmitted: (value) {
                        if (!isLastField) {
                          // Si ce n'est pas le dernier champ, passer au suivant
                          FocusScope.of(context).nextFocus();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: placeholder ?? 'Entrez $label',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    _controllers[name]?.text ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: isEditable ? Colors.black87 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextInputType _getKeyboardType(String fieldType) {
    switch (fieldType) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }

  Widget _buildSettingsTab() {
    if (_currentSettingView != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF006699)),
                  onPressed: () {
                    setState(() {
                      _currentSettingView = null;
                    });
                  },
                ),
                const Text(
                  'Retour aux paramètres',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF006699),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _currentSettingView!),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingItem('Modifier le mot de passe', Icons.lock),
        _buildSettingItem('Aide', Icons.help),
        _buildSettingItem('À propos', Icons.info),
      ],
    );
  }

  Widget _buildSettingItem(String title, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF006699)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _handleSettingTap(title),
      ),
    );
  }

  void _handleSettingTap(String title) {
    switch (title) {
      case 'Modifier le mot de passe':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const ForgotPasswordPage(fromUserAccount: true),
          ),
        );
        break;
      case 'Aide':
        setState(() {
          _currentSettingView = _buildHelpPage();
        });
        break;
      case 'À propos':
        setState(() {
          _currentSettingView = _buildAboutPage();
        });
        break;
    }
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: size.width * 0.90,
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF006699),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/wortisapp.png',
                      height: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Se déconnecter',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006699),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Voulez-vous vraiment vous déconnecter ?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vous devrez vous reconnecter pour accéder à votre compte.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(
                              color: Color(0xFF006699),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _logout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Se déconnecter',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHelpSection(),
        const SizedBox(height: 20),
        _buildContactCard(),
      ],
    );
  }

  Widget _buildHelpSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Questions fréquentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006699),
              ),
            ),
            const SizedBox(height: 16),
            _buildExpandableQuestion(
              'Comment modifier mes informations personnelles ?',
              'Accédez à votre profil et cliquez sur l\'icône d\'édition en haut à droite pour modifier vos informations.',
            ),
            _buildExpandableQuestion(
              'Comment contacter le support ?',
              'Vous pouvez nous contacter par email à support@wortis.cg ou par téléphone au 50 05.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableQuestion(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(answer, style: const TextStyle(color: Colors.black54)),
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nous contacter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006699),
              ),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.email, color: Color(0xFF006699)),
              title: Text('Email'),
              subtitle: Text('support@wortis.cg'),
            ),
            ListTile(
              leading: Icon(Icons.phone, color: Color(0xFF006699)),
              title: Text('Téléphone'),
              subtitle: Text('50 05'),
            ),
            ListTile(
              leading: Icon(Icons.chat, color: Color(0xFF006699)),
              title: Text('Chat en direct'),
              subtitle: Text('Disponible 24/7'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAboutLogoSection(),
        const SizedBox(height: 24),
        _buildAboutInfoSection(),
      ],
    );
  }

  Widget _buildAboutLogoSection() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF006699),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Image.asset('assets/wortisapp.png', color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Wortis',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006699),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Version 1.5.1',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006699), Color(0xFF0088cc)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006699).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              const Text(
                'À propos de',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Wortis est une application de paiement mobile innovante qui permet '
              'aux utilisateurs de gérer leurs transactions quotidiennes de manière '
              'simple et sécurisée. Notre mission est de faciliter les paiements '
              'numériques pour tous.',
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Arrêter toutes les opérations asynchrones en cours
    _tabController.dispose();
    scrollController.dispose();

    // Disposer de tous les contrôleurs de texte
    _controllers.forEach((_, controller) => controller.dispose());

    super.dispose();
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

// class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
//   final TabBar _tabBar;

//   _SliverAppBarDelegate(this._tabBar);

//   @override
//   Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
//     return Container(
//       color: Theme.of(context).scaffoldBackgroundColor,
//       child: _tabBar,
//     );
//   }

//   @override
//   double get maxExtent => _tabBar.preferredSize.height;

//   @override
//   double get minExtent => _tabBar.preferredSize.height;

//   @override
//   bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
//     return false;
//   }
// }

class ProfileField {
  final String id;
  final String name;
  final String label;
  final String? value;
  final IconData icon;
  final bool isEditable;
  final String? placeholder;
  final String? validationRegex;
  final String? validationMessage;
  final bool isRequired;
  final String fieldType; // text, number, email, phone, etc.

  ProfileField({
    required this.id,
    required this.name,
    required this.label,
    this.value,
    required this.icon,
    required this.isEditable,
    this.placeholder,
    this.validationRegex,
    this.validationMessage,
    this.isRequired = false,
    required this.fieldType,
  });

  factory ProfileField.fromJson(Map<String, dynamic> json) {
    IconUtils.getIconData(json['icon']);

    return ProfileField(
      id: json['id'],
      name: json['name'],
      label: json['label'],
      value: json['value'],
      icon: IconUtils.getIconData(json['icon']),
      isEditable: json['isEditable'] ?? true,
      placeholder: json['placeholder'],
      validationRegex: json['validationRegex'],
      validationMessage: json['validationMessage'],
      isRequired: json['isRequired'] ?? false,
      fieldType: json['fieldType'] ?? 'text',
    );
  }
}

// Service pour charger les champs de profil
class ProfileFieldsService {
  static const String baseUrl = 'https://api.live.wortis.cg';

  static Future<List<ProfileField>> getProfileFields() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_profile_fields_v2_test'),
        headers: {"Content-Type": "application/json"},
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏱️ Timeout lors du chargement des champs profil API');
          throw TimeoutException('Timeout lors du chargement des champs profil');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((field) => ProfileField.fromJson(field)).toList();
      } else {
        throw Exception('Erreur lors du chargement des champs');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
}
