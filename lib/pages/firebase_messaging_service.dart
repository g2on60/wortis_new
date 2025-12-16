// import 'dart:convert';
// import 'dart:io';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter/material.dart';
// import 'package:wortis/class/dynamic_navigation_service.dart';
// import 'package:wortis/pages/notifications.dart';

// // Handler pour les messages en arrière-plan (doit être une fonction globale)
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   //print('🔥 [Background] Message Firebase reçu: ${message.messageId}');
//   //print('🔥 [Background] Titre: ${message.notification?.title}');
//   //print('🔥 [Background] Corps: ${message.notification?.body}');
//   //print('🔥 [Background] Data: ${message.data}');

//   // Vous pouvez traiter les données ici si nécessaire
//   // Mais évitez les opérations lourdes
// }

// class FirebaseMessagingService {
//   static final FirebaseMessaging _firebaseMessaging =
//       FirebaseMessaging.instance;
//   static final FlutterLocalNotificationsPlugin _localNotifications =
//       FlutterLocalNotificationsPlugin();
//   static const String baseUrl = "https://api.live.wortis.cg";

//   // Initialisation du service
//   static Future<void> initialize() async {
//     //print('🔥 [Firebase] Initialisation du service Firebase Messaging...');

//     try {
//       // 1. Demander les permissions
//       await _requestPermission();

//       // 2. Configurer les notifications locales
//       await _setupLocalNotifications();

//       // 3. Configurer les handlers Firebase
//       await _setupFirebaseHandlers();

//       // 4. Obtenir et envoyer le token au serveur
//       await _getAndSendToken();

//       //print('✅ [Firebase] Service Firebase Messaging initialisé');
//     } catch (e) {
//       //print('❌ [Firebase] Erreur lors de l\'initialisation: $e');
//     }
//   }

//   // Demander les permissions de notification
//   static Future<void> _requestPermission() async {
//     //print('🔥 [Firebase] Demande des permissions...');

//     try {
//       NotificationSettings settings =
//           await _firebaseMessaging.requestPermission(
//         alert: true,
//         announcement: false,
//         badge: true,
//         carPlay: false,
//         criticalAlert: false,
//         provisional: false,
//         sound: true,
//       );

//       if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//         //print('✅ [Firebase] Permissions accordées');
//       } else if (settings.authorizationStatus ==
//           AuthorizationStatus.provisional) {
//         //print('⚠️ [Firebase] Permissions provisoires accordées');
//       } else {
//         //print('❌ [Firebase] Permissions refusées');
//       }
//     } catch (e) {
//       //print('❌ [Firebase] Erreur demande permissions: $e');
//     }
//   }

//   // Configuration des notifications locales
//   static Future<void> _setupLocalNotifications() async {
//     //print('🔥 [Firebase] Configuration des notifications locales...');

//     try {
//       const AndroidInitializationSettings initializationSettingsAndroid =
//           AndroidInitializationSettings('@mipmap/ic_launcher');

//       final DarwinInitializationSettings initializationSettingsIOS =
//           DarwinInitializationSettings(
//         requestAlertPermission: true,
//         requestBadgePermission: true,
//         requestSoundPermission: true,
//       );

//       final InitializationSettings initializationSettings =
//           InitializationSettings(
//         android: initializationSettingsAndroid,
//         iOS: initializationSettingsIOS,
//       );

//       await _localNotifications.initialize(
//         initializationSettings,
//         onDidReceiveNotificationResponse: (response) {
//           _handleNotificationTap(response.payload);
//         },
//       );

//       // Créer le canal de notification Android
//       const AndroidNotificationChannel channel = AndroidNotificationChannel(
//         'firebase_channel',
//         'Notifications Firebase',
//         description: 'Canal pour les notifications Firebase',
//         importance: Importance.high,
//       );

//       await _localNotifications
//           .resolvePlatformSpecificImplementation<
//               AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);

//       //print('✅ [Firebase] Notifications locales configurées');
//     } catch (e) {
//       //print('❌ [Firebase] Erreur configuration notifications locales: $e');
//     }
//   }

//   // Configuration des handlers Firebase
//   static Future<void> _setupFirebaseHandlers() async {
//     //print('🔥 [Firebase] Configuration des handlers...');

//     try {
//       // Handler pour les messages en arrière-plan
//       FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

//       // Handler pour les messages quand l'app est en premier plan
//       FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//         //print('🔥 [Foreground] Message reçu: ${message.notification?.title}');
//         _showLocalNotification(message);
//       });

//       // Handler pour les clics sur notifications (app en arrière-plan)
//       FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//         //print('🔥 [Background] Notification cliquée: ${message.data}');
//         _handleMessageClick(message);
//       });

//       // Vérifier si l'app a été lancée par une notification
//       RemoteMessage? initialMessage =
//           await _firebaseMessaging.getInitialMessage();
//       if (initialMessage != null) {
//         print(
//             '🔥 [Cold Start] App lancée par notification: ${initialMessage.data}');
//         _handleMessageClick(initialMessage);
//       }

//       //print('✅ [Firebase] Handlers configurés');
//     } catch (e) {
//       //print('❌ [Firebase] Erreur configuration handlers: $e');
//     }
//   }

//   // Obtenir et envoyer le token FCM au serveur
//   static Future<void> _getAndSendToken() async {
//     try {
//       String? token = await _firebaseMessaging.getToken();
//       if (token != null) {
//         //print('🔥 [Firebase] Token FCM: ${token.substring(0, 50)}...');
//         await _sendTokenToServer(token);

//         // Sauvegarder localement pour usage futur
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('fcm_token', token);
//       }

//       // Écouter les rafraîchissements de token
//       _firebaseMessaging.onTokenRefresh.listen((String token) {
//         //print('🔥 [Firebase] Token rafraîchi');
//         _sendTokenToServer(token);
//       });
//     } catch (e) {
//       //print('❌ [Firebase] Erreur récupération token: $e');
//     }
//   }

//   // Envoyer le token FCM à votre serveur
//   static Future<void> _sendTokenToServer(String fcmToken) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final userToken = prefs.getString('user_token');

//       if (userToken == null) {
//         print(
//             '⚠️ [Firebase] Token utilisateur non trouvé, impossible d\'envoyer le token FCM');
//         return;
//       }

//       //print('🔥 [Firebase] Envoi du token FCM au serveur...');

//       final response = await http.post(
//         Uri.parse(
//             'https://api.live.wortis.cg/firebase/api/user/fcm-token'), // Vous devrez créer cet endpoint
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': userToken,
//         },
//         body: jsonEncode({
//           'fcm_token': fcmToken,
//           'platform': Platform.isIOS ? 'ios' : 'android',
//           'app_version': '1.0.0', // Vous pouvez obtenir cela dynamiquement
//         }),
//       );

//       if (response.statusCode == 200) {
//         //print('✅ [Firebase] Token FCM envoyé au serveur avec succès');
//       } else {
//         //print('❌ [Firebase] Erreur envoi token: ${response.statusCode}');
//       }
//     } catch (e) {
//       //print('❌ [Firebase] Erreur envoi token au serveur: $e');
//     }
//   }

//   // Afficher une notification locale quand l'app est en premier plan
//   static Future<void> _showLocalNotification(RemoteMessage message) async {
//     try {
//       const AndroidNotificationDetails androidPlatformChannelSpecifics =
//           AndroidNotificationDetails(
//         'firebase_channel',
//         'Notifications Firebase',
//         channelDescription: 'Canal pour les notifications Firebase',
//         importance: Importance.max,
//         priority: Priority.high,
//         icon: 'wpay_icon',
//         color: Color(0xFF006699),
//       );

//       const DarwinNotificationDetails iOSPlatformChannelSpecifics =
//           DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: true,
//       );

//       const NotificationDetails platformChannelSpecifics = NotificationDetails(
//         android: androidPlatformChannelSpecifics,
//         iOS: iOSPlatformChannelSpecifics,
//       );

//       await _localNotifications.show(
//         message.hashCode,
//         message.notification?.title ?? 'Notification',
//         message.notification?.body ?? 'Vous avez reçu une notification',
//         platformChannelSpecifics,
//         payload: jsonEncode(message.data),
//       );
//     } catch (e) {
//       //print('❌ [Firebase] Erreur affichage notification locale: $e');
//     }
//   }

//   // Gérer les clics sur notifications
//   static void _handleMessageClick(RemoteMessage message) {
//     //print('🔥 [Firebase] Gestion du clic sur notification');

//     // Extraire les données de la notification
//     final data = message.data;
//     _handleNotificationTap(jsonEncode(data));
//   }

//   // Gérer les taps sur notifications (local et Firebase)

//   // Gérer les taps sur notifications (local et Firebase)

// // Gérer les taps sur notifications (local et Firebase)
//   static void _handleNotificationTap(String? payload) {
//     if (payload == null) return;

//     try {
//       final data = jsonDecode(payload);
//       final action = data['action'] ?? 'open_notifications';

//       //print('🔥 [Firebase] Action notification: $action');

//       // NOUVELLE LOGIQUE: Passer toutes les données au service
//       DynamicNavigationService.handleDynamicNavigation(
//         action,
//         additionalData: Map<String, dynamic>.from(data)..remove('action'),
//       );
//     } catch (e) {
//       //print('❌ [Firebase] Erreur traitement tap notification: $e');
//       // Fallback direct vers notifications
//       DynamicNavigationService.handleDynamicNavigation('open_notifications');
//     }
//   }

//   static BuildContext? _getCurrentContext() {
//     // Vous devez adapter cette méthode selon votre architecture
//     // Option 1: Si vous avez un navigatorKey global
//     return navigatorKey.currentContext;

//     // Option 2: Si vous passez le contexte depuis Firebase service
//     // return _context;
//   }

//   // Méthodes de navigation (à adapter selon votre système de navigation)
//   static void _navigateToNotifications() {
//     //print('🔥 [Firebase] Navigation vers les notifications fsfsf');
//     //print('📱 [DynamicNav] Navigation vers Notifications zfsdfs');
//     final context = _getCurrentContext();
//     if (context != null) {
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (context) => const NotificationPage()),
//         (route) => false,
//       );
//     }
//   }

//   static void _navigateToWallet() {
//     //print('🔥 [Firebase] Navigation vers le portefeuille');
//     // Implémentez votre logique de navigation ici
//   }

//   static void _navigateToTransaction(String? transactionId) {
//     //print('🔥 [Firebase] Navigation vers transaction: $transactionId');
//     // Implémentez votre logique de navigation ici
//   }

//   // Méthodes utilitaires

//   // Obtenir le token FCM actuel
//   static Future<String?> getCurrentToken() async {
//     try {
//       return await _firebaseMessaging.getToken();
//     } catch (e) {
//       //print('❌ [Firebase] Erreur récupération token: $e');
//       return null;
//     }
//   }

//   // S'abonner à un topic
//   static Future<void> subscribeToTopic(String topic) async {
//     try {
//       await _firebaseMessaging.subscribeToTopic(topic);
//       //print('✅ [Firebase] Abonné au topic: $topic');
//     } catch (e) {
//       //print('❌ [Firebase] Erreur abonnement topic: $e');
//     }
//   }

//   // Se désabonner d'un topic
//   static Future<void> unsubscribeFromTopic(String topic) async {
//     try {
//       await _firebaseMessaging.unsubscribeFromTopic(topic);
//       //print('✅ [Firebase] Désabonné du topic: $topic');
//     } catch (e) {
//       //print('❌ [Firebase] Erreur désabonnement topic: $e');
//     }
//   }

//   // Envoyer une notification de test via le serveur
//   static Future<bool> sendTestNotification() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final userToken = prefs.getString('user_token');

//       if (userToken == null) {
//         //print('⚠️ [Firebase] Token utilisateur non trouvé');
//         return false;
//       }

//       final response = await http.post(
//         Uri.parse('https://api.live.wortis.cg/firebase/api/notifications/test'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': userToken,
//         },
//         body: jsonEncode({
//           'title': 'Test Firebase',
//           'body': 'Votre intégration Firebase fonctionne !',
//           'action': 'open_notifications',
//         }),
//       );

//       if (response.statusCode == 200) {
//         //print('✅ [Firebase] Notification de test envoyée');
//         return true;
//       } else {
//         print(
//             '❌ [Firebase] Erreur envoi notification test: ${response.statusCode}');
//         return false;
//       }
//     } catch (e) {
//       //print('❌ [Firebase] Erreur envoi notification test: $e');
//       return false;
//     }
//   }
// }
