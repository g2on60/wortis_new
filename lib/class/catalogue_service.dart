import 'package:flutter/material.dart';
import 'package:wortis/class/api_service.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/main.dart';
import 'package:dio/dio.dart';
import 'package:wortis/pages/homepage.dart';

// Styles pour le catalogue
class CatalogStyles {
  static const primaryColor = Color(0xFF006699);
  static const backgroundColor = Color(0xFFF5F7FA);
  static const textColor = Color(0xFF2C3E50);
  static const errorColor = Color(0xFFE74C3C);
  static const successColor = Color(0xFF2ECC71);

  static final tableHeaderStyle = TextStyle(
    color: textColor,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static final tableCellStyle = TextStyle(
    color: textColor,
    fontSize: 14,
  );

  static final priceStyle = TextStyle(
    color: primaryColor,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

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
}

class CatalogView extends StatefulWidget {
  final String serviceName;
  const CatalogView({super.key, required this.serviceName});

  @override
  _CatalogViewState createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? serviceData;
  String? selectedItemId;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {};
  Map<String, dynamic> formValues = {};
  bool isLoading = true;
  final Dio dio = Dio();

  @override
  void initState() {
    super.initState();
    ConnectivityManager(context).initConnectivity;
    fetchServiceData();
  }

  @override
  void dispose() {
    _apiService.cancelOperation();
    controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> fetchServiceData() async {
    try {
      final dio = Dio();
      final response = await dio
          .get('https://api.live.wortis.cg/services/${widget.serviceName}');

      if (mounted && response.statusCode == 200) {
        print("Status code: ${response.statusCode}");

        // Vérification et conversion explicite des données
        if (response.data is Map && response.data.containsKey('service')) {
          final Map<String, dynamic> rawData =
              Map<String, dynamic>.from(response.data['service']);

          // Vérification de la structure des fields
          if (rawData.containsKey('fields') && rawData['fields'] is List) {
            setState(() {
              serviceData = rawData;
              _initializeControllers();
              isLoading = false;
            });
          } else {
            throw Exception(
                'Structure de données invalide: fields manquants ou invalides');
          }
        } else {
          throw Exception('Structure de réponse invalide');
        }
      }
    } catch (e) {
      print('Erreur lors de la récupération : $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: CatalogStyles.errorColor,
          ),
        );
      }
    }
  }

  Widget buildCatalogTable() {
    if (serviceData == null) return const SizedBox.shrink();

    try {
      // Récupération et vérification du champ table_view
      final List<dynamic> fields = List<dynamic>.from(serviceData!['fields']);
      final tableViewField = fields.firstWhere(
        (field) => field is Map && field['type'] == 'table_view',
        orElse: () => null,
      );

      if (tableViewField == null) return const SizedBox.shrink();

      // Récupération des items avec vérification
      final List<dynamic> items =
          List<dynamic>.from(tableViewField['items'] ?? []);

      // Récupération des settings
      final Map<String, dynamic> settings =
          Map<String, dynamic>.from(serviceData!['table_settings'] ?? {});
      final double rowHeight = (settings['row_height'] ?? 80).toDouble();
      final double imageWidth = (settings['image_width'] ?? 60).toDouble();

      return Container(
        decoration: CatalogStyles.cardDecoration,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CatalogStyles.primaryColor.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  SizedBox(width: imageWidth + 16),
                  const Expanded(
                    flex: 2,
                    child: Text('Nom',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Expanded(
                    child: Text(
                      'Prix',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            // Items
            ...items.map((item) {
              final Map<String, dynamic> itemData =
                  Map<String, dynamic>.from(item);
              return InkWell(
                onTap: () {
                  setState(() {
                    selectedItemId = selectedItemId == itemData['id']
                        ? null
                        : itemData['id'];
                    formValues['Article'] =
                        selectedItemId == itemData['id'] ? itemData : null;
                  });
                },
                child: Container(
                  height: rowHeight,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectedItemId == itemData['id']
                        ? CatalogStyles.primaryColor.withOpacity(0.1)
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          itemData['image'].toString(),
                          width: imageWidth,
                          height: rowHeight - 16,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: imageWidth,
                              height: rowHeight - 16,
                              color: Colors.grey[200],
                              child: const Icon(Icons.error),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Text(itemData['name'].toString()),
                      ),
                      Expanded(
                        child: Text(
                          '${itemData['price']} FCFA',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    } catch (e) {
      print('Erreur dans buildCatalogTable: $e');
      return const SizedBox.shrink();
    }
  }

  void _initializeControllers() {
    if (serviceData == null) return;

    for (var field in serviceData!['fields']) {
      if (field['type'] == 'text' || field['type'] == 'number') {
        controllers[field['name']] = TextEditingController();
      }
    }
  }

  Widget buildBanner() {
    if (serviceData == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: CatalogStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (serviceData!['banner'] != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                serviceData!['banner'],
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Icon(Icons.error),
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
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CatalogStyles.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    serviceData!['description'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: CatalogStyles.textColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget buildFormField(Map<String, dynamic> field) {
    if (field['type'] == 'table_view') return const SizedBox.shrink();

    if (field['dependencies'] != null) {
      bool shouldShow = field['dependencies'].any((dep) {
        String dependentField = dep['field'];
        String expectedValue = dep['value'];
        return formValues[dependentField] == expectedValue;
      });
      if (!shouldShow) return const SizedBox.shrink();
    }

    switch (field['type']) {
      case 'number':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextFormField(
            controller: controllers[field['name']],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: field['name'],
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ce champ est requis';
              int? number = int.tryParse(value);
              if (number == null) return 'Veuillez entrer un nombre valide';
              if (number < (field['min'] ?? 1)) {
                return 'Valeur minimale: ${field['min'] ?? 1}';
              }
              if (number > (field['max'] ?? 10)) {
                return 'Valeur maximale: ${field['max'] ?? 10}';
              }
              return null;
            },
            onChanged: (value) {
              formValues[field['name']] = value;
            },
          ),
        );
      case 'selecteur':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DropdownButtonFormField<String>(
            initialValue: formValues[field['name']],
            decoration: InputDecoration(
              labelText: field['name'],
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: field['options'].map<DropdownMenuItem<String>>((option) {
              return DropdownMenuItem<String>(
                value: option['value'],
                child: Text(option['label']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                formValues[field['name']] = value;
              });
            },
            validator: (value) {
              if (value == null) return 'Ce champ est requis';
              return null;
            },
          ),
        );

      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextFormField(
            controller: controllers[field['name']],
            decoration: InputDecoration(
              labelText: field['name'],
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ce champ est requis';
              return null;
            },
            onChanged: (value) {
              formValues[field['name']] = value;
            },
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un article'),
          backgroundColor: CatalogStyles.errorColor,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Création d'une Map<String, dynamic> explicite
      final Map<String, dynamic> requestBody = {};
      serviceData!['body'].forEach((key, value) {
        // Conversion explicite de la clé en String
        String stringKey = key.toString();
        requestBody[stringKey] = formValues[value];
      });

      String url = serviceData!['link_momo'];
      bool isCardPayment = false;

      if (serviceData!['link_momo_dependencies'] != null) {
        String dependentField =
            serviceData!['link_momo_dependencies']['field'].toString();
        String expectedValue =
            serviceData!['link_momo_dependencies']['value'].toString();
        isCardPayment = formValues[dependentField] != expectedValue;
        url = isCardPayment
            ? serviceData!['link_cb'] ?? serviceData!['link_momo']
            : serviceData!['link_momo'];
      }

      await _apiService.submitFormData(
          context, url, requestBody, serviceData, null, isCardPayment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande effectuée avec succès'),
            backgroundColor: CatalogStyles.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la commande: $e'),
            backgroundColor: CatalogStyles.errorColor,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CatalogStyles.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.serviceName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) => HomePage(routeObserver: routeObserver)),
              (route) => false,
            );
          },
        ),
        backgroundColor: CatalogStyles.primaryColor,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(CatalogStyles.primaryColor),
              ),
            )
          : serviceData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: CatalogStyles.errorColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Erreur de chargement des données',
                        style: TextStyle(
                          fontSize: 18,
                          color: CatalogStyles.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: fetchServiceData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CatalogStyles.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildBanner(),
                        buildCatalogTable(),
                        ...serviceData!['fields']
                            .where((field) => field['type'] != 'table_view')
                            .map((field) => buildFormField(field)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isLoading ? null : submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CatalogStyles.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Commander',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
