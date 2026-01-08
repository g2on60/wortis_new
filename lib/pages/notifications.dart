// ignore_for_file: unused_field, non_constant_identifier_names, use_build_context_synchronously, avoid_print, constant_identifier_names, unused_element, deprecated_member_use

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wortis/class/PaymentRequestPage.dart';
import 'package:wortis/class/dynamic_navigation_service.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/class/dataprovider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

import 'package:wortis/pages/homepage_dias.dart';

// NOUVEAU IMPORT FIREBASE

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

enum NotificationType { payment, system, promotion, success }

class NotificationItem {
  final String title;
  final String message;
  final String time;
  final NotificationType type;
  final String? link_get_info;
  bool isRead;
  bool isExpanded;

  NotificationItem({
    required this.title,
    required this.message,
    required this.time,
    this.link_get_info,
    required this.type,
    this.isRead = false,
    this.isExpanded = false, // Valeur par défaut
  });
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final bool _isLoading = false;
  final List<NotificationData> _notifications = [];
  final int _unreadNotificationCount = 0;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
    super.initState();
    Future.microtask(() async {
      try {
        await Provider.of<AppDataProvider>(
          context,
          listen: false,
        ).loadNotificationsIfNeeded();
      } catch (e) {
        if (mounted) {
          CustomOverlay.showError(
            context,
            message: 'Erreur lors du chargement des notifications',
          );
        }
      }
    });
    Provider.of<AppDataProvider>(
      context,
      listen: false,
    ).startPeriodicNotificationRefresh();
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AppDataProvider>(
      builder: (context, provider, child) {
        final notifications = provider.notifications;
        final unreadCount = notifications
            .where((n) => n.statut == "non lu")
            .length;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => _returnToHomePage(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.done_all, color: Colors.white),
                onPressed: () => _markAllAsReadWithFeedback(),
              ),
              // NOUVEAU BOUTON : Test Firebase
              // if (provider.isFirebaseInitialized)
              //   IconButton(
              //     icon: const Icon(Icons.cloud, color: Colors.white),
              //     onPressed: () => _sendFirebaseTestNotification(provider),
              //     tooltip: 'Test Firebase',
              //   ),
            ],
            backgroundColor: const Color(0xFF006699),
          ),
          body: Column(
            children: [
              _buildNotificationStats(provider, unreadCount),
              // NOUVEAU : Statut Firebase
              // if (provider.isFirebaseInitialized)
              //   _buildFirebaseStatus(provider),
              Expanded(
                child: provider.isNotificationsLoading && notifications.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : notifications.isEmpty
                    ? _buildEmptyState()
                    : _buildNotificationList(provider, notifications),
              ),
            ],
          ),
        );
      },
    );
  }

  // NOUVELLE MÉTHODE : Afficher le statut Firebase
  Widget _buildFirebaseStatus(AppDataProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green[50],
      child: Row(
        children: [
          Icon(Icons.cloud_done, color: Colors.green[700], size: 16),
          const SizedBox(width: 8),
          Text(
            'Firebase connecté',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (provider.fcmToken != null)
            Text(
              'Token: ${provider.fcmToken!.substring(0, 10)}...',
              style: TextStyle(
                color: Colors.green[600],
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  // // NOUVELLE MÉTHODE : Test notification Firebase
  // Future<void> _sendFirebaseTestNotification(AppDataProvider provider) async {
  //   CustomOverlay.showLoading(
  //     context,
  //     message: 'Envoi notification Firebase...',
  //   );

  //   try {
  //     await provider.sendTestFirebaseNotification();

  //     CustomOverlay.hide();

  //     if (context.mounted) {
  //       CustomOverlay.showSuccess(
  //         context,
  //         message: 'Notification Firebase envoyée !',
  //       );
  //     }
  //   } catch (e) {
  //     CustomOverlay.hide();

  //     if (context.mounted) {
  //       CustomOverlay.showError(
  //         context,
  //         message: 'Erreur Firebase: ${e.toString()}',
  //       );
  //     }
  //   }
  // }

  Future<void> _markAllAsReadWithFeedback() async {
    final provider = Provider.of<AppDataProvider>(context, listen: false);

    // Afficher loading
    CustomOverlay.showLoading(
      context,
      message: 'Marquage des notifications en cours...',
    );

    try {
      await provider.markAllNotificationsAsRead();

      CustomOverlay.hide();

      if (context.mounted) {
        CustomOverlay.showSuccess(
          context,
          message: 'Toutes les notifications ont été marquées comme lues',
        );
      }
    } catch (e) {
      CustomOverlay.hide();

      if (context.mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors du marquage: ${e.toString()}',
        );
      }
    }
  }

  Widget _buildNotificationStats(AppDataProvider provider, int unreadCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$unreadCount nouvelle${unreadCount > 1 ? 's' : ''} notification${unreadCount > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF006699),
            ),
          ),
          TextButton(
            onPressed: () => _deleteAllWithFeedback(),
            child: const Text(
              'Tout effacer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllWithFeedback() async {
    final provider = Provider.of<AppDataProvider>(context, listen: false);

    // Afficher loading
    CustomOverlay.showLoading(
      context,
      message: 'Suppression de toutes les notifications...',
    );

    try {
      await provider.deleteAllNotifications();

      CustomOverlay.hide();

      if (context.mounted) {
        CustomOverlay.showSuccess(
          context,
          message: 'Toutes les notifications ont été supprimées',
        );
      }
    } catch (e) {
      CustomOverlay.hide();

      if (context.mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors de la suppression: ${e.toString()}',
        );
      }
    }
  }

  Widget _buildNotificationList(
    AppDataProvider provider,
    List<NotificationData> notifications,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: notifications.length + 1,
      itemBuilder: (context, index) {
        if (index == notifications.length) {
          return _buildLoadMoreButton(provider);
        }
        return _buildNotificationCard(provider, notifications[index]);
      },
    );
  }

  Widget _buildNotificationCard(
    AppDataProvider provider,
    NotificationData notification,
  ) {
    final bool isUnread = notification.statut == "non lu";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: isUnread ? 3 : 1, // Plus d'emphase sur les non lues
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _showNotificationDetails(context, provider, notification);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // Remplacé AnimatedContainer par Container pour plus de performance
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isUnread ? Colors.blue[50] : Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationIcon(notification),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Utilisation de const où possible pour éviter les reconstructions inutiles
                        const SizedBox(height: 4),
                        _buildRichTextWithLinks(
                          notification.contenu,
                          notification.isExpanded,
                        ),
                        const SizedBox(height: 8),
                        _buildTimeAgo(notification),
                      ],
                    ),
                  ),
                  _buildNotificationActions(provider, notification),
                ],
              ),
              _buildExpandButton(provider, notification),
            ],
          ),
        ),
      ),
    );
  }

  // Nouvelle méthode pour marquer avec feedback
  Future<void> _markAsReadWithFeedback(
    BuildContext context,
    AppDataProvider provider,
    String notificationId,
  ) async {
    try {
      await provider.markNotificationAsRead(notificationId);
      // Pas de message de succès pour le marquage (trop intrusif)
    } catch (e) {
      if (context.mounted) {
        CustomOverlay.showError(
          context,
          message: 'Erreur lors du marquage: ${e.toString()}',
        );
      }
    }
  }

  // Méthode pour gérer les clics sur les notifications dans la liste
  // Méthode pour gérer les clics sur les notifications dans la liste
  void _handleNotificationItemTap(NotificationData notification) {
    // Marquer comme lue
    Provider.of<AppDataProvider>(
      context,
      listen: false,
    ).markNotificationAsRead(notification.id);

    // Vérifier s'il y a une action spécifique
    final action = notification.action ?? 'open_notifications';

    // Utiliser le service de navigation dynamique
    DynamicNavigationService.handleDynamicNavigation(
      action,
      additionalData: {
        'notification_id': notification.id,
        'notification_type': notification.type,
        'link_get_info': notification.linkGetInfo,
      },
    );
  }

  void _handlePayload(String? payload) {
    if (payload != null) {
      try {
        final data = json.decode(payload);
        final action = data['action'] ?? 'open_notifications';

        // NOUVELLE LOGIQUE: Passer toutes les données au service
        DynamicNavigationService.handleDynamicNavigation(
          action,
          additionalData: Map<String, dynamic>.from(data)..remove('action'),
        );
      } catch (e) {
        DynamicNavigationService.handleDynamicNavigation('open_notifications');
      }
    }
  }

  void _showNotificationDetails(
    BuildContext context,
    AppDataProvider provider,
    NotificationData notification,
  ) {
    // Marquer comme lu
    if (notification.statut == "non lu") {
      _markAsReadWithFeedback(context, provider, notification.id);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: 400,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête avec icône et type de notification
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(
                      notification.type,
                    ).withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getNotificationIcon(notification.type),
                        color: _getNotificationColor(notification.type),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          notification.type.toUpperCase(),
                          style: TextStyle(
                            color: _getNotificationColor(notification.type),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.grey[600],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // Corps de la notification
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Titre
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Text(
                            notification.title,
                            textAlign: TextAlign
                                .center, // Ajouté pour centrer le texte
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        // Date
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Text(
                            notification.getTimeAgo(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),

                        // Contenu principal
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Text(
                            notification.contenu,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bouton de paiement (si nécessaire)
                if (notification.button == true &&
                    notification.link_get_info.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Fermer la boîte de dialogue
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentRequestPage(
                              requestUrl: notification.link_get_info,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment_rounded, size: 20),
                      label: const Text('Voir la demande de paiement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006699),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  // Fonction helper pour la couleur selon le type
  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'Devis':
        return const Color.fromARGB(255, 0, 102, 153);
      case 'paiement':
        return Colors.green;
      case 'demande de paiement':
        return Colors.orange;
      case 'maj':
        return Colors.blue;
      case 'promotions':
        return Colors.purple;
      case 'kdo':
        return Colors.pink;
      case 'info':
        return Colors.yellow;
      default:
        return const Color.fromARGB(255, 0, 102, 153);
    }
  }

  // Fonction helper pour l'icône selon le type
  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'paiement':
        return Icons.payment;
      case 'demande de paiement':
        return Icons.request_page;
      case 'maj':
        return Icons.system_update;
      case 'promotions':
        return Icons.local_offer;
      case 'Devis':
        return Icons.monetization_on;
      case 'kdo':
        return Icons.card_giftcard;
      case 'alerte':
        return Icons.warning; // Icône pour les alertes
      case 'message':
        return Icons.message; // Icône pour les messages
      case 'info':
        return Icons.info; // Icône pour les informations
      default:
        return Icons.notifications; // Icône par défaut
    }
  }

  Widget _buildTimeAgo(NotificationData notification) {
    return Row(
      children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          notification.getTimeAgo(),
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildNotificationActions(
    AppDataProvider provider,
    NotificationData notification,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton de paiement stylisé
        if (notification.button == true)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF006699), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF006699).withOpacity(0.15),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        // Animation pour le survol du bouton de suppression
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _showDeleteConfirmation(provider, notification),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 24,
            tooltip: 'Supprimer',
          ),
        ),
        const SizedBox(width: 8),

        // Indicateur de notification non lue amélioré
        if (notification.statut == "non lu")
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF006699),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF006699).withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRichTextWithLinks(String text, bool isExpanded) {
    // Expression régulière pour détecter les URLs
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    List<TextSpan> textSpans = [];
    int lastMatchEnd = 0;

    // Trouve tous les liens dans le texte
    for (Match match in urlPattern.allMatches(text)) {
      final String url = match.group(0)!;

      // Ajoute le texte avant le lien
      if (match.start > lastMatchEnd) {
        textSpans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        );
      }

      // Ajoute le lien cliquable
      textSpans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF006699),
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final Uri uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                // Afficher un message d'erreur si le lien ne peut pas être ouvert
                if (context.mounted) {
                  CustomOverlay.showError(
                    context,
                    message: 'Impossible d\'ouvrir le lien: $url',
                  );
                }
              }
            },
        ),
      );

      lastMatchEnd = match.end;
    }

    // Ajoute le reste du texte après le dernier lien
    if (lastMatchEnd < text.length) {
      textSpans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: textSpans),
      maxLines: isExpanded ? null : 2,
      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }

  // Dans NotificationPage
  void _showDeleteConfirmation(
    AppDataProvider provider,
    NotificationData notification,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text(
            'Voulez-vous vraiment supprimer cette notification ?',
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => _deleteWithFeedback(provider, notification),
            ),
          ],
        );
      },
    );
  }

  // Suppression avec CustomOverlay
  Future<void> _deleteWithFeedback(
    AppDataProvider provider,
    NotificationData notification,
  ) async {
    Navigator.of(context).pop(); // Fermer le dialog

    // Afficher loading
    CustomOverlay.showLoading(context, message: 'Suppression en cours...');

    try {
      final success = await provider.deleteNotification(notification);

      // Cacher loading
      CustomOverlay.hide();

      if (context.mounted) {
        if (success) {
          CustomOverlay.showSuccess(
            context,
            message: 'Notification supprimée avec succès',
          );
        } else {
          CustomOverlay.showError(context, message: 'Échec de la suppression');
        }
      }
    } catch (e) {
      CustomOverlay.hide();
      if (context.mounted) {
        CustomOverlay.showError(context, message: 'Erreur: ${e.toString()}');
      }
    }
  }

  Widget _buildExpandButton(
    AppDataProvider provider,
    NotificationData notification,
  ) {
    if (notification.contenu.length < 100) {
      return const SizedBox.shrink(); // Ne pas montrer si contenu court
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => provider.toggleNotificationExpansion(notification),
        icon: Icon(
          notification.isExpanded ? Icons.expand_less : Icons.expand_more,
          color: const Color(0xFF006699),
          size: 20,
        ),
        label: Text(
          notification.isExpanded ? 'Voir moins' : 'Voir plus',
          style: const TextStyle(color: Color(0xFF006699), fontSize: 12),
        ),
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8),
          ),
          minimumSize: WidgetStateProperty.all(const Size(0, 30)),
          overlayColor: WidgetStateProperty.all(
            const Color(0xFF006699).withOpacity(0.1),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationData notification) {
    IconData icon;
    Color color;

    switch (notification.type.toLowerCase()) {
      case 'paiement':
        icon = Icons.payment;
        color = Colors.green;
        break;
      case 'demande de paiement':
        icon = Icons.request_page;
        color = Colors.orange;
        break;
      case 'maj':
        icon = Icons.system_update;
        color = Colors.blue;
        break;
      case 'promotions':
        icon = Icons.local_offer;
        color = Colors.purple;
        break;
      case 'kdo':
        icon = Icons.card_giftcard;
        color = Colors.pink;
        break;
      case 'Devis':
        icon = Icons.monetization_on;
        color = const Color.fromARGB(255, 0, 102, 153);
        break;
      default:
        icon = Icons.notifications;
        color = const Color.fromARGB(255, 0, 102, 153);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildLoadMoreButton(AppDataProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: provider.isNotificationsLoading
            ? const CircularProgressIndicator(color: Color(0xFF006699))
            : TextButton(
                onPressed: () => provider.refreshNotifications(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF006699)),
                  ),
                ),
                child: const Text(
                  'Voir plus',
                  style: TextStyle(color: Color(0xFF006699)),
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous n\'avez pas de nouvelles notifications',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  // Traitement minimal en arrière-plan
  if (response.payload != null) {
    try {
      final data = json.decode(response.payload!);
      // Sauvegarder l'action pour traitement ultérieur si nécessaire
    } catch (e) {
      // Erreur payload
    }
  }
}

// SERVICE DE NOTIFICATIONS PUSH MODIFIÉ AVEC FIREBASE
class PushNotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey;
  bool isInitialLaunch = true;

  PushNotificationService({required this.navigatorKey});

  Future<void> initNotification() async {
    print('🔔 [Service] Initialisation du service de notifications...');

    // // 1. NOUVEAU : Initialiser Firebase en premier
    // try {
    //   await FirebaseMessagingService.initialize();
    //   print('✅ [Service] Firebase Messaging initialisé');
    // } catch (e) {
    //   print('❌ [Service] Erreur initialisation Firebase: $e');
    //   // Continuer sans Firebase en cas d'erreur
    // }

    // 2. Configuration Android pour notifications locales
    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Configuration iOS pour notifications locales
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          notificationCategories: [
            DarwinNotificationCategory(
              'default_notification_category',
              actions: [
                DarwinNotificationAction.plain(
                  'open_notification',
                  'Ouvrir',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
              options: {
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
          ],
        );

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 4. Initialiser les notifications locales
    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );

    // 5. Vérifier si l'app a été lancée par une notification
    await _checkNotificationLaunch();

    // 6. Vérifier les notifications non lues au démarrage
    Future.delayed(const Duration(seconds: 2), () {
      checkUnreadNotificationsAtStartup();
    });

    isInitialLaunch = false;

    print('✅ [Service] Service de notifications initialisé');
  }

  // MODIFIÉ : Vérification des notifications non lues avec intégration Firebase
  Future<void> checkUnreadNotificationsAtStartup() async {
    print('🔔 [Startup] Vérification des notifications non lues...');

    try {
      // Récupérer le token depuis les préférences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('user_token');

      if (token == null) {
        print(
          '⚠️ [Startup] Token non trouvé, impossible de vérifier les notifications',
        );
        return;
      }

      // Faire la requête à votre API existante
      final response = await http.get(
        Uri.parse('https://api.live.wortis.cg/notifications_test/$token'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> notifications = jsonDecode(response.body);
        final unreadNotifications = notifications.where((notif) {
          return notif['statut']?.toString().toLowerCase() == 'non lu';
        }).toList();

        if (unreadNotifications.isNotEmpty) {
          await _showUnreadNotificationSummary(unreadNotifications);
        } else {
          print('ℹ️ [Startup] Aucune notification non lue');
        }

        // NOUVEAU : S'abonner aux topics Firebase si nécessaire
        // await _subscribeToFirebaseTopics(token);
      }
    } catch (e) {
      print('❌ [Startup] Erreur lors de la vérification: $e');
    }
  }

  // NOUVEAU : S'abonner aux topics Firebase basés sur l'utilisateur
  // Future<void> _subscribeToFirebaseTopics(String userToken) async {
  //   try {
  //     // Vous pouvez créer des topics basés sur l'utilisateur, région, etc.
  //     await FirebaseMessagingService.subscribeToTopic('all_users');

  //     // Exemple : topic basé sur l'ID utilisateur (à adapter selon vos besoins)
  //     // await FirebaseMessagingService.subscribeToTopic('user_$userId');

  //     print('✅ [Firebase] Abonné aux topics Firebase');
  //   } catch (e) {
  //     print('❌ [Firebase] Erreur abonnement topics: $e');
  //   }
  // }

  // Afficher une notification de résumé des messages non lus
  Future<void> _showUnreadNotificationSummary(
    List<dynamic> unreadNotifications,
  ) async {
    final int count = unreadNotifications.length;

    String title;
    String body;

    if (count == 1) {
      // Une seule notification non lue
      final notification = unreadNotifications.first;
      title = notification['title'] ?? 'Notification non lue';
      body = notification['contenu'] ?? 'Vous avez 1 message non lu';
    } else {
      // Plusieurs notifications non lues
      title = 'Notifications non lues';
      body = 'Vous avez $count messages non lus à consulter';
    }

    try {
      await notificationsPlugin.show(
        9999, // ID spécial pour le résumé
        title,
        body,
        getNotificationDetails('summary'),
        payload: json.encode({
          'type': 'summary',
          'action': 'open_notifications',
          'count': count,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      print(
        '✅ [Startup] Notification de résumé affichée: $count messages non lus',
      );
    } catch (e) {
      print('❌ [Startup] Erreur affichage notification résumé: $e');
    }
  }

  // Vérification séparée du lancement par notification
  Future<void> _checkNotificationLaunch() async {
    try {
      final NotificationAppLaunchDetails? launchDetails =
          await notificationsPlugin.getNotificationAppLaunchDetails();

      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse != null) {
        print(
          '🔔 App lancée par notification: ${launchDetails.notificationResponse!.payload}',
        );

        // Délai pour s'assurer que l'app est complètement initialisée
        await Future.delayed(const Duration(milliseconds: 1000));

        // Traiter la réponse de notification
        _handleNotificationResponse(launchDetails.notificationResponse!);
      }
    } catch (e) {
      print(
        '❌ Erreur lors de la vérification du lancement par notification: $e',
      );
    }
  }

  // Gestion spécifique pour iOS < 10
  void _showNotificationAlert(String title, String body, String? payload) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Fermer'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Ouvrir'),
              onPressed: () {
                Navigator.pop(context);
                _handlePayload(payload);
              },
            ),
          ],
        ),
      );
    }
  }

  void _handlePayload(String? payload) {
    if (payload != null) {
      try {
        print('🔔 Traitement du payload: $payload');

        final data = json.decode(payload);
        final action = data['action'] ?? '';

        switch (action) {
          case 'open_notifications':
            _navigateToNotifications();
            break;
          case 'open_specific_notification':
            final notificationId = data['notification_id'];
            _navigateToSpecificNotification(notificationId);
            break;
          case 'open_wallet':
            _navigateToWallet();
            break;
          case 'open_transaction':
            final transactionId = data['transaction_id'];
            _navigateToTransaction(transactionId);
            break;
          default:
            _navigateToNotifications();
        }
      } catch (e) {
        print('❌ Erreur lors du traitement du payload: $e');
        _navigateToNotifications();
      }
    }
  }

  // Navigation vers une notification spécifique
  void _navigateToSpecificNotification(String? notificationId) {
    print('🔔 Navigation vers notification spécifique: $notificationId');
    _navigateToNotifications();
  }

  // NOUVEAU : Navigation vers le portefeuille
  void _navigateToWallet() {
    print('🔔 Navigation vers le portefeuille');
    Future.microtask(() async {
      final context = navigatorKey.currentContext;
      if (context != null) {
        await Future.delayed(const Duration(milliseconds: 100));

        if (navigatorKey.currentContext != null) {
          // Adaptez selon vos routes
          Navigator.of(navigatorKey.currentContext!).pushNamed('/wallet');
        }
      }
    });
  }

  // NOUVEAU : Navigation vers une transaction
  void _navigateToTransaction(String? transactionId) {
    print('🔔 Navigation vers transaction: $transactionId');
    Future.microtask(() async {
      final context = navigatorKey.currentContext;
      if (context != null) {
        await Future.delayed(const Duration(milliseconds: 100));

        if (navigatorKey.currentContext != null) {
          // Adaptez selon vos routes
          Navigator.of(
            navigatorKey.currentContext!,
          ).pushNamed('/transaction/$transactionId');
        }
      }
    });
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  // Navigation vers les notifications (mise à jour)
  void _navigateToNotifications() {
    Future.microtask(() async {
      final context = navigatorKey.currentContext;
      if (context != null) {
        await Future.delayed(const Duration(milliseconds: 100));

        if (navigatorKey.currentContext != null) {
          Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const NotificationPage()),
            (route) => false,
          );
        }
      } else {
        print('⚠️ Context non disponible pour la navigation');
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToNotifications();
        });
      }
    });
  }

  NotificationDetails getNotificationDetails(String type) {
    // Configuration spéciale pour les résumés
    if (type == 'summary') {
      AndroidNotificationDetails androidDetails =
          const AndroidNotificationDetails(
            'unread_summary_channel',
            'Résumé notifications',
            channelDescription: 'Notifications de résumé des messages non lus',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'wpay_icon',
            color: Color(0xFF006699),
            colorized: true,
          );

      DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'unread_summary_category',
      );

      return NotificationDetails(android: androidDetails, iOS: iosDetails);
    }

    // Configuration par défaut
    AndroidNotificationDetails androidDetails =
        const AndroidNotificationDetails(
          'default_channel',
          'Notifications',
          channelDescription: 'Canal principal des notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          enableLights: true,
          icon: 'wpay_icon',
          playSound: true,
          channelShowBadge: true,
          fullScreenIntent: true,
        );

    // Configuration iOS
    DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
      categoryIdentifier: 'default_notification_category',
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  Future<void> showNotification({
    required String type,
    required String title,
    required String body,
    int id = 0,
  }) async {
    try {
      await notificationsPlugin.show(
        id,
        title,
        body,
        getNotificationDetails(type),
        payload: json.encode({
          'type': type,
          'action': 'open_notifications',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      print('Erreur lors de l\'affichage de la notification: $e');
    }
  }

  // NOUVELLES méthodes utilitaires

  // Envoyer une notification de test
  Future<void> sendTestNotification() async {
    try {
      await notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Test Local',
        'Votre système de notifications locales fonctionne !',
        getNotificationDetails('test'),
        payload: json.encode({'action': 'open_notifications', 'type': 'test'}),
      );
    } catch (e) {
      print('❌ Erreur envoi notification test: $e');
    }
  }

  // Obtenir le token FCM
  // Future<String?> getFCMToken() async {
  //   return await FirebaseMessagingService.getCurrentToken();
  // }

  // Méthode pour demander les permissions iOS
  Future<void> requestIOSPermissions() async {
    if (Platform.isIOS) {
      await notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }
}

class BackgroundNotificationManager {
  static const String NOTIFICATION_TASK = "backgroundNotificationTask";
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const String baseUrl = "https://api.live.wortis.cg";

  // Configuration détaillée des notifications selon le type
  static NotificationDetails getNotificationDetails(String type) {
    // Configuration Android
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_notification_channel', // ID du canal
      'Notifications', // Nom du canal
      channelDescription: 'Canal pour toutes les notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      playSound: true,
      enableLights: true,
      ledColor: const Color(0xFF006699),
      ledOnMs: 1000,
      ledOffMs: 500,

      // Configurations spécifiques selon le type
      ticker: 'ticker',

      visibility: NotificationVisibility.public,
      // Style selon le type de notification
      styleInformation: _getNotificationStyle(type),
    );

    // Configuration iOS
    DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'default_notification_category',
      threadIdentifier: 'default_thread',
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  // Obtenir la catégorie de notification appropriée
  static String _getNotificationCategory(String type) {
    switch (type.toLowerCase()) {
      case 'paiement':
        return 'payment';
      case 'demande de paiement':
        return 'payment_request';
      case 'maj':
        return 'update';
      case 'promotions':
        return 'promotion';
      case 'kdo':
        return 'gift';
      default:
        return 'misc';
    }
  }

  // Obtenir le style de notification approprié
  static StyleInformation _getNotificationStyle(String type) {
    // Par défaut, style de base
    return const DefaultStyleInformation(true, true);
  }

  // Vérification des nouvelles notifications
  static Future<void> checkForNewNotifications() async {
    try {
      // Récupérer le token depuis les préférences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('user_token');

      if (token == null) {
        print('Token non trouvé, impossible de vérifier les notifications');
        return;
      }

      // Faire la requête à l'API
      final response = await http.get(
        Uri.parse('$baseUrl/notifications_test/$token'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Récupérer la dernière notification traitée
        final lastNotificationId = prefs.getInt('last_notification_id') ?? 0;

        final List<dynamic> notifications = jsonDecode(response.body);
        final unreadNotifications = notifications.where((notif) {
          final isUnread =
              notif['statut']?.toString().toLowerCase() == 'non lu';
          final isNew = int.parse(notif['id'].toString()) > lastNotificationId;
          return isUnread && isNew;
        }).toList();

        // Créer une notification pour chaque nouvelle notification non lue
        for (var notification in unreadNotifications) {
          await showNotification(
            id: int.parse(notification['id'].toString()),
            title: notification['title'] ?? 'Nouvelle notification',
            body: notification['contenu'] ?? '',
            type: notification['type'] ?? 'default',
            payload: json.encode(notification),
          );

          // Mettre à jour le dernier ID traité
          await prefs.setInt(
            'last_notification_id',
            int.parse(notification['id'].toString()),
          );
        }

        // Enregistrer le timestamp de la dernière vérification
        await prefs.setInt(
          'last_check_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      print('Erreur lors de la vérification des notifications: $e');
    }
  }

  // Afficher une notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    try {
      // Obtenir la configuration de notification appropriée
      final notificationDetails = getNotificationDetails(type);

      // Afficher la notification
      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      print('Notification affichée avec succès: ID=$id');
    } catch (e) {
      print('Erreur lors de l\'affichage de la notification: $e');
    }
  }

  // Annuler une notification spécifique
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // Annuler toutes les notifications
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
