// ignore_for_file: unused_local_variable, avoid_print, use_build_context_synchronously, sized_box_for_whitespace, unnecessary_to_list_in_spreads, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wortis/class/api_service.dart';
import 'package:wortis/class/class.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:wortis/class/uploaded_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FormStyles {
  static const primaryColor = Color(0xFF006699);
  static const secondaryColor = Color(0xFF0088CC);
  static const backgroundColor = Color(0xFFF5F7FA);
  static const textColor = Color(0xFF2C3E50);
  static const errorColor = Color(0xFFE74C3C);
  static const successColor = Color(0xFF2ECC71);

  static final cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        spreadRadius: 0,
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static final inputDecoration = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE0E7FF), width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE0E7FF), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: errorColor, width: 1),
    ),
    labelStyle: const TextStyle(
      color: Color(0xFF64748B),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14),
    errorStyle: const TextStyle(
      color: errorColor,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );

  static final elevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );

  static final outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: const BorderSide(color: primaryColor, width: 1.5),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
}

class FormService extends StatefulWidget {
  final String serviceName;
  const FormService({super.key, required this.serviceName});

  @override
  _FormServiceState createState() => _FormServiceState();
}

class _FormServiceState extends State<FormService> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? serviceData;
  Map<String, dynamic> formValues = {};
  Map<String, TextEditingController> controllers = {};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  int currentStep = 0;
  Map<String, dynamic>? verificationData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
    fetchServiceFields();
  }

  @override
  void dispose() {
    _apiService.cancelOperation();
    controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // ============================================
  // NORMALISATION DES DONNÉES
  // ============================================

  Map<String, dynamic> _normalizeApiData(Map<String, dynamic> data) {
    try {
      if (data['steps'] != null) {
        for (var step in data['steps']) {
          if (step['fields'] != null) {
            List<Map<String, dynamic>> normalizedFields = [];
            for (var field in step['fields']) {
              normalizedFields.add(_normalizeField(field));
            }
            step['fields'] = normalizedFields;
          }

          if (step['api_fields'] != null) {
            Map<String, dynamic> normalizedApiFields = {};
            step['api_fields'].forEach((key, fieldConfig) {
              normalizedApiFields[key] = {
                'type': fieldConfig['type'] ?? 'text',
                'label': fieldConfig['label'] ?? key,
                'key': fieldConfig['key'],
                'readonly': fieldConfig['readonly'] ?? true,
                'required': fieldConfig['required'] ?? true,
                'format': fieldConfig['format'],
              };
            });
            step['api_fields'] = normalizedApiFields;
          }
        }
      } else if (data['fields'] != null) {
        List<Map<String, dynamic>> normalizedFields = [];
        for (var field in data['fields']) {
          normalizedFields.add(_normalizeField(field));
        }
        data['fields'] = normalizedFields;
      }
      return data;
    } catch (e) {
      print('Erreur lors de la normalisation des données : $e');
      return data;
    }
  }

  Map<String, dynamic> _normalizeField(Map<String, dynamic> field) {
    Map<String, dynamic> normalizedField = {
      'name': field['nom'] ?? field['name'] ?? '',
      'label':
          field['étiquette'] ??
          field['label'] ??
          field['nom'] ??
          field['name'] ??
          '',
      'type': _normalizeFieldType(field['type'] ?? 'text'),
      'required': field['requis'] ?? field['required'] ?? false,
      'readonly': field['readonly'] ?? false,
      'regex': field['regex'],
      'regex_error': field['regex_error'],
      'multiple': field['multiple'],
      'accept': field['accept'],
      'tag': field['tag'], // Préserver le tag pour le pré-remplissage
    };

    if (field['options'] != null) {
      normalizedField['options'] = field['options'].map<Map<String, String>>((
        option,
      ) {
        return {
          'value': option['value'] ?? option['valeur'] ?? '',
          'label': option['label'] ?? option['étiquette'] ?? '',
        };
      }).toList();
    }

    if (field['dependencies'] != null) {
      List<Map<String, dynamic>> normalizedDeps = [];
      for (var dep in field['dependencies']) {
        Map<String, dynamic> normalizedDep = {
          'field': dep['field'] ?? dep['champ'] ?? '',
          'value': dep['value'] ?? dep['valeur'] ?? '',
        };

        if (dep['options'] != null) {
          normalizedDep['options'] = dep['options'].map<Map<String, String>>((
            option,
          ) {
            return {
              'value': option['value'] ?? option['valeur'] ?? '',
              'label': option['label'] ?? option['étiquette'] ?? '',
            };
          }).toList();
        }

        normalizedDeps.add(normalizedDep);
      }
      normalizedField['dependencies'] = normalizedDeps;
    }

    return normalizedField;
  }

  String _normalizeFieldType(String type) {
    final typeMap = {
      'numéro': 'number',
      'sélecteur': 'selecteur',
      'texte': 'text',
    };
    return typeMap[type.toLowerCase()] ?? type.toLowerCase();
  }

  // ============================================
  // RÉCUPÉRATION DES DONNÉES
  // ============================================

  Future<void> fetchServiceFields() async {
    try {
      final responseData = await _apiService.fetchServiceFields(
        widget.serviceName,
      );

      serviceData = _normalizeApiData(responseData['service']);
      await initializeFormValues(); // Appel asynchrone

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Erreur : $e');
      if (mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors de la récupération des données du formulaire',
        );
      }
    }
  }

  // ============================================
  // INITIALISATION ET VALIDATION
  // ============================================

  // Fonction helper pour récupérer les données utilisateur
  Future<Map<String, dynamic>?> _getUserInfoFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoString = prefs.getString('user_infos');
      if (userInfoString != null) {
        return jsonDecode(userInfoString);
      }
    } catch (e) {
      print(
        '⚠️  [FormService] Impossible de récupérer les données utilisateur: $e',
      );
    }
    return null;
  }

  Future<void> initializeFormValues() async {
    if (serviceData == null) return;

    var fields = serviceData!['steps'] != null
        ? serviceData!['steps'][currentStep]['fields']
        : serviceData!['fields'];

    if (fields == null) return;

    // Récupérer les données utilisateur pour le pré-remplissage
    final userInfo = await _getUserInfoFromStorage();
    if (userInfo != null) {
      print(
        '📝 [FormService] Données utilisateur chargées depuis SharedPreferences',
      );
      print('✅ [FormService] Champs disponibles: ${userInfo.keys.toList()}');
    }

    for (var field in fields) {
      String fieldName = field['name'];
      String fieldType = field['type'];
      String? fieldTag = field['tag'];

      // Valeur par défaut depuis les données utilisateur si tag correspond
      dynamic defaultValue;
      if (fieldTag != null &&
          userInfo != null &&
          userInfo.containsKey(fieldTag)) {
        defaultValue = userInfo[fieldTag];
        print(
          '🔄 [FormService] Pré-remplissage du champ "$fieldName" (tag: "$fieldTag") avec: $defaultValue',
        );
      }

      switch (fieldType) {
        case 'list':
          formValues[fieldName] = <Map<String, dynamic>>[];
          break;
        case 'document':
          formValues[fieldName] = field['multiple'] == true ? [] : null;
          break;
        default:
          formValues[fieldName] = defaultValue;
          if ([
            'text',
            'number',
            'date',
            'time',
            'datetime',
          ].contains(fieldType)) {
            controllers[fieldName] = TextEditingController(
              text: defaultValue?.toString() ?? '',
            );
          }
      }
    }
  }

  bool validateAllFields() {
    bool isValid = true;
    List<String> missingFieldsList = [];

    var fields = serviceData!['steps'] != null
        ? serviceData!['steps'][currentStep]['fields']
        : serviceData!['fields'];

    if (fields == null) return true;

    for (var field in fields) {
      if (!shouldShowField(field)) continue;
      if (field['required'] != true) continue;

      String fieldName = field['name'];
      var value = formValues[fieldName];
      bool isEmpty = false;

      switch (field['type']) {
        case 'document':
          if (field['multiple'] == true) {
            isEmpty = value == null || (value as List).isEmpty;
          } else {
            isEmpty = value == null;
          }
          break;
        case 'selecteur':
          isEmpty = value == null || value.toString().isEmpty;
          break;
        case 'number':
          isEmpty = value == null || value.toString().trim().isEmpty;
          break;
        case 'list':
          isEmpty = value == null || (value as List).isEmpty;
          break;
        default:
          isEmpty = value == null || value.toString().trim().isEmpty;
      }

      if (isEmpty) {
        isValid = false;
        missingFieldsList.add(field['label'] ?? fieldName);
      }
    }

    if (!isValid) {
      String missingFields = missingFieldsList.join(', ');
      CustomOverlay.showError(
        context,
        message: 'Veuillez remplir les champs obligatoires : $missingFields',
      );
    }

    return isValid;
  }

  // ============================================
  // SOUMISSION DU FORMULAIRE (SIMPLIFIÉ)
  // ============================================

  Future<void> submitForm() async {
    if (!validateAllFields()) return;
    if (!_formKey.currentState!.validate()) return;

    // Vérifier s'il faut afficher un pop-up de confirmation
    if (serviceData!['steps'] != null) {
      var currentStepData = serviceData!['steps'][currentStep];
      if (currentStepData['show_confirmation_before'] == true &&
          currentStepData['confirmation_popup'] != null) {
        showConfirmationPopup(currentStepData['confirmation_popup']);
        return;
      }
    }

    // Vérifier s'il faut afficher la modal de récapitulatif de paiement
    if (serviceData!['modal_confirm'] != null) {
      showPaymentConfirmationModal();
      return;
    }

    await _continueSubmitProcess();
  }

  Future<void> _continueSubmitProcess() async {
    if (serviceData!['steps'] != null && currentStep == 0) {
      await verifyFirstStep();
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String url = _buildSubmissionUrl();
      Map<String, dynamic> requestBody = _prepareRequestData();
      bool isCardPayment = _isCardPayment();

      print('📤 Soumission:');
      print('  URL: $url');
      print('  Carte: $isCardPayment');

      bool success = await _apiService.submitFormData(
        context,
        url,
        requestBody,
        serviceData,
        null,
        isCardPayment,
      );

      if (mounted && success) {
        setState(() {
          currentStep = 0;
          formValues.clear();
          verificationData = null;
        });
        await initializeFormValues(); // Appel asynchrone en dehors du setState
      }
    } catch (e) {
      print('❌ Erreur soumission: $e');
      if (mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors de la soumission du formulaire',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _buildSubmissionUrl() {
    if (serviceData!['steps'] != null) {
      var finalStep = serviceData!['steps'][1];

      if (finalStep['link_momo_dependencies'] != null) {
        String dependentField = finalStep['link_momo_dependencies']['field'];
        String expectedValue = finalStep['link_momo_dependencies']['value'];
        bool isCard = formValues[dependentField] != expectedValue;

        return isCard
            ? (finalStep['link_cb'] ?? finalStep['link_momo'])
            : finalStep['link_momo'];
      }

      return finalStep['link_momo'];
    }

    if (serviceData!['link_momo_dependencies'] != null) {
      String dependentField = serviceData!['link_momo_dependencies']['field'];
      String expectedValue = serviceData!['link_momo_dependencies']['value'];
      bool isCard = formValues[dependentField] != expectedValue;

      return isCard
          ? (serviceData!['link_cb'] ?? serviceData!['link_momo'])
          : serviceData!['link_momo'];
    }

    return serviceData!['link_momo'];
  }

  Map<String, dynamic> _prepareRequestData() {
    Map<String, dynamic> requestBody = {};

    Map<String, dynamic> bodyMapping = serviceData!['steps'] != null
        ? serviceData!['steps'][1]['body']
        : serviceData!['body'];

    bodyMapping.forEach((apiKey, formKey) {
      var value = formValues[formKey];
      requestBody[apiKey] = value;

      if (value is UploadedFile) {
        print('  $apiKey: [FILE] ${value.name}');
      } else if (value is List &&
          value.isNotEmpty &&
          value.first is UploadedFile) {
        print('  $apiKey: [FILES] ${value.length} fichier(s)');
      } else {
        print('  $apiKey: $value');
      }
    });

    return requestBody;
  }

  bool _isCardPayment() {
    Map<String, dynamic>? dependencies = serviceData!['steps'] != null
        ? serviceData!['steps'][1]['link_momo_dependencies']
        : serviceData!['link_momo_dependencies'];

    if (dependencies == null) return false;

    String dependentField = dependencies['field'];
    String expectedValue = dependencies['value'];

    return formValues[dependentField] != expectedValue;
  }

  // ============================================
  // VÉRIFICATION PREMIÈRE ÉTAPE
  // ============================================

  // Pré-remplir les champs de l'étape 2 avec les données utilisateur
  Future<void> _prefillStep2Fields() async {
    if (currentStep != 1) return;

    final userInfo = await _getUserInfoFromStorage();
    if (userInfo == null) return;

    print('📝 [FormService Step2] Pré-remplissage des champs de l\'étape 2...');

    var step2Fields = serviceData!['steps'][1]['fields'];
    if (step2Fields == null) return;

    for (var field in step2Fields) {
      String fieldName = field['name'];
      String? fieldTag = field['tag'];

      // Ne pré-remplir que si le champ n'a pas déjà une valeur
      if (fieldTag != null &&
          userInfo.containsKey(fieldTag) &&
          (formValues[fieldName] == null ||
              formValues[fieldName].toString().isEmpty)) {
        dynamic defaultValue = userInfo[fieldTag];
        print(
          '🔄 [FormService Step2] Pré-remplissage "$fieldName" (tag: "$fieldTag") avec: $defaultValue',
        );

        setState(() {
          formValues[fieldName] = defaultValue;

          // Mettre à jour le controller si nécessaire
          if (controllers.containsKey(fieldName)) {
            controllers[fieldName]?.value = TextEditingValue(
              text: defaultValue?.toString() ?? '',
              selection: TextSelection.collapsed(
                offset: defaultValue?.toString().length ?? 0,
              ),
            );
          } else if ([
            'text',
            'number',
            'date',
            'time',
            'datetime',
          ].contains(field['type'])) {
            controllers[fieldName] = TextEditingController(
              text: defaultValue?.toString() ?? '',
            );
          }
        });
      }
    }
  }

  Future<void> verifyFirstStep() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    const operationId = 'verify_first_step';
    try {
      Map<String, dynamic> requestBody = {};
      var currentStepData = serviceData!['steps'][currentStep];

      currentStepData['body'].forEach((key, value) {
        if (value is String) {
          requestBody[key] = formValues[value];
        }
      });

      if (currentStepData['body']['additional_params'] != null) {
        requestBody.addAll(currentStepData['body']['additional_params']);
      }

      final requestMethod =
          currentStepData['request']?.toString().toUpperCase() ?? 'GET';

      try {
        final response = requestMethod == 'POST'
            ? await _apiService.verifyDataPost(
                currentStepData['link'],
                requestBody,
                operationId,
              )
            : await _apiService.verifyDataGet(
                currentStepData['link'],
                requestBody,
              );

        CustomOverlay.hide();

        setState(() {
          verificationData = response;
          currentStep = 1;

          var nextStep = serviceData!['steps'][1];

          if (nextStep['api_fields'] != null) {
            Map<String, dynamic> apiFields = nextStep['api_fields'];

            apiFields.forEach((fieldName, fieldConfig) {
              if (fieldConfig['key'] is List) {
                if (fieldConfig['format'] == 'concat') {
                  List<String> values = [];
                  for (String key in fieldConfig['key']) {
                    if (response[key] != null) {
                      values.add(response[key].toString());
                    }
                  }
                  formValues[fieldName] = values.join(' ').trim();
                }
              } else {
                String apiKey = fieldConfig['key'];
                if (response[apiKey] != null) {
                  formValues[fieldName] = response[apiKey];
                }
              }

              if (controllers[fieldName] == null) {
                controllers[fieldName] = TextEditingController(
                  text: formValues[fieldName]?.toString() ?? '',
                );
              } else {
                controllers[fieldName]?.value = TextEditingValue(
                  text: formValues[fieldName]?.toString() ?? '',
                );
              }
            });
          }

          if (nextStep['preserve_fields'] != null) {
            var preserveFields = nextStep['preserve_fields'];
            if (preserveFields['source'] != null &&
                preserveFields['target'] != null) {
              formValues[preserveFields['target']] =
                  formValues[preserveFields['source']];
            }
          }

          isLoading = false;
        });

        // Pré-remplir les champs de l'étape 2 avec les données utilisateur (tag)
        _prefillStep2Fields();
      } catch (e) {
        throw Exception('not_found');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      CustomOverlay.hide();

      if (mounted) {
        CustomOverlay.showError(context, message: 'Informations non trouvées');
      }
    }
  }

  // ============================================
  // GESTION DES CHAMPS
  // ============================================

  void updateFormValue(String fieldName, dynamic value) {
    setState(() {
      formValues[fieldName] = value;

      var fields = serviceData!['steps'] != null
          ? serviceData!['steps'][currentStep]['fields']
          : serviceData!['fields'];

      if (fields == null) return;

      var field = fields.firstWhere(
        (f) => f['name'] == fieldName,
        orElse: () => {'type': ''},
      );

      if (!['text', 'number'].contains(field['type']) &&
          controllers.containsKey(fieldName)) {
        controllers[fieldName]?.value = TextEditingValue(
          text: value?.toString() ?? '',
        );
      }

      if (fields != null) {
        for (var field in fields) {
          if (field['dependencies'] != null) {
            bool shouldReset = field['dependencies'].any(
              (dependency) =>
                  dependency['field'] == fieldName &&
                  dependency['value'] != value,
            );

            if (shouldReset) {
              String dependentFieldName = field['name'];
              formValues[dependentFieldName] = null;
              if (controllers.containsKey(dependentFieldName)) {
                controllers[dependentFieldName]?.clear();
              }
            }
          }
        }
      }
    });
  }

  bool shouldShowField(Map<String, dynamic> field) {
    if (field['dependencies'] == null) return true;
    return field['dependencies'].any((dependency) {
      String dependentField = dependency['field'];
      String expectedValue = dependency['value'];
      return formValues[dependentField] == expectedValue;
    });
  }

  List<DropdownMenuItem<String>> getDropdownOptions(
    Map<String, dynamic> field,
  ) {
    List<DropdownMenuItem<String>> items = [];

    try {
      if (field['dependencies'] != null) {
        for (var dependency in field['dependencies']) {
          String dependentField = dependency['field'];
          String expectedValue = dependency['value'];

          if (formValues[dependentField] == expectedValue) {
            var optionsToUse = dependency['options'] ?? field['options'];
            if (optionsToUse != null) {
              items = optionsToUse.map<DropdownMenuItem<String>>((option) {
                return DropdownMenuItem<String>(
                  value: option['value'],
                  child: Text(option['label']),
                );
              }).toList();
            }
            break;
          }
        }
      } else if (field['options'] != null) {
        items = field['options'].map<DropdownMenuItem<String>>((option) {
          return DropdownMenuItem<String>(
            value: option['value'],
            child: Text(option['label']),
          );
        }).toList();
      }
    } catch (e) {
      print('Erreur lors de la création des options du dropdown : $e');
    }

    return items;
  }

  // ============================================
  // GESTION DES FICHIERS
  // ============================================

  Future<void> _pickDocument(
    String fieldName,
    Map<String, dynamic> field,
  ) async {
    try {
      List<String>? allowedExtensions;
      FileType fileType = FileType.any;

      if (field['accept'] != null) {
        String accept = field['accept'].toString();
        if (accept.contains('image')) {
          fileType = FileType.image;
        } else if (accept.contains('pdf')) {
          fileType = FileType.custom;
          allowedExtensions = ['pdf'];
        } else if (accept.contains('video')) {
          fileType = FileType.video;
        } else {
          allowedExtensions = accept
              .split(',')
              .map((e) => e.trim().replaceAll('.', ''))
              .toList();
          fileType = FileType.custom;
        }
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: field['multiple'] == true,
      );

      if (result != null) {
        if (field['multiple'] == true) {
          List<UploadedFile> files = [];
          for (var file in result.files) {
            if (file.path != null) {
              files.add(
                await _createUploadedFile(file.path!, file.name, file.size),
              );
            }
          }
          setState(() {
            formValues[fieldName] = files;
          });
        } else {
          PlatformFile file = result.files.first;
          if (file.path != null) {
            UploadedFile uploadedFile = await _createUploadedFile(
              file.path!,
              file.name,
              file.size,
            );
            setState(() {
              formValues[fieldName] = uploadedFile;
            });
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la sélection du fichier : $e');
      if (mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors de la sélection du fichier',
        );
      }
    }
  }

  Future<void> _pickImage(String fieldName, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        UploadedFile uploadedFile = await _createUploadedFile(
          image.path,
          path.basename(image.path),
          await File(image.path).length(),
        );

        setState(() {
          formValues[fieldName] = uploadedFile;
        });
      }
    } catch (e) {
      print('Erreur lors de la sélection de l\'image : $e');
      if (mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors de la sélection de l\'image',
        );
      }
    }
  }

  Future<UploadedFile> _createUploadedFile(
    String filePath,
    String fileName,
    int fileSize,
  ) async {
    File file = File(filePath);
    String? mimeType = lookupMimeType(filePath);

    String? base64String;
    if (fileSize < 5 * 1024 * 1024) {
      List<int> fileBytes = await file.readAsBytes();
      base64String = base64Encode(fileBytes);
    }

    return UploadedFile(
      name: fileName,
      path: filePath,
      size: fileSize,
      mimeType: mimeType,
      base64: base64String,
    );
  }

  void _removeFile(String fieldName, {int? index}) {
    setState(() {
      if (index != null) {
        List<UploadedFile> files = List<UploadedFile>.from(
          formValues[fieldName],
        );
        files.removeAt(index);
        formValues[fieldName] = files;
      } else {
        formValues[fieldName] = null;
      }
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    }
    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    }
    if (mimeType.contains('zip') || mimeType.contains('rar')) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file;
  }

  // ============================================
  // VALIDATION REGEX
  // ============================================

  String _generateErrorMessageFromRegex(String regexPattern) {
    Map<String, String> commonPatterns = {
      r'^\d{7}[a-zA-Z]$':
          'Format attendu: 7 chiffres suivis d\'une lettre (ex: 1234567A)',
      r'^\d{8}$': 'Format attendu: 8 chiffres (ex: 12345678)',
      r'^\d{10}$': 'Format attendu: 10 chiffres (ex: 1234567890)',
      r'^[a-zA-Z]+$': 'Format attendu: lettres uniquement',
      r'^\d+$': 'Format attendu: chiffres uniquement',
      r'^[a-zA-Z0-9]+$': 'Format attendu: lettres et chiffres uniquement',
    };

    if (commonPatterns.containsKey(regexPattern)) {
      return commonPatterns[regexPattern]!;
    }

    String message = 'Format attendu: ';
    if (regexPattern.contains(r'\d')) {
      message += regexPattern.contains('[a-zA-Z]')
          ? 'chiffres et lettres'
          : 'chiffres uniquement';
    } else if (regexPattern.contains('[a-zA-Z]')) {
      message += 'lettres uniquement';
    } else {
      message += 'format spécifique requis';
    }

    return message;
  }

  String? _validateWithRegex(
    String? value,
    String regexPattern, {
    String? customErrorMessage,
  }) {
    if (value == null || value.isEmpty) return null;

    try {
      RegExp regex = RegExp(regexPattern);
      if (!regex.hasMatch(value)) {
        return customErrorMessage ??
            _generateErrorMessageFromRegex(regexPattern);
      }
      return null;
    } catch (e) {
      return 'Erreur de validation du format';
    }
  }

  // ============================================
  // CONSTRUCTION DES CHAMPS DU FORMULAIRE
  // ============================================

  Widget buildFormField(Map<String, dynamic> field) {
    if (!shouldShowField(field)) return const SizedBox();

    String fieldName = field['name'];
    String fieldType = field['type'];
    bool isReadOnly = field['readonly'] ?? false;
    String? regexPattern = field['regex'];
    String? customRegexError = field['regex_error'];

    switch (fieldType) {
      case 'text':
      case 'number':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextFormField(
            controller: controllers[fieldName],
            keyboardType: fieldType == 'number'
                ? TextInputType.number
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: field['label'] ?? fieldName,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                fieldType == 'number' ? Icons.numbers : Icons.text_fields,
                color: FormStyles.primaryColor.withOpacity(0.7),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E7FF)),
              ),
            ),
            readOnly: isReadOnly,
            onChanged: (value) => updateFormValue(fieldName, value),
            validator: (value) {
              if (field['required'] == true && (value?.isEmpty ?? true)) {
                return 'Ce champ est requis';
              }
              if (fieldType == 'number' && value != null && value.isNotEmpty) {
                if (double.tryParse(value) == null) {
                  return 'Veuillez entrer un nombre valide';
                }
              }
              if (regexPattern != null && regexPattern.isNotEmpty) {
                String? regexError = _validateWithRegex(
                  value,
                  regexPattern,
                  customErrorMessage: customRegexError,
                );
                if (regexError != null) {
                  return regexError;
                }
              }
              return null;
            },
          ),
        );

      case 'selecteur':
        List<DropdownMenuItem<String>> items = getDropdownOptions(field);
        String? currentValue = formValues[fieldName];

        if (currentValue != null &&
            !items.any((item) => item.value == currentValue)) {
          currentValue = null;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: DropdownButtonFormField<String>(
            value: currentValue,
            items: items,
            decoration: InputDecoration(
              labelText: field['label'] ?? fieldName,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                Icons.arrow_drop_down_circle,
                color: FormStyles.primaryColor.withOpacity(0.7),
              ),
            ),
            onChanged: isReadOnly
                ? null
                : (value) => updateFormValue(fieldName, value),
            validator: (value) {
              if (field['required'] == true && value == null) {
                return 'Ce champ est requis';
              }
              return null;
            },
          ),
        );

      case 'date':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextFormField(
            controller: controllers[fieldName],
            decoration: InputDecoration(
              labelText: field['label'] ?? fieldName,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                Icons.calendar_today,
                color: FormStyles.primaryColor.withOpacity(0.7),
              ),
            ),
            readOnly: true,
            onTap: isReadOnly
                ? null
                : () async {
                    final now = DateTime.now();
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now,
                      lastDate: DateTime(2101),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: FormStyles.primaryColor,
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (picked != null && mounted) {
                      setState(() {
                        String formattedDate = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                        controllers[fieldName]?.value = TextEditingValue(
                          text: formattedDate,
                        );
                        updateFormValue(fieldName, formattedDate);
                      });
                    }
                  },
            validator: (value) {
              if (field['required'] == true && (value?.isEmpty ?? true)) {
                return 'Ce champ est requis';
              }
              return null;
            },
          ),
        );

      case 'time':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextFormField(
            controller: controllers[fieldName],
            decoration: InputDecoration(
              labelText: field['label'] ?? fieldName,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                Icons.access_time,
                color: FormStyles.primaryColor.withOpacity(0.7),
              ),
            ),
            readOnly: true,
            onTap: isReadOnly
                ? null
                : () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        controllers[fieldName]?.value = TextEditingValue(
                          text: picked.format(context),
                        );
                        updateFormValue(fieldName, picked.format(context));
                      });
                    }
                  },
            validator: (value) {
              if (field['required'] == true && (value?.isEmpty ?? true)) {
                return 'Ce champ est requis';
              }
              return null;
            },
          ),
        );

      case 'datetime':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextFormField(
            controller: controllers[fieldName],
            decoration: InputDecoration(
              labelText: field['label'] ?? fieldName,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                Icons.event,
                color: FormStyles.primaryColor.withOpacity(0.7),
              ),
            ),
            readOnly: true,
            onTap: isReadOnly
                ? null
                : () async {
                    final DateTime? date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );

                    if (date != null) {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );

                      if (time != null && mounted) {
                        final DateTime dateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                        setState(() {
                          String formattedDateTime = DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(dateTime);
                          controllers[fieldName]?.value = TextEditingValue(
                            text: formattedDateTime,
                          );
                          updateFormValue(fieldName, formattedDateTime);
                        });
                      }
                    }
                  },
            validator: (value) {
              if (field['required'] == true && (value?.isEmpty ?? true)) {
                return 'Ce champ est requis';
              }
              return null;
            },
          ),
        );

      case 'document':
        bool isMultiple = field['multiple'] == true;
        bool isImageOnly =
            field['accept']?.toString().contains('image') ?? false;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 20,
                      color: FormStyles.primaryColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      field['label'] ?? fieldName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: FormStyles.textColor,
                      ),
                    ),
                    if (field['required'] == true)
                      const Text(
                        ' *',
                        style: TextStyle(
                          color: FormStyles.errorColor,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isReadOnly
                          ? null
                          : () => _pickDocument(fieldName, field),
                      icon: Icon(
                        isImageOnly ? Icons.photo_library : Icons.upload_file,
                        size: 20,
                      ),
                      label: Text(
                        isImageOnly
                            ? 'Choisir une image'
                            : 'Choisir un fichier',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FormStyles.primaryColor,
                        side: const BorderSide(color: FormStyles.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (isImageOnly) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: isReadOnly
                          ? null
                          : () => _pickImage(fieldName, ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text(
                        'Photo',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FormStyles.primaryColor,
                        side: const BorderSide(color: FormStyles.primaryColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (formValues[fieldName] != null) ...[
                const SizedBox(height: 12),
                if (isMultiple)
                  ...((formValues[fieldName] as List<UploadedFile>)
                      .asMap()
                      .entries
                      .map((entry) {
                        int index = entry.key;
                        UploadedFile file = entry.value;
                        return _buildFilePreview(
                          file,
                          fieldName,
                          index: index,
                          isReadOnly: isReadOnly,
                        );
                      })
                      .toList())
                else
                  _buildFilePreview(
                    formValues[fieldName] as UploadedFile,
                    fieldName,
                    isReadOnly: isReadOnly,
                  ),
              ],
            ],
          ),
        );

      case 'list':
        return buildDynamicListField(field);

      default:
        return const SizedBox();
    }
  }

  Widget _buildFilePreview(
    UploadedFile file,
    String fieldName, {
    int? index,
    bool isReadOnly = false,
  }) {
    bool isImage = file.mimeType?.startsWith('image/') ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E7FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: FormStyles.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    child: Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.broken_image,
                          color: FormStyles.primaryColor.withOpacity(0.5),
                        );
                      },
                    ),
                  )
                : Icon(
                    _getFileIcon(file.mimeType),
                    color: FormStyles.primaryColor,
                    size: 30,
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: FormStyles.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFileSize(file.size),
                    style: TextStyle(
                      fontSize: 12,
                      color: FormStyles.textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isReadOnly)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: FormStyles.errorColor,
              onPressed: () => _removeFile(fieldName, index: index),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
        ],
      ),
    );
  }

  Widget buildDynamicListField(Map<String, dynamic> field) {
    String fieldName = field['name'];

    if (formValues[fieldName] == null) {
      formValues[fieldName] = <Map<String, dynamic>>[];
    }

    List<Map<String, dynamic>> fieldValues = List<Map<String, dynamic>>.from(
      formValues[fieldName],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: FormStyles.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: FormStyles.primaryColor),
                const SizedBox(width: 8),
                Text(
                  field['label'] ?? fieldName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FormStyles.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fieldValues.length,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Élément ${index + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: FormStyles.textColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: FormStyles.errorColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  fieldValues.removeAt(index);
                                  formValues[fieldName] = fieldValues;
                                });
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        ...(field['options'] as List).map<Widget>((option) {
                          String optionName = option['value'].toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              initialValue:
                                  fieldValues[index][optionName]?.toString() ??
                                  '',
                              decoration: InputDecoration(
                                labelText: option['label'],
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(
                                  Icons.edit,
                                  color: FormStyles.primaryColor,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  fieldValues[index][optionName] = value;
                                  formValues[fieldName] = fieldValues;
                                });
                              },
                              validator: (value) =>
                                  value!.isEmpty ? 'Ce champ est requis' : null,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  Map<String, dynamic> newItem = {};
                  for (var option in (field['options'] as List)) {
                    newItem[option['value'].toString()] = '';
                  }
                  fieldValues.add(newItem);
                  formValues[fieldName] = fieldValues;
                });
              },
              style: FormStyles.elevatedButtonStyle,
              icon: const Icon(Icons.add),
              label: Text(serviceData!['bouton_list'] ?? 'Ajouter un élément'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // CONSTRUCTION DE L'INTERFACE
  // ============================================

  Widget buildProgressIndicator() {
    if (serviceData!['steps'] == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / serviceData!['steps'].length,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                FormStyles.primaryColor,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget buildBanner() {
    if (serviceData == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: FormStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (serviceData!['banner'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                serviceData!['banner'],
                width: double.infinity,
                fit: BoxFit.fitWidth,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.white,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: FormStyles.errorColor,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
          if (serviceData!['description'] != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: FormStyles.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          serviceData!['tite_description'] ?? 'Description',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: FormStyles.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    serviceData!['description'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: FormStyles.textColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (serviceData!['comment_payer'] != null)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.help_outline,
                            color: FormStyles.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _showPaymentInstructionsModal,
                            child: const Text(
                              'Comment ça marche ?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: FormStyles.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showPaymentInstructionsModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        final size = MediaQuery.of(context).size;
        final isSmallScreen = size.width < 360;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(maxHeight: size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Comment ça marche',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      serviceData!['comment_payer'] ??
                          'Instructions non disponibles',
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FormStyles.elevatedButtonStyle,
                      child: const Text('Compris'),
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

  List<Widget> buildCurrentStepFields() {
    if (serviceData!['steps'] != null) {
      var currentStepData = serviceData!['steps'][currentStep];
      List<Widget> fields = [];

      if (currentStep == 1) {
        if (currentStepData['api_fields'] != null) {
          fields.add(
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: FormStyles.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Informations détaillées',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: FormStyles.textColor,
                    ),
                  ),
                ],
              ),
            ),
          );

          currentStepData['api_fields'].forEach((fieldName, fieldConfig) {
            Map<String, dynamic> field = {
              'name': fieldName,
              'type': fieldConfig['type'] ?? 'text',
              'label': fieldConfig['label'] ?? fieldName,
              'readonly': fieldConfig['readonly'] ?? true,
              'required': fieldConfig['required'] ?? true,
            };

            if (!controllers.containsKey(fieldName)) {
              controllers[fieldName] = TextEditingController(
                text: formValues[fieldName]?.toString() ?? '',
              );
            }

            if (shouldShowField(field)) {
              fields.add(buildFormField(field));
            }
          });

          fields.add(const Divider(height: 32));
        }

        if (currentStepData['fields'] != null &&
            currentStepData['fields'].isNotEmpty) {
          fields.add(
            Container(
              margin: const EdgeInsets.only(bottom: 16, top: 8),
              child: const Row(
                children: [
                  Icon(Icons.payment, color: FormStyles.primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Informations de paiement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: FormStyles.textColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      if (currentStepData['fields'] != null) {
        fields.addAll(
          currentStepData['fields']
              .where((field) => shouldShowField(field))
              .map<Widget>((field) => buildFormField(field))
              .toList(),
        );
      }

      return [
        Container(
          decoration: FormStyles.cardDecoration,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: fields,
            ),
          ),
        ),
      ];
    } else {
      // Vérifier si fields existe et n'est pas null
      if (serviceData!['fields'] != null) {
        return serviceData!['fields']
            .where((field) => shouldShowField(field))
            .map<Widget>((field) => buildFormField(field))
            .toList();
      } else {
        // Retourner une liste vide si fields n'existe pas
        return [];
      }
    }
  }

  Widget buildNavigationButtons() {
    if (serviceData!['steps'] == null) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        height: 48,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLoading ? null : submitForm,
          style: FormStyles.elevatedButtonStyle,
          child: isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(serviceData!['button_service'] ?? 'Soumettre'),
        ),
      );
    }

    var currentStepData = serviceData!['steps'][currentStep];
    String buttonTitle =
        currentStepData['title_button'] ??
        (currentStep == 0 ? 'Vérifier' : 'Payer');

    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          if (currentStep == 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  height: 58,
                  child: OutlinedButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            _apiService.cancelOperation();
                            setState(() {
                              currentStep = 0;
                              verificationData = null;
                              var step2Fields = serviceData!['steps'][1];
                              if (step2Fields['api_fields'] != null) {
                                step2Fields['api_fields'].forEach((
                                  fieldName,
                                  _,
                                ) {
                                  formValues.remove(fieldName);
                                  controllers[fieldName]?.clear();
                                });
                              }
                            });
                          },
                    style: FormStyles.outlinedButtonStyle,
                    child: const Text('Retour'),
                  ),
                ),
              ),
            ),
          Expanded(
            child: SizedBox(
              height: 58,
              child: ElevatedButton(
                onPressed: isLoading ? null : submitForm,
                style: FormStyles.elevatedButtonStyle,
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        buttonTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // POP-UP DE CONFIRMATION
  // ============================================

  void showConfirmationPopup(Map<String, dynamic> popupConfig) {
    String popupType = popupConfig['popup_type'] ?? 'info';
    String title = popupConfig['popup_title'] ?? 'Confirmation';
    String text = popupConfig['popup_text'] ?? 'Voulez-vous continuer ?';
    String? confirmText = popupConfig['confirm_text'];
    String? cancelText = popupConfig['cancel_text'];

    bool hasConfirm = confirmText != null;
    bool hasCancel = cancelText != null;

    if (!hasConfirm && !hasCancel) {
      confirmText = 'Confirmer';
      cancelText = 'Annuler';
      hasConfirm = true;
      hasCancel = true;
    }

    Color getPopupColor() {
      switch (popupType) {
        case 'warning':
          return Colors.orange.shade600;
        case 'error':
          return Colors.red.shade600;
        case 'success':
          return Colors.green.shade600;
        case 'info':
        default:
          return const Color(0xFF006699);
      }
    }

    IconData getPopupIcon() {
      switch (popupType) {
        case 'warning':
          return Icons.warning_amber_rounded;
        case 'error':
          return Icons.error_outline_rounded;
        case 'success':
          return Icons.check_circle_outline_rounded;
        case 'info':
        default:
          return Icons.info_outline_rounded;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _SimpleConfirmationDialog(
          popupColor: getPopupColor(),
          popupIcon: getPopupIcon(),
          title: title,
          text: text,
          confirmText: confirmText,
          cancelText: cancelText,
          hasConfirm: hasConfirm,
          hasCancel: hasCancel,
          onConfirm: () async {
            Navigator.of(context).pop();
            await _continueSubmitProcess();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void showPaymentConfirmationModal() {
    Map<String, dynamic> modalConfirm = serviceData!['modal_confirm'];

    // Extract frais_operateur and frais_service
    double fraisOperateur = (modalConfirm['frais_operateur'] ?? 0).toDouble();

    // Handle frais_service which might be {"$numberLong": "2000"} or a direct number
    double fraisService = 0;
    if (modalConfirm['frais_service'] != null) {
      if (modalConfirm['frais_service'] is Map) {
        fraisService = double.parse(
          modalConfirm['frais_service']['\$numberLong']?.toString() ?? '0',
        );
      } else {
        fraisService = (modalConfirm['frais_service'] ?? 0).toDouble();
      }
    }

    // Build list of fields to display (excluding frais_operateur and frais_service)
    List<Map<String, String>> displayFields = [];
    String? amountFieldName;

    modalConfirm.forEach((key, value) {
      if (key != 'frais_operateur' && key != 'frais_service') {
        String fieldName = value.toString();
        // Check if this is the amount field (contains "Montant" or similar)
        if (key.toLowerCase().contains('montant') ||
            key.toLowerCase().contains('amount')) {
          amountFieldName = fieldName;
        }
        displayFields.add({'label': key, 'fieldName': fieldName});
      }
    });

    // Calculate the total amount
    double totalAmount = 0;
    if (amountFieldName != null && formValues[amountFieldName] != null) {
      double baseAmount =
          double.tryParse(formValues[amountFieldName].toString()) ?? 0;
      totalAmount = (baseAmount * fraisOperateur) + fraisService + baseAmount;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _PaymentConfirmationDialog(
          displayFields: displayFields,
          formValues: formValues,
          amountFieldName: amountFieldName,
          totalAmount: totalAmount,
          fraisService: fraisService,
          fraisOperateur: fraisOperateur,
          onConfirm: () async {
            Navigator.of(context).pop();
            await _continueSubmitProcess();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  // ============================================
  // BUILD PRINCIPAL
  // ============================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Theme(
      data: Theme.of(
        context,
      ).copyWith(inputDecorationTheme: FormStyles.inputDecoration),
      child: Scaffold(
        backgroundColor: FormStyles.backgroundColor,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Text(
            widget.serviceName.replaceAll('\n', ''),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          backgroundColor: FormStyles.primaryColor,
        ),
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            final horizontalPadding = maxWidth * 0.05;
            final verticalPadding = maxHeight * 0.02;
            final fieldSpacing = maxHeight * 0.015;

            return isLoading
                ? const Center(child: CircularProgressIndicator())
                : serviceData == null
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FormStyles.primaryColor,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                      },
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: horizontalPadding,
                          right: horizontalPadding,
                          top: verticalPadding,
                          bottom: maxHeight * 0.1,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildBanner(),
                              Container(
                                width: maxWidth * 0.9,
                                child: buildProgressIndicator(),
                              ),
                              SizedBox(height: fieldSpacing),
                              ...buildCurrentStepFields()
                                  .map(
                                    (field) => Container(
                                      width: maxWidth * 0.9,
                                      margin: EdgeInsets.only(
                                        bottom: fieldSpacing,
                                      ),
                                      child: field,
                                    ),
                                  )
                                  .toList(),
                              Container(
                                width: maxWidth * 0.9,
                                margin: EdgeInsets.only(
                                  top: fieldSpacing * 2,
                                  bottom: fieldSpacing,
                                ),
                                child: buildNavigationButtons(),
                              ),
                              SizedBox(height: maxHeight * 0.05),
                            ],
                          ),
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

// ============================================
// WIDGETS DE DIALOGUE DE CONFIRMATION
// ============================================

class _SimpleConfirmationDialog extends StatefulWidget {
  final Color popupColor;
  final IconData popupIcon;
  final String title;
  final String text;
  final String? confirmText;
  final String? cancelText;
  final bool hasConfirm;
  final bool hasCancel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _SimpleConfirmationDialog({
    required this.popupColor,
    required this.popupIcon,
    required this.title,
    required this.text,
    required this.confirmText,
    required this.cancelText,
    required this.hasConfirm,
    required this.hasCancel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  _SimpleConfirmationDialogState createState() =>
      _SimpleConfirmationDialogState();
}

class _SimpleConfirmationDialogState extends State<_SimpleConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: widget.popupColor.withOpacity(0.08),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 1500),
                            tween: Tween<double>(begin: 0.9, end: 1.1),
                            curve: Curves.easeInOut,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: widget.popupColor.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    widget.popupIcon,
                                    color: widget.popupColor,
                                    size: 30,
                                  ),
                                ),
                              );
                            },
                            onEnd: () {
                              if (mounted) {
                                setState(() {});
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: widget.popupColor,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.text,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 24,
                      ),
                      child: Row(
                        children: [
                          if (widget.hasCancel)
                            Expanded(
                              child: Container(
                                height: 48,
                                margin: EdgeInsets.only(
                                  right: widget.hasConfirm ? 8 : 0,
                                ),
                                child: _AnimatedButton(
                                  text: widget.cancelText!,
                                  onPressed: widget.onCancel,
                                  backgroundColor: Colors.transparent,
                                  textColor: Colors.grey[600]!,
                                  borderColor: Colors.grey[300]!,
                                  isOutlined: true,
                                ),
                              ),
                            ),
                          if (widget.hasConfirm)
                            Expanded(
                              child: Container(
                                height: 48,
                                margin: EdgeInsets.only(
                                  left: widget.hasCancel ? 8 : 0,
                                ),
                                child: _AnimatedButton(
                                  text: widget.confirmText!,
                                  onPressed: widget.onConfirm,
                                  backgroundColor: widget.popupColor,
                                  textColor: Colors.white,
                                  borderColor: widget.popupColor,
                                  isOutlined: false,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaymentConfirmationDialog extends StatefulWidget {
  final List<Map<String, String>> displayFields;
  final Map<String, dynamic> formValues;
  final String? amountFieldName;
  final double totalAmount;
  final double fraisService;
  final double fraisOperateur;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _PaymentConfirmationDialog({
    required this.displayFields,
    required this.formValues,
    required this.amountFieldName,
    required this.totalAmount,
    required this.fraisService,
    required this.fraisOperateur,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  _PaymentConfirmationDialogState createState() =>
      _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<_PaymentConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0', 'fr_FR');

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: FormStyles.primaryColor.withOpacity(0.08),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: FormStyles.primaryColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: FormStyles.primaryColor,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Récapitulatif du paiement',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: FormStyles.primaryColor,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Display fields
                          ...widget.displayFields.map((field) {
                            String label = field['label']!;
                            String fieldName = field['fieldName']!;
                            String value =
                                widget.formValues[fieldName]?.toString() ?? '';

                            // Special handling for amount field
                            if (fieldName == widget.amountFieldName) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: FormStyles.primaryColor.withOpacity(
                                    0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: FormStyles.primaryColor.withOpacity(
                                      0.2,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$value FCFA',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF2C3E50),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Divider(height: 16),
                                    // Frais opérateur
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Frais opérateur',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '${numberFormat.format(double.tryParse(value) != null ? double.parse(value) * widget.fraisOperateur : 0)} FCFA',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF2C3E50),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Frais de service
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Frais de service',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '${numberFormat.format(widget.fraisService)} FCFA',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF2C3E50),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1, thickness: 2),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total à payer',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF2C3E50),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${numberFormat.format(widget.totalAmount)} FCFA',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: FormStyles.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Regular field display
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      value,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF2C3E50),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    // Buttons
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 24,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              margin: const EdgeInsets.only(right: 8),
                              child: _AnimatedButton(
                                text: 'Annuler',
                                onPressed: widget.onCancel,
                                backgroundColor: Colors.transparent,
                                textColor: Colors.grey[600]!,
                                borderColor: Colors.grey[300]!,
                                isOutlined: true,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 48,
                              margin: const EdgeInsets.only(left: 8),
                              child: _AnimatedButton(
                                text: 'Confirmer',
                                onPressed: widget.onConfirm,
                                backgroundColor: FormStyles.primaryColor,
                                textColor: Colors.white,
                                borderColor: FormStyles.primaryColor,
                                isOutlined: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final bool isOutlined;

  const _AnimatedButton({
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.isOutlined,
  });

  @override
  _AnimatedButtonState createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: widget.isOutlined
                    ? Border.all(color: widget.borderColor, width: 1.5)
                    : null,
                boxShadow: widget.isOutlined
                    ? null
                    : [
                        BoxShadow(
                          color: widget.backgroundColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.textColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
