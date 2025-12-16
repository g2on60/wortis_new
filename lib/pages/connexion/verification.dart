// ignore_for_file: unused_local_variable, avoid_print, deprecated_member_use

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:wortis/pages/welcome.dart';

class VerificationScreen extends StatefulWidget {
  final String data;
  final String datatel;

  const VerificationScreen(
      {super.key, required this.data, required this.datatel});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  List<String> pinValues = List.filled(4, '');
  int currentIndex = 0;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    ConnectivityManager(context).initConnectivity;
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleNumberPress(String number) {
    HapticFeedback.lightImpact();
    if (currentIndex < 4) {
      setState(() {
        pinValues[currentIndex] = number;
        currentIndex++;
      });

      // Déclencher la vérification si c'est le dernier chiffre
      if (currentIndex == 4) {
        confirmPin();
      }
    }
  }

  void _handleBackspace() {
    HapticFeedback.lightImpact();
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        pinValues[currentIndex] = '';
      });
    }
  }

  // ignore: unused_element
  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) {
        _animationController.reverse();
        _handleNumberPress(number);
      },
      onTapCancel: () => _animationController.reverse(),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: Container(
              width: 70,
              height: 70,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> confirmPin() async {
    if (pinValues.any((value) => value.isEmpty)) {
      CustomOverlay.showError(
        context,
        message: 'Veuillez entrer les 4 chiffres du code',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService(context);
      String pin = pinValues.join();

      print('🔄 [ConfirmPin] Vérification du code: $pin');

      // Vérification du code - cette méthode doit lever une exception en cas d'échec
      await authService.verifyCode(token: widget.data, pin: pin);

      print('✅ [ConfirmPin] Code vérifié avec succès');

      // ========== REDIRECTION BASÉE SUR GÉOLOCALISATION DÉTECTÉE ==========
      if (mounted) {
        // Récupérer la géolocalisation détectée
        final locationService = LocationService();
        final currentLocation = locationService.currentLocation;

        // if (currentLocation != null) {
        final detectedCountry = currentLocation?.country;
        print(
            '🌍 [ConfirmPin] Pays détecté: ${detectedCountry?.name} (${detectedCountry?.code})');

        // if (detectedCountry.code == 'CG') {
        // ========== CONGO DÉTECTÉ → HomePage ==========
        print('🇨🇬 [ConfirmPin] Géolocalisation Congo → HomePage');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  HomePage(routeObserver: RouteObserver<PageRoute>())),
          (route) => false,
        );
        // } else {
        // ========== AUTRE PAYS → Welcome (Diaspora) ==========
        print(
            '🌍 [ConfirmPin] Géolocalisation ${detectedCountry?.name} → Welcome');

        // Récupérer le nom utilisateur pour Welcome
        String userName = "Utilisateur";
        try {
          final prefs = await SharedPreferences.getInstance();
          final userInfosString = prefs.getString('user_infos');
          if (userInfosString != null) {
            final userInfos = json.decode(userInfosString);
            userName =
                userInfos['nom'] ?? userInfos['nomEtPrenom'] ?? "Utilisateur";
          }
        } catch (e) {
          print('Erreur récupération nom utilisateur: $e');
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomeZoneSelectionPage(
              userName: userName,
              onZoneSelected: (selectedZone) {
                // Le traitement se fera dans la page Welcome
              },
            ),
          ),
          (route) => false,
        );
        // }
        // } else {
        //   // ========== GÉOLOCALISATION NON DISPONIBLE → Fallback ==========
        //   print('⚠️ [ConfirmPin] Géolocalisation non disponible → Welcome par défaut');

        //   String userName = "Utilisateur";
        //   try {
        //     final prefs = await SharedPreferences.getInstance();
        //     final userInfosString = prefs.getString('user_infos');
        //     if (userInfosString != null) {
        //       final userInfos = json.decode(userInfosString);
        //       userName = userInfos['nom'] ?? userInfos['nomEtPrenom'] ?? "Utilisateur";
        //     }
        //   } catch (e) {
        //     print('Erreur récupération nom utilisateur: $e');
        //   }

        //   Navigator.pushAndRemoveUntil(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) => WelcomeZoneSelectionPage(
        //         userName: userName,
        //         onZoneSelected: (selectedZone) {
        //           // Le traitement se fera dans la page Welcome
        //         },
        //       ),
        //     ),
        //     (route) => false,
        //   );
        // }
      }
    } catch (e) {
      print('❌ [ConfirmPin] Erreur de vérification: $e');

      if (mounted) {
        // ========== AFFICHER L'ERREUR ET RESTER SUR LA PAGE ==========
        CustomOverlay.showError(context,
            message: 'Le code de vérification entré n\'est pas valide');

        // Réinitialiser le formulaire
        setState(() {
          pinValues = List.filled(4, '');
          currentIndex = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> resendCode(String token, String tel) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.live.wortis.cg/resend_code_apk_wpay_v2_test'),
        body: json.encode({'token': token, 'tel': tel}),
        headers: {'Content-Type': 'application/json'},
      );
      print(json.encode({'token': token, 'tel': tel}));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        String updatedToken = jsonResponse['token'];

        if (mounted) {
          CustomOverlay.showSuccess(
            context,
            message: 'Un nouveau code a été envoyé',
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationScreen(
                data: updatedToken,
                datatel: widget.datatel,
              ),
            ),
          );
        }
      } else {
        throw Exception(
            'Erreur lors du renvoi du code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        CustomOverlay.showError(context,
            message: 'Erreur lors du renvoi du code: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
        pinValues = List.filled(4, '');
        currentIndex = 0;
      });
    }
  }

  Widget _buildResponsiveNumberButton(
      String number, double size, double fontSize) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) {
        _animationController.reverse();
        _handleNumberPress(number);
      },
      onTapCancel: () => _animationController.reverse(),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: Container(
              width: size,
              height: size,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(size / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  number,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveBackspaceButton(double size) {
    return GestureDetector(
      onTap: _handleBackspace,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.white,
            size: size * 0.35,
          ),
        ),
      ),
    );
  }

  String maskPhoneNumber(String phoneNumber) {
    for (var country in countries) {
      if (phoneNumber.startsWith(country.dialCode)) {
        String numberWithoutCode =
            phoneNumber.substring(country.dialCode.length);

        if (numberWithoutCode.length > 4) {
          String maskedPart = '*' * (numberWithoutCode.length - 4);
          return '${country.dialCode} ${numberWithoutCode.substring(0, 2)}$maskedPart${numberWithoutCode.substring(numberWithoutCode.length - 2)}';
        }
        return phoneNumber;
      }
    }
    return phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 360;
        final isMediumScreen = constraints.maxWidth < 480;

        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        final buttonSize =
            isSmallScreen ? 60.0 : (isMediumScreen ? 65.0 : 70.0);
        final pinBoxSize =
            isSmallScreen ? 45.0 : (isMediumScreen ? 48.0 : 50.0);
        final headerFontSize =
            isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0);
        final titleFontSize =
            isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0);
        final numberFontSize =
            isSmallScreen ? 24.0 : (isMediumScreen ? 26.0 : 28.0);
        final pinFontSize =
            isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0);
        final spacing = isSmallScreen ? 30.0 : (isMediumScreen ? 35.0 : 40.0);
        final horizontalPadding =
            isSmallScreen ? 15.0 : (isMediumScreen ? 18.0 : 20.0);

        return Scaffold(
          backgroundColor: const Color(0xFF006699),
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF006699), Color(0xFF004466)],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      children: [
                        SizedBox(height: screenHeight * 0.03),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              iconSize: isSmallScreen ? 22 : 24,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Text(
                              "Code de vérification",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: headerFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 35 : 40),
                          ],
                        ),
                        SizedBox(height: spacing),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding),
                          child: Text(
                            "Saisissez le code de vérification envoyé au\n${maskPhoneNumber(widget.datatel)}",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: titleFontSize,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: spacing),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            bool isFilled = pinValues[index].isNotEmpty;
                            bool isActive = index == currentIndex;
                            return Container(
                              width: pinBoxSize,
                              height: pinBoxSize,
                              margin: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 6 : 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                border: Border.all(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 12 : 15),
                              ),
                              child: Center(
                                child: Text(
                                  pinValues[index],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: pinFontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: spacing),
                        Column(
                          children: [
                            for (var i = 0; i < 3; i++)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (j) {
                                  final number = (i * 3 + j + 1).toString();
                                  return _buildResponsiveNumberButton(
                                    number,
                                    buttonSize,
                                    numberFontSize,
                                  );
                                }),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: buttonSize + 16),
                                _buildResponsiveNumberButton(
                                  '0',
                                  buttonSize,
                                  numberFontSize,
                                ),
                                _buildResponsiveBackspaceButton(buttonSize),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: spacing * 0.5),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        SizedBox(height: spacing * 0.25),
                        TextButton(
                          onPressed: () async {
                            await resendCode(widget.data, 'azerty');
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding * 1.5,
                              vertical: isSmallScreen ? 10 : 12,
                            ),
                          ),
                          child: Text(
                            'RENVOYER LE CODE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
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
        );
      },
    );
  }
}
