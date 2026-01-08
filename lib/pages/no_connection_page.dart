import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wortis/class/dataprovider.dart';
import 'package:wortis/class/class.dart';

class NoConnectionPage extends StatefulWidget {
  const NoConnectionPage({super.key});

  @override
  State<NoConnectionPage> createState() => _NoConnectionPageState();
}

class _NoConnectionPageState extends State<NoConnectionPage>
    with SingleTickerProviderStateMixin {
  bool _showQRCode = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _qrData = '';
  bool _isLoadingQR = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadUserDataFromStorage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Charge les données utilisateur depuis SharedPreferences
  Future<void> _loadUserDataFromStorage() async {
    setState(() {
      _isLoadingQR = true;
    });

    try {
      // Récupérer TOUTES les informations utilisateur sauvegardées
      var userData = await SessionManager.getAllUserInfo();

      print('🔍 [QRCode] Données récupérées du storage offline:');
      print('   offline_user_data: ${userData.keys.toList()}');

      // Fallback vers user_infos si offline_user_data est vide
      if (userData.isEmpty) {
        print('⚠️ [QRCode] offline_user_data vide, essai avec user_infos');
        final prefs = await SharedPreferences.getInstance();
        final userInfosJson = prefs.getString('user_infos');

        if (userInfosJson != null && userInfosJson.isNotEmpty) {
          userData = jsonDecode(userInfosJson) as Map<String, dynamic>;
          print('✅ [QRCode] Données récupérées depuis user_infos');
          print('   user_infos clés: ${userData.keys.toList()}');

          // Sauvegarder dans offline_user_data pour la prochaine fois
          await SessionManager.saveAllUserInfo(userData);
        }
      }

      print('   📋 Toutes les données: $userData');

      if (userData.isNotEmpty) {
        // Extraire les 4 champs essentiels pour le QR code
        final nom = userData['nom']?.toString() ??
                    userData['name']?.toString() ??
                    userData['lastname']?.toString() ?? '';
        final prenom = userData['prenom']?.toString() ??
                       userData['firstname']?.toString() ??
                       userData['first_name']?.toString() ?? '';
        final email = userData['email']?.toString() ??
                     userData['mail']?.toString() ?? '';

        // Le téléphone
        final telephone = userData['phone_number']?.toString() ??
                         userData['phone']?.toString() ??
                         userData['telephone']?.toString() ??
                         userData['user_id']?.toString() ?? '';

        print('   📝 Nom: $nom');
        print('   📝 Prénom: $prenom');
        print('   📝 Email: $email');
        print('   📝 Téléphone: $telephone');

        // Créer le QR data avec les 4 informations essentielles
        final userInfo = {
          'nom': nom,
          'prenom': prenom,
          'telephone': telephone,
          'email': email,
          'app': 'Wortis',
        };

        _qrData = jsonEncode(userInfo);
        print('✅ [QRCode] QR Data généré avec succès depuis offline_user_data');
      } else {
        print('⚠️ [QRCode] Pas de données offline, utilisation du Provider');
        // Essayer avec le Provider en fallback
        _qrData = _getUserQRDataFromProvider();
      }
    } catch (e) {
      print('❌ [QRCode] Erreur chargement storage: $e');
      _qrData = _getUserQRDataFromProvider();
    } finally {
      setState(() {
        _isLoadingQR = false;
      });
    }
  }

  /// Récupère les données depuis le Provider (fallback)
  String _getUserQRDataFromProvider() {
    try {
      final appDataProvider = Provider.of<AppDataProvider>(
        context,
        listen: false,
      );

      final userData = appDataProvider.userData;

      if (userData != null) {
        final userInfo = {
          'nom': userData.getFieldValue('nom') ?? '',
          'prenom': userData.getFieldValue('prenom') ?? '',
          'telephone': userData.getFieldValue('phone_number') ??
                       userData.getFieldValue('phone') ??
                       userData.getFieldValue('telephone') ??
                       userData.getFieldValue('user_id') ?? '',
          'email': userData.getFieldValue('email') ?? '',
          'app': 'Wortis',
        };

        print('✅ [QRCode] Données QR générées depuis Provider');
        return jsonEncode(userInfo);
      }
    } catch (e) {
      print('❌ [QRCode] Erreur Provider: $e');
    }

    // Fallback final
    final fallbackInfo = {
      'message': 'Mode hors ligne',
      'app': 'Wortis',
      'generated_at': DateTime.now().toIso8601String(),
      'note': 'Données utilisateur non disponibles',
    };

    return jsonEncode(fallbackInfo);
  }

  void _toggleQRCode() {
    setState(() {
      _showQRCode = !_showQRCode;
      if (_showQRCode) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF006699),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: screenHeight * 0.1),

                  // Icône de connexion perdue - masquée si QR code affiché
                  if (!_showQRCode) ...[
                    Container(
                      padding: EdgeInsets.all(screenWidth * 0.08),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wifi_off_rounded,
                        size: screenWidth * 0.2,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.05),
                    // Titre
                    Text(
                      'Problème de connexion',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.07,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    // Description
                    Text(
                      'Impossible de se connecter à Internet.\nVeuillez vérifier votre connexion.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: screenWidth * 0.04,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenHeight * 0.05),
                  ],

                  // Bouton Afficher QR Code
                  if (!_showQRCode)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _toggleQRCode,
                        icon: Icon(Icons.qr_code_2, size: screenWidth * 0.07),
                        label: Text(
                          'Afficher mon QR Code',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF006699),
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.08,
                            vertical: screenHeight * 0.02,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),

                  // Zone d'affichage du QR Code
                  if (_showQRCode)
                    Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Container blanc pour le QR code
                            Container(
                              width: screenWidth * 0.85,
                              padding: EdgeInsets.all(screenWidth * 0.06),
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
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Mes informations',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.045,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF006699),
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.02),
                                  // QR Code centré
                                  Center(
                                    child: _isLoadingQR
                                        ? SizedBox(
                                            width: screenWidth * 0.6,
                                            height: screenWidth * 0.6,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF006699),
                                              ),
                                            ),
                                          )
                                        : QrImageView(
                                            data: _qrData.isNotEmpty
                                                ? _qrData
                                                : jsonEncode({'error': 'Données non disponibles'}),
                                            version: QrVersions.auto,
                                            size: screenWidth * 0.6,
                                            backgroundColor: Colors.white,
                                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                                            padding: const EdgeInsets.all(10),
                                          ),
                                  ),
                                  SizedBox(height: screenHeight * 0.02),
                                  Text(
                                    'Scannez ce code pour accéder\nà mes informations',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.03,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.03),

                            // Bouton Masquer centré
                            Center(
                              child: TextButton.icon(
                                onPressed: _toggleQRCode,
                                icon: const Icon(Icons.close, color: Colors.white),
                                label: Text(
                                  'Masquer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth * 0.04,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.06,
                                    vertical: screenHeight * 0.015,
                                  ),
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (!_showQRCode) SizedBox(height: screenHeight * 0.04),

                  // Indicateur de réessai
                  if (!_showQRCode)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          Text(
                            'Tentative de reconnexion...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: screenWidth * 0.035,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: screenHeight * 0.1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
