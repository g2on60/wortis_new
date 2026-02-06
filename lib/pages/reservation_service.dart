// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wortis/class/api_service.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/class/form_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ReservationService extends StatefulWidget {
  final String serviceName;

  const ReservationService({super.key, required this.serviceName});

  @override
  // ignore: library_private_types_in_public_api
  _ReservationServiceState createState() => _ReservationServiceState();
}

class _ReservationServiceState extends State<ReservationService> {
  final ApiService _apiService = ApiService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? serviceData;
  Map<String, dynamic> formValues = {};
  Map<String, TextEditingController> controllers = {};

  bool isLoading = true;
  bool isLoadingSlots = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];

  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Gestion des étapes
  int _currentStep = 1;
  final int _totalSteps = 3;

  // Gestion des catégories
  String? _selectedCategory;

  // Gestion des variantes
  String? _selectedVariantId;
  Map<String, dynamic>? _currentPrestationData;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
    fetchServiceData();
  }

  @override
  void dispose() {
    _apiService.cancelOperation();
    _scrollController.dispose();
    controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> fetchServiceData() async {
    try {
      final responseData = await _apiService.fetchServiceFields(
        widget.serviceName,
      );

      setState(() {
        serviceData = responseData['service'];
        isLoading = false;
      });

      // Ne pas charger les créneaux au démarrage, seulement à l'étape 2
    } catch (e) {
      print('Erreur : $e');
      if (mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors du chargement des données de réservation',
        );
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<String>> _getOccupiedSlots(DateTime date) async {
    List<String> occupiedSlots = [];

    // 1. Récupérer les créneaux bloqués statiques depuis le JSON
    final availability = serviceData?['availability'];
    if (availability != null) {
      final blockedSlots = availability['blocked_slots'] as Map<String, dynamic>?;
      if (blockedSlots != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final blockedForDate = blockedSlots[dateKey] as List<dynamic>?;
        if (blockedForDate != null) {
          occupiedSlots.addAll(blockedForDate.map((slot) => slot.toString()));
        }
      }

      // 2. Récupérer les créneaux occupés depuis l'API
      final apiOccupiedSlotsUrl = availability['api_occupied_slots'] as String?;
      if (apiOccupiedSlotsUrl != null) {
        try {
          // Remplacer les paramètres dans l'URL
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final serviceName = widget.serviceName;
          String apiUrl = apiOccupiedSlotsUrl
              .replaceAll('{date}', dateStr)
              .replaceAll('{service}', Uri.encodeComponent(serviceName));

          print('🔍 Récupération créneaux occupés: $apiUrl');

          final response = await http.get(Uri.parse(apiUrl));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['occupied_slots'] != null) {
              final apiOccupied = data['occupied_slots'] as List<dynamic>;
              occupiedSlots.addAll(apiOccupied.map((slot) => slot.toString()));
              print('✅ Créneaux occupés récupérés: ${apiOccupied.length}');
            }
          } else {
            print('⚠️ Erreur API créneaux occupés: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ Erreur récupération créneaux occupés API: $e');
          // Continue sans les créneaux de l'API en cas d'erreur
        }
      }
    }

    return occupiedSlots;
  }

  Future<void> _loadAvailableTimeSlots(DateTime date) async {
    setState(() {
      isLoadingSlots = true;
    });

    try {
      // Récupérer tous les créneaux par défaut
      List<String> allSlots = _getDefaultTimeSlots(date);

      // Récupérer les créneaux occupés
      List<String> occupiedSlots = await _getOccupiedSlots(date);

      // Filtrer les créneaux occupés
      List<String> availableSlots = allSlots.where((slot) {
        // Normaliser le format (enlever les espaces autour du tiret)
        String normalizedSlot = slot.replaceAll(' - ', '-').replaceAll(' ', '');

        return !occupiedSlots.any((occupied) {
          String normalizedOccupied = occupied.replaceAll(' - ', '-').replaceAll(' ', '');
          return normalizedSlot == normalizedOccupied;
        });
      }).toList();

      setState(() {
        _availableTimeSlots = availableSlots;
      });

      print('📅 Date: ${DateFormat('yyyy-MM-dd').format(date)}');
      print('   Total créneaux: ${allSlots.length}');
      print('   Créneaux occupés: ${occupiedSlots.length}');
      print('   Créneaux disponibles: ${availableSlots.length}');
    } catch (e) {
      print('❌ Erreur chargement créneaux: $e');
      setState(() {
        _availableTimeSlots = _getDefaultTimeSlots(date);
      });
    } finally {
      setState(() {
        isLoadingSlots = false;
      });
    }
  }

  List<String> _getDefaultTimeSlots(DateTime date) {
    // Vérifier si la configuration d'availability existe
    if (serviceData?['availability'] == null) {
      // Configuration par défaut si pas de config dans le JSON
      if (date.weekday == 7) return [];
      final defaultSlots = [
        '08:00 - 09:00',
        '09:00 - 10:00',
        '10:00 - 11:00',
        '11:00 - 12:00',
        '14:00 - 15:00',
        '15:00 - 16:00',
        '16:00 - 17:00',
        '17:00 - 18:00',
      ];
      return _filterPastTimeSlots(defaultSlots, date);
    }

    final availability = serviceData!['availability'];

    // Vérifier si le jour est exclu
    final excludedDays =
        (availability['excluded_days'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];

    if (excludedDays.contains(date.weekday)) {
      return [];
    }

    // Vérifier si le jour est dans les jours de travail
    final workingDays =
        (availability['working_days'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [1, 2, 3, 4, 5, 6];

    if (!workingDays.contains(date.weekday)) {
      return [];
    }

    // Vérifier s'il y a un horaire personnalisé pour ce jour
    final customSchedules =
        availability['custom_schedules'] as Map<String, dynamic>?;
    if (customSchedules != null &&
        customSchedules.containsKey(date.weekday.toString())) {
      final daySchedule = customSchedules[date.weekday.toString()];
      final slots =
          (daySchedule['time_slots'] as List<dynamic>?)
              ?.map((slot) => slot.toString())
              .toList() ??
          [];
      final formattedSlots = _formatTimeSlots(slots);
      return _filterPastTimeSlots(formattedSlots, date);
    }

    // Utiliser les créneaux par défaut
    final defaultSlots =
        (availability['time_slots'] as List<dynamic>?)
            ?.map((slot) => slot.toString())
            .toList() ??
        [];

    final formattedSlots = _formatTimeSlots(defaultSlots);
    return _filterPastTimeSlots(formattedSlots, date);
  }

  List<String> _formatTimeSlots(List<String> slots) {
    // Convertir "08:00-09:00" en "08:00 - 09:00" pour l'affichage
    return slots.map((slot) {
      if (slot.contains('-') && !slot.contains(' - ')) {
        return slot.replaceAll('-', ' - ');
      }
      return slot;
    }).toList();
  }

  List<String> _filterPastTimeSlots(List<String> slots, DateTime date) {
    // Si ce n'est pas aujourd'hui, retourner tous les créneaux
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (!isToday) {
      return slots;
    }

    // Filtrer les créneaux passés pour aujourd'hui
    final currentTime = TimeOfDay.now();
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    return slots.where((slot) {
      // Extraire l'heure de début du créneau
      // Format: "08:00 - 09:00" ou "08:00-09:00"
      String startTime = slot.split('-')[0].trim();

      // Parser l'heure
      final parts = startTime.split(':');
      if (parts.length != 2) return false;

      final slotHour = int.tryParse(parts[0]);
      final slotMinute = int.tryParse(parts[1]);

      if (slotHour == null || slotMinute == null) return false;

      final slotMinutes = slotHour * 60 + slotMinute;

      // Ajouter un buffer de 30 minutes (le créneau doit commencer dans au moins 30 min)
      final bufferMinutes = 30;

      return slotMinutes >= (currentMinutes + bufferMinutes);
    }).toList();
  }

  bool _hasAvailableSlots(DateTime date) {
    // Récupérer les créneaux pour cette date
    final slots = _getDefaultTimeSlots(date);
    // S'il reste des créneaux après filtrage, la date est disponible
    return slots.isNotEmpty;
  }

  DateTime _findFirstAvailableDate() {
    // Chercher le premier jour disponible dans les 90 prochains jours
    final now = DateTime.now();

    for (int i = 0; i < 90; i++) {
      final date = now.add(Duration(days: i));

      // Vérifier si ce jour a des créneaux disponibles
      if (_hasAvailableSlots(date)) {
        return date;
      }
    }

    // Si aucun jour disponible trouvé, retourner aujourd'hui
    return now;
  }

  double _calculateAmount() {
    double basePrice = 0;

    // Prix de base de la prestation
    if (_currentPrestationData != null) {
      final price = _currentPrestationData!['price'];
      if (price != null) {
        basePrice = (price is int) ? price.toDouble() : (price as double);
      }
    }

    // Prix de la variante (remplace le prix de base)
    if (_selectedVariantId != null && _currentPrestationData?['variants'] != null) {
      final variants = _currentPrestationData!['variants'] as List;
      try {
        final variant = variants.firstWhere(
          (v) => v['id'] == _selectedVariantId,
        );
        if (variant != null && variant['price'] != null) {
          final variantPrice = variant['price'];
          basePrice = (variantPrice is int) ? variantPrice.toDouble() : (variantPrice as double);
        }
      } catch (e) {
        // Variante non trouvée, garder le prix de base
      }
    }

    return basePrice;
  }

  Future<void> submitReservation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTimeSlot == null) {
      CustomOverlay.showError(
        context,
        message: _getText(
          'error_no_timeslot',
          'Veuillez sélectionner un créneau horaire',
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      Map<String, dynamic> requestBody = {};

      if (serviceData!['body'] != null) {
        print(serviceData!['body']);
        serviceData!['body'].forEach((apiKey, formKey) {
          if (formKey == 'date') {
            requestBody[apiKey] = DateFormat(
              'yyyy-MM-dd',
            ).format(_selectedDate);
          } else if (formKey == 'timeSlot') {
            requestBody[apiKey] = _selectedTimeSlot;
          } else if (formKey == 'amount') {
            // Calculer automatiquement le montant
            final amount = _calculateAmount();
            print('💰 Montant calculé: $amount');
            requestBody[apiKey] = amount;
          } else if (formKey == 'service_name') {
            // Ajouter automatiquement le nom du service
            final serviceName = serviceData!['name'];
            print('🏪 Service: $serviceName');
            requestBody[apiKey] = serviceName;
          } else if (formKey == 'payment_method') {
            // Ajouter la méthode de paiement par défaut
            print('💳 Méthode: MTN_MONEY');
            requestBody[apiKey] = 'MTN_MONEY';
          } else if (formValues.containsKey(formKey)) {
            requestBody[apiKey] = formValues[formKey];
          } else {
            requestBody[apiKey] = formKey;
          }
        });
      } else {
        requestBody = {
          ...formValues,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'timeSlot': _selectedTimeSlot,
        };
      }

      // ⚠️ AJOUTER LES CHAMPS OBLIGATOIRES (même si absents du JSON)
      if (!requestBody.containsKey('service_name')) {
        final serviceName = serviceData!['name'];
        print('🏪 [AUTO] Service: $serviceName');
        requestBody['service_name'] = serviceName;
      }

      if (!requestBody.containsKey('amount')) {
        final amount = _calculateAmount();
        print('💰 [AUTO] Montant calculé: $amount');
        requestBody['amount'] = amount;
      }

      if (!requestBody.containsKey('payment_method')) {
        print('💳 [AUTO] Méthode: MTN_MONEY');
        requestBody['payment_method'] = 'MTN_MONEY';
      }

      print('📅 Soumission réservation: $requestBody');

      String url = serviceData!['link_momo'] ?? '';
      bool success = await _apiService.submitFormData(
        context,
        url,
        requestBody,
        serviceData,
        null,
        false,
      );

      if (mounted && success) {
        setState(() {
          formValues.clear();
          controllers.forEach((_, controller) => controller.clear());
          _selectedTimeSlot = null;
          _selectedDate = DateTime.now();
        });
      }
    } catch (e) {
      print('❌ Erreur réservation: $e');
      if (mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors de la réservation',
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

  String _getText(String key, String defaultValue) {
    return serviceData?['texts']?[key]?.toString() ?? defaultValue;
  }

  void _nextStep() {
    if (_currentStep == 1) {
      // Vérifier qu'une prestation est sélectionnée
      if (formValues['type_prestation'] == null) {
        CustomOverlay.showError(
          context,
          message: _getText(
            'error_no_prestation',
            'Veuillez sélectionner une prestation',
          ),
        );
        return;
      }

      // Vérifier qu'une variante est sélectionnée si la prestation a des variantes
      if (_currentPrestationData != null) {
        final variants = _currentPrestationData!['variants'] as List<dynamic>?;
        if (variants != null && variants.isNotEmpty) {
          if (_selectedVariantId == null) {
            CustomOverlay.showError(
              context,
              message: _getText(
                'error_no_variant',
                'Veuillez sélectionner une option',
              ),
            );
            return;
          }
        }
      }

      // Trouver et sélectionner automatiquement le premier jour disponible
      setState(() {
        _selectedDate = _findFirstAvailableDate();
        _focusedDate = _selectedDate;
      });
    } else if (_currentStep == 2) {
      // Charger les créneaux pour la date sélectionnée
      _loadAvailableTimeSlots(_selectedDate);
    }

    if (_currentStep < _totalSteps) {
      setState(() {
        _currentStep++;
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: Colors.white,
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final stepNumber = index + 1;
          final isCompleted = stepNumber < _currentStep;
          final isCurrent = stepNumber == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted || isCurrent
                              ? FormStyles.primaryColor
                              : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : Text(
                                  '$stepNumber',
                                  style: TextStyle(
                                    color: isCurrent
                                        ? Colors.white
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stepNumber == 1
                            ? _getText('step_1_label', 'Prestation')
                            : stepNumber == 2
                            ? _getText('step_2_label', 'Date')
                            : _getText('step_3_label', 'Détails'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrent
                              ? FormStyles.primaryColor
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < _totalSteps - 1)
                  Container(
                    height: 2,
                    width: 20,
                    color: stepNumber < _currentStep
                        ? FormStyles.primaryColor
                        : Colors.grey[300],
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showInstructionsModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: FormStyles.primaryColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Comment ça marche',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      serviceData!['comment_payer'] ??
                          'Instructions non disponibles',
                      style: const TextStyle(fontSize: 15, height: 1.6),
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

  Widget buildHeroSection() {
    if (serviceData?['banner'] == null && serviceData?['description'] == null) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (serviceData?['banner'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Image.network(
                    serviceData!['banner'],
                    fit: BoxFit.cover,
                    height: 220,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FormStyles.primaryColor,
                              FormStyles.primaryColor.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.calendar_today,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceData!['title'] ?? widget.serviceName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Service professionnel',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (serviceData?['description'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceData!['description'],
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2C3E50),
                      height: 1.6,
                    ),
                  ),
                  if (serviceData?['comment_payer'] != null) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _showInstructionsModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: FormStyles.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: FormStyles.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Comment ça marche ?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: FormStyles.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultPrestationImage(int index) {
    // Différentes couleurs et icônes pour chaque prestation
    final List<Map<String, dynamic>> defaultStyles = [
      {'color': const Color(0xFF6366F1), 'icon': Icons.content_cut},
      {'color': const Color(0xFFEC4899), 'icon': Icons.brush},
      {'color': const Color(0xFF10B981), 'icon': Icons.face_retouching_natural},
      {'color': const Color(0xFFF59E0B), 'icon': Icons.spa},
      {'color': const Color(0xFF8B5CF6), 'icon': Icons.auto_awesome},
      {'color': const Color(0xFF06B6D4), 'icon': Icons.style},
    ];

    final style = defaultStyles[index % defaultStyles.length];

    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            style['color'] as Color,
            (style['color'] as Color).withOpacity(0.7),
          ],
        ),
      ),
      child: Icon(
        style['icon'] as IconData,
        size: 50,
        color: Colors.white.withOpacity(0.9),
      ),
    );
  }

  Widget _buildCategoryTabs(List<dynamic> categories) {
    // Initialiser la catégorie sélectionnée à "all" si elle n'est pas définie
    _selectedCategory ??= 'all';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Option "Toutes"
          _buildCategoryChip(
            id: 'all',
            label: 'Toutes',
            icon: Icons.grid_view,
            isSelected: _selectedCategory == 'all',
          ),
          const SizedBox(width: 10),
          // Catégories
          ...categories.map((category) {
            final id = category['id']?.toString() ?? '';
            final label = category['label']?.toString() ?? '';
            final iconName = category['icon']?.toString() ?? 'category';

            // Mapper les noms d'icônes vers IconData
            IconData icon = Icons.category;
            switch (iconName) {
              case 'content_cut':
                icon = Icons.content_cut;
                break;
              case 'face_retouching_natural':
                icon = Icons.face_retouching_natural;
                break;
              case 'auto_awesome':
                icon = Icons.auto_awesome;
                break;
              case 'spa':
                icon = Icons.spa;
                break;
              case 'brush':
                icon = Icons.brush;
                break;
              case 'style':
                icon = Icons.style;
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _buildCategoryChip(
                id: id,
                label: label,
                icon: icon,
                isSelected: _selectedCategory == id,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = id;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    FormStyles.primaryColor,
                    FormStyles.primaryColor.withOpacity(0.8),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? FormStyles.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: FormStyles.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVariantModal(Map<String, dynamic> prestationData) {
    final variants = prestationData['variants'] as List<dynamic>?;
    if (variants == null || variants.isEmpty) return;

    final prestationLabel = prestationData['label']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: FormStyles.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.tune,
                            color: FormStyles.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prestationLabel,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              Text(
                                'Choisissez une option',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Variantes
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(20),
                      itemCount: variants.length,
                      itemBuilder: (context, index) {
                        final variant = variants[index];
                        final variantId = variant['id']?.toString() ?? '';
                        final label = variant['label']?.toString() ?? '';
                        final price = variant['price'] as int?;
                        final description = variant['description']?.toString();
                        final isSelected = _selectedVariantId == variantId;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedVariantId = variantId;
                                if (price != null) {
                                  formValues['variant_price'] = price;
                                }
                                formValues['variant'] = variantId;
                              });
                              setModalState(() {});
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [
                                          FormStyles.primaryColor
                                              .withOpacity(0.15),
                                          FormStyles.primaryColor
                                              .withOpacity(0.05),
                                        ],
                                      )
                                    : null,
                                color: isSelected ? null : Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? FormStyles.primaryColor
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: FormStyles.primaryColor
                                              .withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? FormStyles.primaryColor
                                            : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                      color: isSelected
                                          ? FormStyles.primaryColor
                                          : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 18,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? FormStyles.primaryColor
                                                : const Color(0xFF2C3E50),
                                          ),
                                        ),
                                        if (description != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            description,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (price != null) ...[
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? FormStyles.primaryColor
                                            : FormStyles.primaryColor
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${NumberFormat('#,##0', 'fr_FR').format(price)} F',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : FormStyles.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Bouton de validation
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                      onPressed: _selectedVariantId != null
                          ? () {
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FormStyles.primaryColor,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedVariantId != null
                                ? 'Valider la sélection'
                                : 'Sélectionnez une option',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedVariantId != null
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                          ),
                          if (_selectedVariantId != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle, color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildPrestationSelector() {
    final fields = serviceData?['fields'] as List<dynamic>? ?? [];
    final prestationField = fields.firstWhere(
      (field) => field['name'] == 'type_prestation',
      orElse: () => null,
    );

    if (prestationField == null) return const SizedBox();

    final options = prestationField['options'] as List<dynamic>? ?? [];
    if (options.isEmpty) return const SizedBox();

    // Vérifier si des catégories existent
    final categories = serviceData?['categories'] as List<dynamic>? ?? [];
    final hasCategories = categories.isNotEmpty;

    // Filtrer les options en fonction de la catégorie sélectionnée
    final filteredOptions = hasCategories && _selectedCategory != null && _selectedCategory != 'all'
        ? options.where((option) => option['category'] == _selectedCategory).toList()
        : options;

    // Toujours afficher les cards, même sans images
    final bool hasImages =
        options.isNotEmpty &&
        options.first is Map &&
        (options.first as Map).containsKey('image');

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FormStyles.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: FormStyles.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choisissez votre prestation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      '${filteredOptions.length} option${filteredOptions.length > 1 ? 's' : ''} disponible${filteredOptions.length > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasCategories) ...[
            const SizedBox(height: 20),
            _buildCategoryTabs(categories),
          ],
          const SizedBox(height: 20),
          if (filteredOptions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune prestation dans cette catégorie',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredOptions.length,
              itemBuilder: (context, index) {
                final option = filteredOptions[index];
              String value = option['value'] ?? '';
              String label = option['label'] ?? value;
              String? description = option['description'];
              int? price = option['price'];
              String? imageUrl = option['image'];
              bool isSelected = formValues['type_prestation'] == value;
              bool isPopular = index == 0;
              bool isBestValue = index == 2;

              return InkWell(
                onTap: () {
                  setState(() {
                    formValues['type_prestation'] = value;
                    // Stocker les données de la prestation pour accéder aux variantes
                    _currentPrestationData = option;
                    // Réinitialiser la variante sélectionnée
                    _selectedVariantId = null;
                    formValues.remove('variant');
                    formValues.remove('variant_price');

                    // Si pas de variantes, stocker le prix directement
                    final variants = option['variants'];
                    if (variants == null || (variants as List).isEmpty) {
                      if (price != null) {
                        formValues['variant_price'] = price;
                      }
                    }
                  });

                  // Si la prestation a des variantes, ouvrir la modale
                  final variants = option['variants'];
                  if (variants != null && (variants as List).isNotEmpty) {
                    _showVariantModal(option);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? FormStyles.primaryColor
                          : Colors.grey[200]!,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? FormStyles.primaryColor.withOpacity(0.2)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: isSelected ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: imageUrl != null && hasImages
                                ? Image.network(
                                    imageUrl,
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildDefaultPrestationImage(
                                        index,
                                      );
                                    },
                                  )
                                : _buildDefaultPrestationImage(index),
                          ),
                          if (isPopular)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.star,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Populaire',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (isBestValue && !isPopular)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Meilleur prix',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (isSelected)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: FormStyles.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label.split('(')[0].trim(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? FormStyles.primaryColor
                                      : const Color(0xFF2C3E50),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (description != null) ...[
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (price != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? FormStyles.primaryColor
                                        : FormStyles.primaryColor.withOpacity(
                                            0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${NumberFormat('#,##0', 'fr_FR').format(price)} FCFA',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : FormStyles.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildCalendarSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: FormStyles.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: FormStyles.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choisissez votre date',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    'Disponibilités jusqu\'à 90 jours',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _focusedDate,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            calendarFormat: _calendarFormat,
            locale: 'fr_FR',
            enabledDayPredicate: (day) {
              // Désactiver les jours passés
              if (day.isBefore(
                DateTime.now().subtract(const Duration(days: 1)),
              )) {
                return false;
              }

              // Vérifier la configuration d'availability
              if (serviceData?['availability'] != null) {
                final availability = serviceData!['availability'];

                // Vérifier les jours exclus
                final excludedDays =
                    (availability['excluded_days'] as List<dynamic>?)
                        ?.map((e) => e as int)
                        .toList() ??
                    [];

                if (excludedDays.contains(day.weekday)) {
                  return false;
                }

                // Vérifier les jours de travail
                final workingDays =
                    (availability['working_days'] as List<dynamic>?)
                        ?.map((e) => e as int)
                        .toList() ??
                    [1, 2, 3, 4, 5, 6];

                if (!workingDays.contains(day.weekday)) {
                  return false;
                }
              }

              // Vérifier si la journée a au moins un créneau disponible
              return _hasAvailableSlots(day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (selectedDay.isAfter(
                DateTime.now().subtract(const Duration(days: 1)),
              )) {
                setState(() {
                  _selectedDate = selectedDay;
                  _focusedDate = focusedDay;
                  _selectedTimeSlot = null;
                });
                _loadAvailableTimeSlots(selectedDay);
              }
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: FormStyles.primaryColor,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              todayDecoration: BoxDecoration(
                color: FormStyles.primaryColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: FormStyles.primaryColor,
                fontWeight: FontWeight.bold,
              ),
              weekendTextStyle: TextStyle(color: Colors.red[400]),
              outsideDaysVisible: false,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              formatButtonDecoration: BoxDecoration(
                color: FormStyles.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              formatButtonTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTimeSlotsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: FormStyles.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.access_time,
                  color: FormStyles.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sélectionnez un créneau',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      DateFormat('EEEE dd MMMM', 'fr_FR').format(_selectedDate),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isLoadingSlots)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_availableTimeSlots.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun créneau disponible',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Veuillez choisir une autre date',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableTimeSlots.map((slot) {
                bool isSelected = _selectedTimeSlot == slot;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTimeSlot = slot;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                FormStyles.primaryColor,
                                FormStyles.primaryColor.withOpacity(0.8),
                              ],
                            )
                          : null,
                      color: isSelected ? null : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? FormStyles.primaryColor
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? Icons.access_time
                              : Icons.access_time_outlined,
                          size: 18,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          slot,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[800],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget buildOtherFields() {
    final fields = serviceData?['fields'] as List<dynamic>? ?? [];
    final otherFields = fields
        .where((field) => field['name'] != 'type_prestation')
        .toList();

    if (otherFields.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: FormStyles.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_note,
                  color: FormStyles.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Vos coordonnées',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...otherFields.map((field) => _buildField(field)).toList(),
        ],
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    String fieldName = field['name'] ?? '';
    String fieldType = field['type'] ?? 'text';
    String fieldLabel = field['label'] ?? fieldName;
    bool isRequired = field['required'] ?? false;
    String? regex = field['regex'];
    String? regexError = field['regex_error'];

    if (fieldType == 'selecteur') {
      return _buildSelectField(field);
    }

    if (!controllers.containsKey(fieldName)) {
      controllers[fieldName] = TextEditingController();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controllers[fieldName],
        keyboardType: fieldType == 'number'
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: fieldLabel,
          filled: true,
          fillColor: Colors.grey[50],
          prefixIcon: Icon(
            fieldType == 'number' ? Icons.phone : Icons.text_fields,
            color: FormStyles.primaryColor,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: FormStyles.primaryColor, width: 2),
          ),
        ),
        onChanged: (value) {
          formValues[fieldName] = value;
        },
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Ce champ est requis';
          }
          if (regex != null && value != null && value.isNotEmpty) {
            RegExp regExp = RegExp(regex);
            if (!regExp.hasMatch(value)) {
              return regexError ?? 'Format invalide';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSelectField(Map<String, dynamic> field) {
    String fieldName = field['name'] ?? '';
    String fieldLabel = field['label'] ?? fieldName;
    bool isRequired = field['required'] ?? false;
    List<dynamic> options = field['options'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: formValues[fieldName],
        decoration: InputDecoration(
          labelText: fieldLabel,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: FormStyles.primaryColor, width: 2),
          ),
        ),
        items: options.map<DropdownMenuItem<String>>((option) {
          String value = option['value'] ?? '';
          String label = option['label'] ?? value;
          return DropdownMenuItem<String>(value: value, child: Text(label));
        }).toList(),
        onChanged: (value) {
          setState(() {
            formValues[fieldName] = value;
          });
        },
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Ce champ est requis';
          }
          return null;
        },
      ),
    );
  }

  Widget buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FormStyles.primaryColor.withOpacity(0.1),
            FormStyles.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FormStyles.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FormStyles.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Récapitulatif',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryRow(
            Icons.calendar_today,
            'Date de réservation',
            DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(_selectedDate),
          ),
          const Divider(height: 24),
          _buildSummaryRow(
            Icons.access_time,
            'Créneau horaire',
            _selectedTimeSlot ?? 'Non sélectionné',
          ),
          if (formValues['type_prestation'] != null) ...[
            const Divider(height: 24),
            _buildSummaryRow(
              Icons.content_cut,
              'Prestation',
              _getPrestationLabel(formValues['type_prestation']),
            ),
          ],
        ],
      ),
    );
  }

  String _getPrestationLabel(String? value) {
    if (value == null) return 'Non sélectionné';
    final fields = serviceData?['fields'] as List<dynamic>? ?? [];
    final prestationField = fields.firstWhere(
      (field) => field['name'] == 'type_prestation',
      orElse: () => null,
    );
    if (prestationField == null) return value;

    final options = prestationField['options'] as List<dynamic>? ?? [];
    final option = options.firstWhere(
      (opt) => opt['value'] == value,
      orElse: () => null,
    );

    return option?['label']?.toString().split('(')[0].trim() ?? value;
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: FormStyles.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: FormStyles.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.serviceName.replaceAll('\n', ''),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProgressIndicator(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentStep == 1) ...[
                            buildHeroSection(),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                _getText(
                                  'step_1_title',
                                  'Étape 1 : Choisissez votre prestation',
                                ),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: FormStyles.primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            buildPrestationSelector(),
                          ] else if (_currentStep == 2) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                _getText(
                                  'step_2_title',
                                  'Étape 2 : Sélectionnez la date',
                                ),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: FormStyles.primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            buildCalendarSection(),
                          ] else if (_currentStep == 3) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                _getText(
                                  'step_3_title',
                                  'Étape 3 : Finalisez votre réservation',
                                ),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: FormStyles.primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            buildTimeSlotsSection(),
                            buildSummaryCard(),
                            buildOtherFields(),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isLoading
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 1)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: FormStyles.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: FormStyles.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getText('button_previous', 'Précédent'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: FormStyles.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_currentStep > 1) const SizedBox(width: 12),
                  Expanded(
                    flex: _currentStep == 1 ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: _currentStep == _totalSteps
                          ? submitReservation
                          : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FormStyles.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == _totalSteps
                                ? _getText('button_confirm', 'Confirmer')
                                : _getText('button_next', 'Suivant'),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentStep == _totalSteps
                                ? Icons.check_circle
                                : Icons.arrow_forward,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
