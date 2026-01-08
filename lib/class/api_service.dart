// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use, unused_element

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wortis/class/uploaded_file.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/class/webviews.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class ApiService {
  static const String baseUrl = 'https://api.live.wortis.cg';
  final Map<String, http.Client> _clients = {};

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ============================================
  // RÉCUPÉRATION DES CHAMPS DE SERVICE
  // ============================================

  Future<Map<String, dynamic>> fetchServiceFields(String service) async {
    try {
      final String countryCode = await ZoneBenefManager.getZoneBenef() ?? 'CG';

      print('Code pays: $countryCode');

      final Map<String, dynamic> requestData = {
        'service': service,
        'country_code': countryCode,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/service_test'),
        headers: _headers,
        body: jsonEncode(requestData),
      );

      _validateResponse(response);
      return jsonDecode(response.body);
    } catch (e) {
      print('Erreur fetchServiceFields: $e');
      throw _handleError('Récupération des champs', e);
    }
  }

  // ============================================
  // VÉRIFICATION DES DONNÉES
  // ============================================

  Future<Map<String, dynamic>> verifyDataGet(
    String url,
    Map<String, dynamic> params,
  ) async {
    try {
      if (!url.startsWith('http')) {
        url = baseUrl + url;
      }

      final uri = Uri.parse(url).replace(
        queryParameters: params.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );

      print('Vérification GET: $uri');

      final response = await http.get(uri, headers: _headers);

      print('Status: ${response.statusCode}');

      if (response.statusCode >= 300) {
        throw Exception('not_found');
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('Erreur verifyDataGet: $e');
      throw Exception('not_found');
    }
  }

  Future<Map<String, dynamic>> verifyDataPost(
    String url,
    Map<String, dynamic> data, [
    String? operationId,
  ]) async {
    final client = operationId != null
        ? _createClient(operationId)
        : http.Client();

    try {
      if (!url.startsWith('http')) {
        url = baseUrl + url;
      }

      print('Vérification POST: $url');

      final response = await client.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(_sanitizeData(data)),
      );

      print('Status: ${response.statusCode}');

      if (response.statusCode >= 300) {
        throw Exception('not_found');
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('Erreur verifyDataPost: $e');
      throw Exception('not_found');
    } finally {
      if (operationId == null) {
        client.close();
      }
    }
  }

  // ============================================
  // SOUMISSION DU FORMULAIRE (SIMPLIFIÉ)
  // ============================================

  Future<bool> submitFormData(
    BuildContext context,
    String url,
    Map<String, dynamic> data,
    Map<String, dynamic>? serviceData, [
    String? operationId,
    bool isCard = false,
  ]) async {
    // Ajouter le token
    final token = await SessionManager.getToken();
    data['token'] = token;

    final client = operationId != null
        ? _createClient(operationId)
        : http.Client();

    try {
      // Construire l'URL complète
      if (!url.startsWith('http')) {
        url = baseUrl + url;
      }

      print('=' * 50);
      print('🚀 Soumission formulaire');
      print('=' * 50);
      print('📍 URL: $url');
      print('💳 Carte bancaire: $isCard');

      // Détecter si on a des fichiers
      bool hasFiles = _hasFiles(data);

      print('📦 Type de requête: ${hasFiles ? "MULTIPART" : "JSON"}');

      // Choisir la méthode d'envoi
      http.Response response = hasFiles
          ? await _sendMultipart(client, url, data)
          : await _sendJson(client, url, data);

      print('📥 Réponse: ${response.statusCode}');
      print('=' * 50);

      // Traiter la réponse
      return await _handleResponse(context, response, serviceData, isCard);
    } catch (e) {
      print('❌ Erreur: $e');
      if (context.mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors de la soumission',
        );
      }
      return false;
    } finally {
      if (operationId == null) {
        client.close();
      }
    }
  }

  // ============================================
  // DÉTECTION ET ENVOI DES FICHIERS
  // ============================================

  bool _hasFiles(Map<String, dynamic> data) {
    for (var value in data.values) {
      if (value is UploadedFile) {
        print('✅ Fichier détecté (unique)');
        return true;
      }
      if (value is List && value.isNotEmpty && value.first is UploadedFile) {
        print('✅ Fichiers détectés (liste)');
        return true;
      }
    }
    return false;
  }

  Future<http.Response> _sendMultipart(
    http.Client client,
    String url,
    Map<String, dynamic> data,
  ) async {
    print('📤 Envoi multipart/form-data');

    var request = http.MultipartRequest('POST', Uri.parse(url));

    int filesCount = 0;
    int fieldsCount = 0;

    for (var entry in data.entries) {
      String key = entry.key;
      var value = entry.value;

      if (value is UploadedFile) {
        // Fichier unique
        await _addFile(request, key, value);
        filesCount++;
      } else if (value is List &&
          value.isNotEmpty &&
          value.first is UploadedFile) {
        // Liste de fichiers
        if (value.length == 1) {
          // Un seul fichier : pas d'index
          await _addFile(request, key, value[0]);
          filesCount++;
        } else {
          // Plusieurs fichiers : avec index
          for (int i = 0; i < value.length; i++) {
            await _addFile(request, '$key[$i]', value[i]);
            filesCount++;
          }
        }
      } else if (value != null) {
        // Champ texte
        request.fields[key] = value.toString();
        fieldsCount++;
      }
    }

    print('📊 Résumé:');
    print('  - Champs: $fieldsCount');
    print('  - Fichiers: $filesCount');

    // Debug détaillé
    print('📋 Champs envoyés:');
    request.fields.forEach((key, value) {
      String display = value.length > 50
          ? '${value.substring(0, 50)}...'
          : value;
      print('  - $key: $display');
    });

    print('📎 Fichiers envoyés:');
    for (var file in request.files) {
      print('  - ${file.field}: ${file.filename} (${file.length} bytes)');
    }

    print('🚀 Envoi...');
    var streamedResponse = await client.send(request);
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      print('⚠️ Erreur: ${response.body}');
    }

    return response;
  }

  Future<void> _addFile(
    http.MultipartRequest request,
    String fieldName,
    UploadedFile file,
  ) async {
    try {
      final fileObj = File(file.path);

      if (!await fileObj.exists()) {
        print('  ⚠️ Fichier introuvable: ${file.path}');
        return;
      }

      final bytes = await fileObj.readAsBytes();
      final mime =
          file.mimeType ??
          lookupMimeType(file.path) ??
          'application/octet-stream';
      final parts = mime.split('/');

      final multipartFile = http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: file.name,
        contentType: MediaType(parts[0], parts[1]),
      );

      request.files.add(multipartFile);
      print('  ✅ $fieldName: ${file.name} (${bytes.length} bytes)');
    } catch (e) {
      print('  ❌ Erreur $fieldName: $e');
    }
  }

  Future<http.Response> _sendJson(
    http.Client client,
    String url,
    Map<String, dynamic> data,
  ) async {
    print('📤 Envoi application/json');

    return await client.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(_sanitizeData(data)),
    );
  }

  // ============================================
  // TRAITEMENT DES RÉPONSES
  // ============================================

  Future<bool> _handleResponse(
    BuildContext context,
    http.Response response,
    Map<String, dynamic>? serviceData,
    bool isCard,
  ) async {
    // Succès (200-299)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);

      // Gérer les redirections de paiement
      if (isCard && data['Lien'] != null && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceWebView(url: data['Lien']),
          ),
        );

        if (context.mounted && data['transID'] != null) {
          showTransactionCheckingDialog(context, data['transID'], isCard: true);
        }
      } else if (data['transID'] != null && context.mounted) {
        showTransactionCheckingDialog(context, data['transID'], isCard: false);
      }

      if (context.mounted) {
        CustomOverlay.showSuccess(
          context,
          message: 'Formulaire soumis avec succès !',
        );
      }
      return true;
    }

    // Erreur (400+)
    if (context.mounted) {
      try {
        final data = jsonDecode(response.body);
        String errorMsg = _extractErrorMessage(data);

        // Utiliser les messages personnalisés si disponibles
        if (response.statusCode >= 400 && response.statusCode < 500) {
          errorMsg = errorMsg ?? serviceData?['error_400'];
        } else if (response.statusCode >= 500) {
          errorMsg = errorMsg ?? serviceData?['error_500'];
        }

        CustomOverlay.showError(context, message: errorMsg);
      } catch (e) {
        CustomOverlay.showError(
          context,
          message: 'Erreur ${response.statusCode}: ${response.body}',
        );
      }
    }

    return false;
  }

  String _extractErrorMessage(Map<String, dynamic> data) {
    // Essayer différentes clés possibles pour le message d'erreur
    var message =
        data['message'] ??
        data['error'] ??
        data['Erreur'] ??
        data['erreur'] ??
        data['Error'];

    // Si c'est un objet, creuser plus profond
    if (message is Map<String, dynamic>) {
      message =
          message['message'] ??
          message['error'] ??
          'Erreur lors de la soumission';
    }

    return message?.toString() ?? 'Erreur lors de la soumission';
  }

  // ============================================
  // GESTION DES NOTIFICATIONS
  // ============================================

  Future<void> createNotification(String status) async {
    final token = await SessionManager.getToken();
    if (token == null) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/create_notifications_test'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'type': status == "SUCCESSFUL" || status == '200'
              ? 'paiement'
              : 'kdo',
          'contenu': status == "SUCCESSFUL" || status == '200'
              ? 'Votre paiement a été effectué avec succès'
              : 'Échec de votre paiement',
          'user_id': token,
          'icone': 'payment',
          'title': status == "SUCCESSFUL" || status == '200'
              ? 'Paiement réussi'
              : 'Paiement échoué',
        }),
      );
    } catch (e) {
      print('Erreur création notification: $e');
    }
  }

  // ============================================
  // VÉRIFICATION DES TRANSACTIONS
  // ============================================

  void _startTransactionCheck(
    BuildContext context,
    String reference, {
    required bool isCard,
  }) {
    Timer? timer;
    bool isCompleted = false;

    Future<void> handlePaymentStatus(String status) async {
      if (isCompleted) return;

      isCompleted = true;
      timer?.cancel();

      await createNotification(status);

      if (context.mounted) {
        Navigator.of(context).pop();

        if (status == "SUCCESSFUL" || status == "200") {
          _showResultDialog(context, '', true);
        } else {
          _showResultDialog(context, '', false);
        }
      }
    }

    Future<void> checkTransaction() async {
      if (isCompleted) {
        timer?.cancel();
        return;
      }

      try {
        final checkingUrl = isCard
            ? '$baseUrl/check_transac_cb'
            : '$baseUrl/check_transac';
        final requestBody = isCard
            ? {'uniqueID': reference}
            : {'transac': reference};

        final response = await http.post(
          Uri.parse(checkingUrl),
          headers: _headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          final paymentStatus = result['status'];

          if (paymentStatus == "FAILED" ||
              paymentStatus == "SUCCESSFUL" ||
              paymentStatus == "200") {
            await handlePaymentStatus(paymentStatus);
          }
        }
      } catch (e) {
        print('Erreur de vérification: $e');
      }
    }

    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!isCompleted) {
        checkTransaction();
      }
    });

    Future.delayed(const Duration(seconds: 60), () async {
      if (!isCompleted) {
        await handlePaymentStatus("FAILED");
      }
    });
  }

  Future<void> showTransactionCheckingDialog(
    BuildContext context,
    String reference, {
    bool isCard = false,
  }) {
    _startTransactionCheck(context, reference, isCard: isCard);
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          TransactionCheckingDialog(reference: reference, isCard: isCard),
    );
  }

  void _showResultDialog(BuildContext context, String message, bool isSuccess) {
    // Cette méthode peut être implémentée si nécessaire
    // Pour l'instant, les notifications suffisent
  }

  // ============================================
  // MÉTHODES UTILITAIRES
  // ============================================

  void _validateResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String errorMessage;
    try {
      final errorBody = jsonDecode(response.body);
      errorMessage =
          errorBody['message'] ?? errorBody['error'] ?? 'Erreur inconnue';
    } catch (_) {
      errorMessage = 'Erreur HTTP: ${response.statusCode}';
    }

    throw Exception(errorMessage);
  }

  bool _isErrorResponse(Map<String, dynamic> response) {
    if (response['status'] == false || response['status'] == 'false') {
      return true;
    }

    if (response['success'] == false || response['success'] == 'false') {
      return true;
    }

    if (response['error'] != null) {
      return true;
    }

    return false;
  }

  Exception _handleError(String operation, dynamic error) {
    String errorMessage;
    if (error is Exception) {
      errorMessage = error.toString().replaceAll('Exception: ', '');
    } else {
      errorMessage = error.toString();
    }
    return Exception('Erreur lors de $operation: $errorMessage');
  }

  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is num) {
        return MapEntry(key, value.toString());
      }
      if (value == null) {
        return MapEntry(key, '');
      }
      if (value is String) {
        return MapEntry(key, value.trim());
      }
      return MapEntry(key, value);
    });
  }

  Future<bool> checkConnectivity() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void cancelOperation([String? operationId]) {
    if (operationId != null) {
      _clients[operationId]?.close();
      _clients.remove(operationId);
    } else {
      _clients.forEach((_, client) => client.close());
      _clients.clear();
    }
  }

  http.Client _createClient(String operationId) {
    final client = http.Client();
    _clients[operationId] = client;
    return client;
  }
}

// ============================================
// DIALOGUE DE VÉRIFICATION DE TRANSACTION
// ============================================

class TransactionCheckingDialog extends StatefulWidget {
  final String reference;
  final bool isCard;

  const TransactionCheckingDialog({
    super.key,
    required this.reference,
    this.isCard = false,
  });

  @override
  _TransactionCheckingDialogState createState() =>
      _TransactionCheckingDialogState();
}

class _TransactionCheckingDialogState extends State<TransactionCheckingDialog> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : size.width * 0.1,
          vertical: isSmallScreen ? 24 : size.height * 0.1,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              constraints: BoxConstraints(
                maxHeight: isSmallScreen
                    ? size.height * 0.8
                    : size.height * 0.6,
                minHeight: 200,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isSmallScreen ? 80 : 100,
                        height: isSmallScreen ? 80 : 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF006699).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.payment,
                          size: isSmallScreen ? 40 : 50,
                          color: const Color(0xFF006699),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 28),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'En attente de paiement',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 22 : 26,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      Text(
                        'Veuillez confirmer le paiement sur votre téléphone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          color: const Color(0xFF5D6D7E),
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Text(
                        'Une notification vous sera envoyée dès que le paiement sera validé.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: const Color(0xFF7F8C8D),
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 20,
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE9ECEF),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: isSmallScreen ? 18 : 20,
                              color: const Color(0xFF006699),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Référence: ${widget.reference.length > 12 ? "${widget.reference.substring(0, 12)}..." : widget.reference}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 15,
                                color: const Color(0xFF495057),
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 24 : 32),
                      SizedBox(
                        width: double.infinity,
                        height: isSmallScreen ? 50 : 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006699),
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: const Color(
                              0xFF006699,
                            ).withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: isSmallScreen ? 20 : 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Compris',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vous pouvez fermer cette fenêtre',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: const Color(0xFF95A5A6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
