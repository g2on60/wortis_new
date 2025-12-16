import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WortisSubscriptionPage extends StatefulWidget {
  final Map<String, String>? params;

  const WortisSubscriptionPage({super.key, this.params});

  @override
  State<WortisSubscriptionPage> createState() => _WortisSubscriptionPageState();
}

class _WortisSubscriptionPageState extends State<WortisSubscriptionPage> {
  // Variables globales
  late Map<String, String> serviceParams;
  List<dynamic> availableServices = [];
  Map<String, dynamic>? selectedService;
  Map<String, dynamic>? selectedPlan;
  Map<String, dynamic>? subscriptionData;
  Map<String, dynamic>? currentTransaction;
  Map<String, dynamic>? currentStripeSubscription;

  // État de l'interface
  bool isLoading = true;
  String loadingMessage = 'Chargement des plans disponibles...';
  bool showPlanSelection = false;
  bool hasExistingSubscription = false;
  int currentSection = 1; // 1: abonnement, 2: paiement

  // Contrôleurs de formulaire
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _subscriptionNumberController =
      TextEditingController();

  // Configuration pays
  final Map<String, Map<String, String>> countryCodes = {
    'CM': {'flag': '🇨🇲', 'dial': '+237'},
    'SN': {'flag': '🇸🇳', 'dial': '+221'},
    'CG': {'flag': '🇨🇬', 'dial': '+242'},
    'CI': {'flag': '🇨🇮', 'dial': '+225'},
    'BF': {'flag': '🇧🇫', 'dial': '+226'},
    'ML': {'flag': '🇲🇱', 'dial': '+223'},
    'GA': {'flag': '🇬🇦', 'dial': '+241'},
    'BJ': {'flag': '🇧🇯', 'dial': '+229'},
    'TG': {'flag': '🇹🇬', 'dial': '+228'},
  };

  String get currentFlag =>
      countryCodes[serviceParams['eligibleCountries']?.toUpperCase()]
          ?['flag'] ??
      '🇨🇬';
  String get currentDialCode =>
      countryCodes[serviceParams['eligibleCountries']?.toUpperCase()]
          ?['dial'] ??
      '+242';

  @override
  void initState() {
    super.initState();
    _initializeParams();
    _loadPlans();
  }

  void _initializeParams() {
    serviceParams = {
      'serviceName': Uri.decodeComponent(widget.params?['service'] ??
          widget.params?['service_name'] ??
          'Service Internet'),
      'userToken':
          widget.params?['token'] ?? widget.params?['user_token'] ?? '',
      'eligibleCountries': widget.params?['countries'] ??
          widget.params?['eligible_countries'] ??
          'CG',
      'logo': widget.params?['logo'] ?? '',
      'source': widget.params?['source'] ?? 'mobile_app',
      'timestamp': widget.params?['timestamp'] ??
          widget.params?['ts'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
    };
    print('🔍 Paramètres reçus: $serviceParams');
  }

  Future<void> _loadPlans() async {
    try {
      setState(() {
        isLoading = true;
        loadingMessage = 'Chargement des plans disponibles...';
      });

      final response = await http.get(
        Uri.parse('https://api.live.wortis.cg/famlink/api/services'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        availableServices = data['services'] ?? [];
        _findMatchingService();
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (error) {
      print('❌ Erreur lors du chargement: $error');
      _showError('Erreur de connexion: $error');
    }
  }

  void _findMatchingService() {
    final serviceName = serviceParams['serviceName']!;
    Map<String, dynamic>? bestMatch;

    for (var service in availableServices) {
      final nameMatch = _normalizeString(serviceName)
              .contains(_normalizeString(service['name'])) ||
          _normalizeString(service['name'])
              .contains(_normalizeString(serviceName));

      if (nameMatch) {
        bestMatch = service;
        break;
      }
    }

    if (bestMatch == null && availableServices.isNotEmpty) {
      bestMatch = availableServices[0];
    }

    selectedService = bestMatch;

    if (selectedService != null) {
      print('🎯 Service sélectionné: "${selectedService!['name']}"');
      _displayServiceAndPlans();
    } else {
      _showError('Aucun service trouvé');
    }
  }

  void _displayServiceAndPlans() {
    // Filtrer les plans selon le pays
    final countryCode = serviceParams['eligibleCountries']!.toUpperCase();
    List<dynamic> filteredPlans = (selectedService!['plans'] as List<dynamic>?)
            ?.where((plan) =>
                (plan['countries'] as List<dynamic>).contains(countryCode))
            .toList() ??
        [];

    if (filteredPlans.isEmpty) {
      filteredPlans = selectedService!['plans'] ?? [];
    }

    if (filteredPlans.isEmpty) {
      _showError('Aucun plan disponible');
      return;
    }

    setState(() {
      isLoading = false;
      if (filteredPlans.length == 1) {
        // Un seul plan : auto-sélection
        selectedPlan = filteredPlans[0];
        showPlanSelection = false;
        print('📋 Plan auto-sélectionné: ${selectedPlan!['name']}');
      } else {
        // Plusieurs plans : affichage de la sélection
        showPlanSelection = true;
        selectedPlan = filteredPlans[0]; // Auto-sélectionner le premier
        print(
            '📋 ${filteredPlans.length} plans disponibles, affichage de la sélection');
      }
    });
  }

  void _selectPlan(Map<String, dynamic> plan) {
    setState(() {
      selectedPlan = plan;
    });
    print('📋 Plan sélectionné: ${plan['name']}');
  }

  Future<void> _handleSubscriptionSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (hasExistingSubscription &&
        _subscriptionNumberController.text.trim().isEmpty) {
      _showError('Veuillez saisir le numéro d\'abonnement existant.');
      return;
    }

    setState(() {
      isLoading = true;
      loadingMessage = 'Création de l\'abonnement...';
    });

    try {
      final result = await _createSubscription();
      if (result['success']) {
        subscriptionData = result['data'];
        print('✅ Abonnement créé: $subscriptionData');
        _showPaymentSection();
      } else {
        throw Exception(result['error']);
      }
    } catch (error) {
      print('❌ Erreur création abonnement: $error');
      _showError('Erreur: $error');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _createSubscription() async {
    final installationInfo = <String, dynamic>{
      'existing_installation': hasExistingSubscription,
    };

    if (hasExistingSubscription) {
      installationInfo['subscription_number'] =
          _subscriptionNumberController.text.trim();
    } else {
      installationInfo.addAll({
        'address': _addressController.text.trim(),
        'district': _districtController.text.trim(),
        'city': _cityController.text.trim(),
        'contact_name': _nameController.text.trim(),
        'contact_email': _emailController.text.trim(),
        'contact_phone': currentDialCode + _phoneController.text.trim(),
        'notes': _notesController.text.trim(),
      });
    }

    final apiData = {
      'service_id': selectedService!['_services'],
      'plan_id': selectedPlan!['id'],
      'country': serviceParams['eligibleCountries']!.toUpperCase(),
      'installation_info': installationInfo,
    };

    final token = serviceParams['userToken'];
    if (token == null || token.isEmpty) {
      throw Exception('Token utilisateur manquant');
    }

    final apiUrl =
        'https://api.live.wortis.cg/famlink/api/subscriptions/$token';

    // Stratégie retry
    for (int tentative = 1; tentative <= 2; tentative++) {
      try {
        print('📡 Tentative $tentative/2 vers l\'API: $apiUrl');
        print('📦 Payload: ${json.encode(apiData)}');

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(apiData),
        );

        print('📊 Tentative $tentative - Status: ${response.statusCode}');

        Map<String, dynamic> responseData;
        try {
          responseData = json.decode(response.body);
        } catch (parseError) {
          print('❌ Tentative $tentative - Erreur parsing JSON: $parseError');
          if (tentative == 2) {
            throw Exception('Réponse invalide du serveur');
          }
          continue;
        }

        print('📨 Tentative $tentative - Réponse: $responseData');

        if (response.statusCode == 200) {
          print('🎉 Succès à la tentative $tentative !');
          return {
            'success': true,
            'data': responseData,
            'tentative': tentative
          };
        }

        final errorMessage =
            responseData['error'] ?? responseData['message'] ?? '';
        if (errorMessage.contains('abonnement') &&
            errorMessage.contains('existe déjà')) {
          print(
              '🎉 Succès détecté à la tentative $tentative (abonnement créé précédemment) !');
          return {
            'success': true,
            'data': {
              'message': 'Abonnement créé avec succès',
              'subscription': {
                '_subscriptions': 'Créé lors de la tentative précédente',
                'service_id': apiData['service_id'],
                'plan_id': apiData['plan_id'],
                'installation_info': apiData['installation_info'],
              }
            },
            'tentative': tentative,
            'wasAlreadyCreated': true,
          };
        }

        print('❌ Tentative $tentative échouée: $errorMessage');

        if (tentative == 2) {
          return {'success': false, 'error': errorMessage};
        }

        await Future.delayed(const Duration(seconds: 1));
      } catch (networkError) {
        print('❌ Tentative $tentative - Erreur réseau: $networkError');

        if (tentative == 2) {
          return {
            'success': false,
            'error': 'Erreur de connexion: $networkError'
          };
        }

        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    return {
      'success': false,
      'error': 'Erreur inattendue dans la logique de retry'
    };
  }

  Future<Map<String, dynamic>> _createFamlinkTransaction() async {
    try {
      final installationFee =
          (selectedPlan!['installation_fee'] ?? 0).toDouble();
      final monthlyPrice = (selectedPlan!['price_monthly'] ?? 0).toDouble();
      final total = monthlyPrice + installationFee;

      String? subscriptionId;
      if (subscriptionData != null) {
        if (subscriptionData!['subscription'] != null &&
            subscriptionData!['subscription']['_subscriptions'] != null) {
          subscriptionId = subscriptionData!['subscription']['_subscriptions'];
        } else if (subscriptionData!['_subscriptions'] != null) {
          subscriptionId = subscriptionData!['_subscriptions'];
        }
      }

      final transactionData = {
        'amount': total,
        'currency': 'EUR',
        'payment_method': 'card',
        'subscription_id': subscriptionId,
        'description':
            'Paiement ${selectedService!['name']} - ${selectedPlan!['name']}',
      };

      final token = serviceParams['userToken'];
      final apiUrl =
          'https://api.live.wortis.cg/famlink/api/transactions/$token';

      print('💳 Création transaction Famlink: $transactionData');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(transactionData),
      );

      final responseData = json.decode(response.body);
      print('📨 Réponse transaction Famlink: $responseData');

      if (response.statusCode != 200) {
        throw Exception(responseData['error'] ??
            responseData['message'] ??
            'Erreur lors de la création de la transaction');
      }

      String? transactionId;
      if (responseData['transaction'] != null &&
          responseData['transaction']['_transactions'] != null) {
        transactionId = responseData['transaction']['_transactions'];
      } else if (responseData['transaction'] != null &&
          responseData['transaction']['_id'] != null) {
        transactionId = responseData['transaction']['_id'];
      } else if (responseData['transaction_id'] != null) {
        transactionId = responseData['transaction_id'];
      }

      print('✅ Transaction Famlink créée: $transactionId');

      return {
        'success': true,
        'data': responseData,
        'transactionId': transactionId,
      };
    } catch (error) {
      print('❌ Erreur création transaction Famlink: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _createStripeSubscription() async {
    try {
      String customerEmail = 'contact@example.com';
      String customerName = 'Client';

      if (!hasExistingSubscription) {
        customerEmail = _emailController.text;
        customerName = _nameController.text;
      }

      final installationFee =
          (selectedPlan!['installation_fee'] ?? 0).toDouble();
      String? priceId;

      if (installationFee > 0) {
        priceId = selectedPlan!['priceStripeID_inst'];
        print(
            '💰 Frais d\'installation: $installationFee€ → utilise priceStripeID_inst');
      } else {
        priceId = selectedPlan!['priceStripeID_sans_inst'];
        print(
            '🆓 Sans frais d\'installation → utilise priceStripeID_sans_inst');
      }

      if (priceId == null || priceId.isEmpty) {
        throw Exception(
            'Price ID manquant pour le plan "${selectedPlan!['name']}".');
      }

      final subscriptionData = {
        'email': customerEmail,
        'name': customerName,
        'price_id': priceId,
      };

      print('💳 Création abonnement Stripe: $subscriptionData');

      final response = await http.post(
        Uri.parse('https://api.live.wortis.cg/create-subscription'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(subscriptionData),
      );

      final responseData = json.decode(response.body);
      print('📨 Réponse abonnement Stripe: $responseData');

      if (response.statusCode != 200) {
        if (responseData['error'] != null &&
            responseData['error'].toString().contains('price')) {
          throw Exception(
              'Price ID "$priceId" non trouvé dans Stripe. Plan: ${selectedPlan!['name']}');
        }
        throw Exception(responseData['error'] ??
            'Erreur lors de la création de l\'abonnement Stripe');
      }

      return {
        'success': true,
        'data': responseData,
        'subscriptionId': responseData['subscription_id'],
        'customerId': responseData['customer_id'],
        'clientSecret': responseData['client_secret'] ??
            responseData['setup_intent_secret'],
        'requiresSetup': responseData['requires_setup'] ?? false,
        'paymentIntentId': responseData['payment_intent_id'],
        'usedPriceId': priceId,
        'installationFee': installationFee,
      };
    } catch (error) {
      print('❌ Erreur création abonnement Stripe: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  void _showPaymentSection() {
    setState(() {
      currentSection = 2;
    });
  }

  void _goBackToSubscription() {
    setState(() {
      currentSection = 1;
    });
  }

  String _normalizeString(String str) {
    return str
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $message'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5F7FA), Color(0xFFC3CFE2)],
            ),
          ),
          child: Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: isLoading
                        ? _buildLoading()
                        : currentSection == 1
                            ? _buildSubscriptionSection()
                            : _buildPaymentSection(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF006699), width: 3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (serviceParams['logo']?.isNotEmpty == true)
                Image.network(
                  serviceParams['logo']!,
                  height: 25,
                  width: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Image.network(
                    'https://app.wortis.cg/wortis.png',
                    height: 25,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Image.network(
                  'https://app.wortis.cg/wortis.png',
                  height: 25,
                  width: 120,
                  fit: BoxFit.contain,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006699)),
            ),
            const SizedBox(height: 20),
            Text(
              loadingMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bénéficiaire de l\'abonnement',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          if (selectedService != null) _buildServiceInfo(),
          if (showPlanSelection && selectedService != null)
            _buildPlanSelection(),
          _buildExistingSubscriptionCheck(),
          _buildSubscriptionForm(),
        ],
      ),
    );
  }

  Widget _buildServiceInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (selectedService!['logo_url'] != null)
            Image.network(
              selectedService!['logo_url'],
              width: 80,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          const SizedBox(height: 15),
          Text(
            selectedService!['name'],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006699),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            selectedService!['description'] ?? 'Service Internet',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
          if (!showPlanSelection && selectedPlan != null) ...[
            const SizedBox(height: 15),
            const Text(
              'PRIX MENSUEL',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${(selectedPlan!['price_monthly'] ?? 0).toStringAsFixed(2)} €/mois',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF28A745).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                (selectedPlan!['installation_fee'] ?? 0) == 0
                    ? '🎉 Installation gratuite'
                    : '⚡ Installation: ${(selectedPlan!['installation_fee'] ?? 0).toStringAsFixed(2)} €',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF28A745),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanSelection() {
    final countryCode = serviceParams['eligibleCountries']!.toUpperCase();
    List<dynamic> filteredPlans = (selectedService!['plans'] as List<dynamic>?)
            ?.where((plan) =>
                (plan['countries'] as List<dynamic>).contains(countryCode))
            .toList() ??
        [];

    if (filteredPlans.isEmpty) {
      filteredPlans = selectedService!['plans'] ?? [];
    }

    return Column(
      children: [
        const Text(
          '📋 Choisissez votre forfait',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF006699),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        ...filteredPlans.map((plan) => _buildPlanItem(plan)),
      ],
    );
  }

  Widget _buildPlanItem(Map<String, dynamic> plan) {
    final isSelected =
        selectedPlan != null && selectedPlan!['id'] == plan['id'];

    return GestureDetector(
      onTap: () => _selectPlan(plan),
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FBFF) : Colors.white,
          border: Border.all(
            color:
                isSelected ? const Color(0xFF006699) : const Color(0xFFE9ECEF),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF006699).withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006699),
                      ),
                    ),
                    Text(
                      '${(plan['price_monthly'] ?? 0).toStringAsFixed(2)} €/mois',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  plan['description'] ?? 'Forfait Internet haut débit',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  (plan['installation_fee'] ?? 0) == 0
                      ? '🎉 Installation gratuite'
                      : '⚡ Installation: ${(plan['installation_fee'] ?? 0).toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF28A745),
                  ),
                ),
                if (plan['features'] != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (plan['features'] as List<dynamic>)
                        .map((feature) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                feature.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF006699),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingSubscriptionCheck() {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 30),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    hasExistingSubscription = !hasExistingSubscription;
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: hasExistingSubscription
                        ? const Color(0xFF006699)
                        : Colors.white,
                    border:
                        Border.all(color: const Color(0xFF006699), width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: hasExistingSubscription
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    hasExistingSubscription = !hasExistingSubscription;
                  });
                },
                child: const Text(
                  'Abonnement existant',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006699),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Cochez cette case si le bénéficiaire dispose déjà d\'un abonnement pour ce service.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          if (hasExistingSubscription) ...[
            const SizedBox(height: 15),
            TextFormField(
              controller: _subscriptionNumberController,
              decoration: const InputDecoration(
                labelText: 'Numéro d\'abonnement existant',
                hintText: 'Saisissez le numéro d\'abonnement',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF006699), width: 2),
                ),
              ),
              validator: (value) {
                if (hasExistingSubscription &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Veuillez saisir le numéro d\'abonnement';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Votre numéro d\'abonnement se trouve sur votre facture ou votre contrat.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: hasExistingSubscription ? 0 : null,
            child: hasExistingSubscription
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _buildFormField(
                        controller: _nameController,
                        label: 'Nom du bénéficiaire',
                        isRequired: !hasExistingSubscription,
                      ),
                      _buildFormField(
                        controller: _emailController,
                        label: 'Email du bénéficiaire',
                        keyboardType: TextInputType.emailAddress,
                        isRequired: !hasExistingSubscription,
                      ),
                      _buildFormField(
                        controller: _addressController,
                        label: 'Adresse du bénéficiaire',
                        isRequired: !hasExistingSubscription,
                      ),
                      _buildFormField(
                        controller: _cityController,
                        label: 'Ville du bénéficiaire',
                        isRequired: !hasExistingSubscription,
                      ),
                      _buildPhoneField(),
                      _buildFormField(
                        controller: _districtController,
                        label: 'Quartier du bénéficiaire',
                        isRequired: !hasExistingSubscription,
                      ),
                      _buildFormField(
                        controller: _notesController,
                        label: 'Instructions spéciales (optionnel)',
                        maxLines: 3,
                        isRequired: false,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSubscriptionSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006699),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '🛒 Créer l\'abonnement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF006699), width: 2),
          ),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return 'Ce champ est requis';
          }
          if (keyboardType == TextInputType.emailAddress &&
              value != null &&
              value.isNotEmpty) {
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Veuillez saisir un email valide';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border.all(color: const Color(0xFFE9ECEF), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentFlag,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  currentDialCode,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down, size: 16),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone du bénéficiaire *',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF006699), width: 2),
                ),
              ),
              validator: (value) {
                if (!hasExistingSubscription &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Ce champ est requis';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    final installationFee = (selectedPlan!['installation_fee'] ?? 0).toDouble();
    final monthlyPrice = (selectedPlan!['price_monthly'] ?? 0).toDouble();
    final total = monthlyPrice + installationFee;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finaliser votre commande',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Votre demande est éligible ! Choisissez votre méthode de paiement pour finaliser votre abonnement.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildOrderSummary(),
          const SizedBox(height: 30),
          const Text(
            '💳 Informations de paiement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006699),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Entrez vos informations de carte pour finaliser l\'abonnement.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFD1ECF1),
              border: Border.all(color: const Color(0xFFBEE5EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, color: Color(0xFF0C5460)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vos informations sont protégées par un cryptage SSL 256-bit et traitées par Stripe.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0C5460),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _goBackToSubscription,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(15),
                    side: const BorderSide(color: Color(0xFF6C757D)),
                  ),
                  child: const Text(
                    '← Retour',
                    style: TextStyle(color: Color(0xFF6C757D)),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () async {
                    // Simulation du processus de paiement
                    setState(() {
                      isLoading = true;
                      loadingMessage = 'Traitement du paiement...';
                    });

                    try {
                      // Créer la transaction Famlink
                      final famlinkResult = await _createFamlinkTransaction();
                      if (!famlinkResult['success']) {
                        throw Exception(famlinkResult['error']);
                      }
                      currentTransaction = famlinkResult;

                      // Créer l'abonnement Stripe
                      final stripeResult = await _createStripeSubscription();
                      if (!stripeResult['success']) {
                        throw Exception(stripeResult['error']);
                      }
                      currentStripeSubscription = stripeResult;

                      // Simulation du succès du paiement
                      await Future.delayed(const Duration(seconds: 2));

                      setState(() {
                        isLoading = false;
                      });

                      _showSuccess(
                        'Félicitations ! Votre abonnement a été créé et payé avec succès. Un email de confirmation vous a été envoyé.',
                      );

                      // Redirection ou reset après 3 secondes
                      Future.delayed(const Duration(seconds: 3), () {
                        Navigator.of(context).pop();
                      });
                    } catch (error) {
                      setState(() {
                        isLoading = false;
                      });
                      _showError('Erreur: $error');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006699),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Payer maintenant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final installationFee = (selectedPlan!['installation_fee'] ?? 0).toDouble();
    final monthlyPrice = (selectedPlan!['price_monthly'] ?? 0).toDouble();
    final total = monthlyPrice + installationFee;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF006699), width: 2),
              ),
            ),
            child: const Text(
              '📋 Récapitulatif',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006699),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSummaryItem('Service', selectedService!['name']),
          _buildSummaryItem('Forfait', selectedPlan!['name']),
          _buildSummaryItem('Traitement', 'Sous 48h'),
          _buildSummaryItem(
            'Adresse',
            hasExistingSubscription
                ? 'Abonnement existant n°${_subscriptionNumberController.text}'
                : '${_addressController.text}, ${_cityController.text}',
          ),
          _buildSummaryItem('Frais d\'installation',
              '${installationFee.toStringAsFixed(2)} €'),
          _buildSummaryItem(
              'Montant mensuel', '${monthlyPrice.toStringAsFixed(2)} €'),
          const Divider(thickness: 2, color: Color(0xFF006699)),
          const SizedBox(height: 10),
          _buildSummaryItem(
            'Total à payer',
            '${total.toStringAsFixed(2)} €',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color:
                  isTotal ? const Color(0xFF006699) : const Color(0xFF666666),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.w600,
              color:
                  isTotal ? const Color(0xFF006699) : const Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    _notesController.dispose();
    _subscriptionNumberController.dispose();
    super.dispose();
  }
}
