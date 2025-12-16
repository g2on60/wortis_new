// ignore_for_file: file_names, use_super_parameters, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:wortis/class/class.dart';

class PaymentRequestPage extends StatefulWidget {
  final String requestUrl;

  const PaymentRequestPage({
    Key? key,
    required this.requestUrl,
  }) : super(key: key);

  @override
  State<PaymentRequestPage> createState() => _PaymentRequestPageState();
}

class PaymentModal extends StatefulWidget {
  final Map<String, dynamic> paymentSection;
  final String reservationId;
  final Map<String, dynamic> paymentData;

  const PaymentModal({
    Key? key,
    required this.paymentSection,
    required this.reservationId,
    required this.paymentData,
  }) : super(key: key);

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String? selectedPaymentMode;
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get fieldsConfig =>
      widget.paymentSection['fields_paiement'] ?? {};

  Map<String, dynamic> get paymentData => widget.paymentData;

  @override
  void initState() {
    super.initState();
    ConnectivityManager(context).initConnectivity;
    _controllers['numero_paiement'] = TextEditingController();
    _controllers['nom_titulaire'] = TextEditingController();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  bool _shouldShowField(String fieldName) {
    final field = fieldsConfig[fieldName];
    if (field == null) return false;

    final dependencies = field['dependencies'] as List?;
    if (dependencies == null) return true;

    return dependencies.any((dep) =>
        dep['field'] == 'mode_paiement' && dep['value'] == selectedPaymentMode);
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final request = widget.paymentSection['request'];
      if (request == null) {
        throw Exception('Configuration de la requête manquante');
      }

      final endpoint = request['endpoints'][selectedPaymentMode];
      final bodyMapping = request['body_mapping'][selectedPaymentMode];

      dynamic extractValue(String path) {
        final parts = path.split('.');
        dynamic current;

        if (parts[0] == 'sections') {
          final sections =
              paymentData['enregistrement_unique']['sections'] as List;
          for (var section in sections) {
            if (section['title'] == parts[1]) {
              if (parts[2] == 'fields') {
                final fields = section['fields'] as List;
                for (var field in fields) {
                  if (field['label'] == parts[3]) {
                    return field['value'];
                  }
                }
              }
              current = section;
              break;
            }
          }
          parts.removeRange(0, 2);
        } else {
          current = widget.paymentSection;
        }

        for (var part in parts) {
          if (current is Map) {
            current = current[part];
          } else if (current is List && int.tryParse(part) != null) {
            current = current[int.parse(part)];
          } else {
            current = null;
            break;
          }
        }
        return current;
      }

      final Map<String, dynamic> requestBody = {};
      bodyMapping.forEach((key, path) {
        if (path == '_id') {
          requestBody[key] = widget.reservationId;
        } else if (path.startsWith('fields_paiement.')) {
          final fieldName = path.split('.')[1];
          requestBody[key] = _controllers[fieldName]?.text;
        } else {
          final value = extractValue(path);
          if (value != null) {
            requestBody[key] = value;
          }
        }
      });

      print('Request Body: $requestBody');

      CustomOverlay.showLoading(context,
          message: 'Traitement du paiement en cours...');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: Map<String, String>.from(request['headers'] ?? {}),
        body: json.encode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final transactionId = responseData['transID'];

        if (mounted) {
          CustomOverlay.showLoading(context,
              message: 'Vérification du paiement en cours...');
        }

        bool transactionComplete = false;
        int attempts = 0;
        final maxAttempts = 45; // 90 secondes avec 2 secondes d'intervalle

        while (!transactionComplete && attempts < maxAttempts) {
          try {
            final checkResponse = await http.post(
                Uri.parse('https://api.live.wortis.cg/check_transac_box'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(
                    {"mode": selectedPaymentMode, "transac": transactionId}));

            print('Check response status: ${checkResponse.statusCode}');
            print('Check response body: ${checkResponse.body}');

            if (checkResponse.statusCode == 200) {
              final checkData = json.decode(checkResponse.body);
              final status = checkData['status'];

              if (status == "200" || status == "SUCCESSFUL") {
                transactionComplete = true;
                if (mounted) {
                  // Créer la notification
                  await createNotification(status);
                  CustomOverlay.hide();
                  CustomOverlay.showSuccess(context,
                      message: 'Paiement effectué avec succès');
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      Navigator.of(context).pop(true);
                    }
                  });
                }
                break;
              } else if (status == "FAILED") {
                transactionComplete = true;
                if (mounted) {
                  CustomOverlay.hide();
                  CustomOverlay.showError(context,
                      message: 'La transaction a échoué');
                }
                break;
              }
            }

            attempts++;
            await Future.delayed(const Duration(seconds: 2));
          } catch (e) {
            print('Erreur lors de la vérification: $e');
          }
        }

        if (!transactionComplete && mounted) {
          CustomOverlay.hide();
          CustomOverlay.showError(context,
              message: 'Le paiement n\'a pas abouti après 90 secondes');
        }
      } else {
        throw Exception('Échec du paiement');
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        CustomOverlay.hide();
        CustomOverlay.showError(context,
            message: 'Une erreur est survenue lors du paiement');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> createNotification(String status) async {
    final token = await SessionManager.getToken();
    if (token == null) return;

    try {
      // ignore: unused_local_variable
      final response = await http.post(
        Uri.parse('$baseUrl/create_notifications'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'type': 'paiement',
          'contenu': status == "SUCCESSFUL"
              ? 'Votre paiement a été effectué avec succès'
              : 'Échec de votre paiement',
          'user_id': token,
          'icone': 'payment',
          'title':
              status == "SUCCESSFUL" ? 'Paiement réussi' : 'Paiement échoué'
        }),
      );
    } catch (e) {
      print('Erreur création notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Paiement',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006699).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${widget.paymentSection['amount']['label']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.paymentSection['amount']['value'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006699),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (fieldsConfig.containsKey('mode_paiement')) ...[
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: fieldsConfig['mode_paiement']['label'],
                      border: const OutlineInputBorder(),
                    ),
                    initialValue: selectedPaymentMode,
                    items: (fieldsConfig['mode_paiement']['options'] as List?)
                            ?.map<DropdownMenuItem<String>>((option) {
                          return DropdownMenuItem(
                            value: option['value'],
                            child: Text(option['label']),
                          );
                        }).toList() ??
                        [],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez sélectionner un mode de paiement';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        selectedPaymentMode = value;
                        _controllers
                            .forEach((_, controller) => controller.clear());
                      });
                    },
                  ),
                ],
                if (selectedPaymentMode != null) ...[
                  if (_shouldShowField('numero_paiement')) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['numero_paiement'],
                      decoration: InputDecoration(
                        labelText: fieldsConfig['numero_paiement']['label'],
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (fieldsConfig['numero_paiement']['required'] ==
                                true &&
                            (value == null || value.isEmpty)) {
                          return 'Ce champ est requis';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (_shouldShowField('nom_titulaire')) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['nom_titulaire'],
                      decoration: InputDecoration(
                        labelText: fieldsConfig['nom_titulaire']['label'],
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (fieldsConfig['nom_titulaire']['required'] == true &&
                            (value == null || value.isEmpty)) {
                          return 'Ce champ est requis';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handlePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006699),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirmer le paiement',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentRequestPageState extends State<PaymentRequestPage> {
  Map<String, dynamic>? paymentData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    ConnectivityManager(context).initConnectivity;
    _loadPaymentData();
  }

  Future<void> _loadPaymentData() async {
    try {
      final response = await http.get(
        Uri.parse(widget.requestUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          setState(() {
            paymentData = data;
            isLoading = false;
          });
        } else {
          setState(() {
            error = 'Données invalides';
            isLoading = false;
          });
          CustomOverlay.showError(context,
              message: 'Les données reçues sont invalides');
        }
      } else {
        setState(() {
          error = 'Erreur lors de la récupération des données';
          isLoading = false;
        });
        CustomOverlay.showError(context,
            message: 'Erreur lors de la récupération des données');
      }
    } catch (e) {
      setState(() {
        error = 'Une erreur est survenue';
        isLoading = false;
      });
      CustomOverlay.showError(context,
          message: 'Une erreur est survenue lors du chargement');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildScaffold(
        title: 'Chargement...',
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF006699)),
        ),
      );
    }

    if (error != null) {
      return _buildScaffold(
        title: 'Erreur',
        body: _buildErrorWidget(),
      );
    }

    final data = paymentData!['enregistrement_unique'];
    final sections = data['sections'] as List;

    return _buildScaffold(
      title: paymentData!['page_title'] ?? 'Détails',
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sections.map<Widget>((section) {
                return _buildSection(section);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(Map<String, dynamic> section) {
    switch (section['title']) {
      case 'Informations principales':
        return _buildMainInfoSection(section);
      case 'Paiement':
        return _buildPaymentSection(section);
      default:
        return _buildGenericSection(section);
    }
  }

  Widget _buildMainInfoSection(Map<String, dynamic> section) {
    return Column(
      children: [
        if (section['main_image'] != null)
          Container(
            width: double.infinity,
            height: 200,
            child: Image.network(
              Uri.encodeFull(section['main_image']),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildImageError(),
              loadingBuilder: (context, child, loadingProgress) =>
                  _buildImageLoading(child, loadingProgress),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (section['main_title'] != null)
                Text(
                  section['main_title']['value'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.start,
                ),
              if (section['code'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006699).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${section['code']['label']}: ${section['code']['value']}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF006699),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenericSection(Map<String, dynamic> section) {
    final fields = section['fields'] as List?;
    if (fields == null || fields.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            section['title'],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006699),
            ),
          ),
          const SizedBox(height: 12),
          ...fields.map<Widget>((field) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field['label'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    field['value'],
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(Map<String, dynamic> section) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${section['amount']['label']} : ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  section['amount']['value'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006699),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => PaymentModal(
                      paymentSection: section,
                      reservationId:
                          paymentData?['enregistrement_unique']['_id'] ?? '',
                      paymentData: paymentData!,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006699),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  section['button']['text'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildImageLoading(Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress == null) return child;
    return Center(
      child: CircularProgressIndicator(
        value: loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes!
            : null,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFF006699),
            size: 48,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _loadPaymentData();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006699),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaffold({required String title, required Widget body}) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF006699),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: body,
    );
  }
}
