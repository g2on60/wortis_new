// ignore_for_file: unused_local_variable, unused_field, camel_case_types, library_private_types_in_public_api, avoid_print, use_build_context_synchronously, duplicate_ignore, deprecated_member_use

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart';

class VerificationScreen_Forgot extends StatefulWidget {
  final String data;

  final String datatel;

  const VerificationScreen_Forgot(
      {super.key, required this.data, required this.datatel});

  @override
  _VerificationScreen_ForgotState createState() =>
      _VerificationScreen_ForgotState();
}

class _VerificationScreen_ForgotState extends State<VerificationScreen_Forgot>
    with SingleTickerProviderStateMixin {
  List<String> pinValues = List.filled(4, '');
  int currentIndex = 0;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
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

      // Déclencher la vérification automatiquement si c'est le dernier chiffre
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

  Future<void> confirmPin() async {
    if (pinValues.any((value) => value.isEmpty)) {
      CustomOverlay.showError(context,
          message: 'Veuillez entrer les 4 chiffres du code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String pin = pinValues.join();
      print('🔄 [ConfirmPin] Vérification du code: $pin, pour ${widget.data}');

      await verifyCode(token: widget.data, pin: pin);

      print('✅ [ConfirmPin] Code vérifié avec succès');
    } catch (e) {
      print('❌ [ConfirmPin] Erreur de vérification Forgot: $e');

      if (mounted) {
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

        // Récupérer le nouveau token
        String updatedToken = jsonResponse['token'];

        if (mounted) {
          CustomOverlay.showSuccess(
            context,
            message: 'Un nouveau code a été envoyé',
          );

          // Recharger la page avec les nouvelles données
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationScreen_Forgot(
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

  Future<void> verifyCode({required String token, required String pin}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify_code_apk_wpay_v2_test'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'pin': pin,
        }),
      );

      print({
        'token': token,
        'pin': pin,
      });

      final data = jsonDecode(response.body);

      if (data['Code'] == 200) {
        final newToken = data['token'];
        if (newToken != null) {
          await SessionManager.clearSession();
          await SessionManager.saveSession(newToken);

          // Navigation vers la page de nouveau mot de passe
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => Page_New_MDP(token: newToken),
            ),
            (route) => false,
          );
        } else {
          throw Exception('Token non reçu du serveur');
        }
      } else {
        throw Exception('Le code de vérification entré n\'est pas valide');
      }
    } catch (e) {
      throw Exception('Erreur lors de la vérification: $e');
    }
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

    // Fallback si aucun indicatif trouvé
    if (phoneNumber.length < 4) {
      return phoneNumber;
    }
    return '${phoneNumber.substring(0, 2)}*${phoneNumber.substring(phoneNumber.length - 2)}';
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

                        // Header
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

                        // Message explicatif
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

                        // PIN Display
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

                        // Numpad
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

                        // Loading indicator
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),

                        SizedBox(height: spacing * 0.25),

                        // Resend button
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

// Classe Page_New_MDP reste inchangée
class Page_New_MDP extends StatefulWidget {
  final String token;

  const Page_New_MDP({super.key, required this.token});

  @override
  _Page_New_MDPState createState() => _Page_New_MDPState();
}

class _Page_New_MDPState extends State<Page_New_MDP> with KeyboardAwareState {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final _passwordResetService = PasswordResetService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    CustomOverlay.showError(context, message: message);
  }

  bool _validatePassword() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Vérifier si les mots de passe sont identiques
    if (password != confirmPassword) {
      _showErrorSnackBar('Les mots de passe ne correspondent pas');
      return false;
    }

    // Vérifier la longueur minimale
    if (password.length < 8) {
      _showErrorSnackBar('Le mot de passe doit contenir au moins 8 caractères');
      return false;
    }

    // Vérifier les critères de complexité
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      _showErrorSnackBar(
          'Le mot de passe doit contenir au moins une majuscule');
      return false;
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      _showErrorSnackBar(
          'Le mot de passe doit contenir au moins une minuscule');
      return false;
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      _showErrorSnackBar('Le mot de passe doit contenir au moins un chiffre');
      return false;
    }

    return true;
  }

  Future<void> updatePassword(String token, String password) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'https://api.live.wortis.cg/update_password_apk_wpay_v2_test'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
        body: json.encode({
          'password': password,
        }),
      );
      print('token : $token');
      if (response.statusCode == 200) {
        if (mounted) {
          CustomOverlay.showSuccess(
            context,
            message: 'Mot de passe mis à jour avec succès',
          );

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => AuthentificationPage()),
                (route) => false,
              );
            }
          });
        }
      } else {
        final errorData = json.decode(response.body);
        print("⚠️ $errorData['message']");
        throw Exception(errorData['message'] ??
            'Erreur lors de la mise à jour du mot de passe');
      }
    } catch (e) {
      if (mounted) {
        print("⚠️❌ $e");
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPasswordFields(double formWidth) {
    return Column(
      children: [
        AuthFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          hintText: 'Entrez le nouveau mot de passe',
          prefixIcon: Icons.lock,
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
          textInputAction: TextInputAction.next,
          onEditingComplete: () {
            FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
          },
        ),
        const SizedBox(height: 16),
        AuthFormField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocusNode,
          hintText: 'Confirmez le mot de passe',
          prefixIcon: Icons.lock,
          obscureText: !_isConfirmPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isConfirmPasswordVisible
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
            },
          ),
          textInputAction: TextInputAction.done,
          onEditingComplete: () {
            _confirmPasswordFocusNode.unfocus();
          },
        ),
      ],
    );
  }

  Widget _buildHeader(double titleSize) {
    return AnimatedOpacity(
      duration: AppConfig.animationDuration,
      opacity: isKeyboardVisible ? 0.8 : 1.0,
      child: Text(
        "Réinitialisation du mot de passe",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: titleSize,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final formWidth =
        size.width > AppConfig.mobileBreakpoint ? 500.0 : size.width * 0.9;
    final titleSize = isKeyboardVisible ? size.width * 0.04 : size.width * 0.05;
    final messageSize =
        isKeyboardVisible ? size.width * 0.03 : size.width * 0.035;

    return Scaffold(
      backgroundColor: AppConfig.primaryColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.05,
                vertical:
                    isKeyboardVisible ? size.height * 0.02 : size.height * 0.05,
              ),
              constraints: BoxConstraints(
                minHeight: size.height - MediaQuery.of(context).padding.top,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isKeyboardVisible) SizedBox(height: size.height * 0.1),
                  _buildHeader(titleSize),
                  SizedBox(height: size.height * 0.04),
                  SizedBox(
                    width: formWidth,
                    child: _buildPasswordFields(formWidth),
                  ),
                  SizedBox(height: size.height * 0.02),
                  Container(
                    width: formWidth,
                    margin: EdgeInsets.symmetric(vertical: size.height * 0.02),
                    child: Text(
                      "Le mot de passe doit contenir au moins 8 caractères, une majuscule, une minuscule, un chiffre et un caractère spécial.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: messageSize,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                  if (!isKeyboardVisible || size.height > 500)
                    SizedBox(
                      width: formWidth,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                if (_validatePassword()) {
                                  await updatePassword(
                                      widget.token, _passwordController.text);
                                }
                              },
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                            (states) {
                              return states.contains(WidgetState.disabled)
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.white;
                            },
                          ),
                          foregroundColor:
                              WidgetStateProperty.all(AppConfig.primaryColor),
                          padding: WidgetStateProperty.all(
                            EdgeInsets.symmetric(
                              vertical: size.height * 0.02,
                              horizontal: size.width * 0.08,
                            ),
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100000),
                            ),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppConfig.primaryColor,
                                  ),
                                ),
                              )
                            : const Text(
                                'Réinitialiser le mot de passe',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  if (!isKeyboardVisible) ...[
                    SizedBox(height: size.height * 0.04),
                    Container(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "N'avez-vous pas un compte ?",
                            style: TextStyle(color: Colors.grey[300]),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupPage(),
                              ),
                            ),
                            child: const Text(
                              'Créer un compte',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// ignore: unused_element
  void _showSuccessSnackBar(String message) {
    CustomOverlay.showSuccess(context, message: message);
  }
}
