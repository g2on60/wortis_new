
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart';
import 'package:wortis/pages/notifications.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:wortis/pages/homepage_dias.dart';
import 'package:wortis/pages/transaction.dart';
import 'package:wortis/pages/moncompte.dart';
import 'package:wortis/class/webviews.dart';
import 'package:wortis/class/form_service.dart';

class DynamicNavigationService {
  static const String baseUrl = 'https://api.live.wortis.cg';
  
  // Méthode principale pour gérer la navigation dynamique
  static Future<void> handleDynamicNavigation(String action, {Map<String, dynamic>? additionalData}) async {
    try {
      print('🎯 [DynamicNav] Traitement action: $action');
      
      // NOUVELLE LOGIQUE: Appel API uniquement si action = 'call_to_api'
      if (action == 'call_to_api') {
        print('📡 [DynamicNav] Appel API requis');
        final navigationInfo = await _getNavigationInfoFromAPI(additionalData);
        
        if (navigationInfo != null) {
          await _navigateToPage(navigationInfo);
        } else {
          // Fallback vers notifications si l'API ne répond pas
          _navigateToNotifications();
        }
      } else {
        // Navigation directe sans API
        print('🚀 [DynamicNav] Navigation directe sans API');
        await _handleDirectNavigation(action, additionalData);
      }
      
    } catch (e) {
      print('❌ [DynamicNav] Erreur: $e');
      // Fallback vers notifications en cas d'erreur
      _navigateToNotifications();
    }
  }
  
  // Gestion de navigation directe sans API
  static Future<void> _handleDirectNavigation(String action, Map<String, dynamic>? data) async {
    switch (action) {
      case 'open_notifications':
        _navigateToNotifications();
        break;
        
      case 'open_home':
        _navigateToHomePage();
        break;
        
      case 'open_transaction_history':
        _navigateToTransactionHistory();
        break;
        
      case 'open_transaction':
        final transactionId = data?['transaction_id'];
        _navigateToSpecificTransaction(transactionId);
        break;
        
      case 'open_account':
        _navigateToAccount();
        break;
        
      case 'open_wallet':
        _navigateToAccount(); // Même page que compte pour le moment
        break;
        
      case 'open_service':
        final serviceName = data?['service_name'] ?? 'Louer un Véhicule';
        await _navigateToService(serviceName);
        break;
        
      case 'open_webview':
        final url = data?['url'];
        final title = data?['title'] ?? 'Page Web';
        _navigateToWebView(url, title);
        break;
        
      case 'open_promotion':
        final promoUrl = data?['promo_url'] ?? 'https://wortis.cg/promotions';
        final promoTitle = data?['promo_title'] ?? 'Promotions';
        _navigateToWebView(promoUrl, promoTitle);
        break;
        
      case 'open_news':
        _navigateToWebView('https://wortis.cg/actualites', 'Actualités');
        break;
        
      case 'open_payment':
        final serviceName = data?['service_name'] ?? 'Payment';
        await _navigateToService(serviceName);
        break;
        
      case 'open_settings':
        _navigateToAccount(); // Redirection vers compte/paramètres
        break;
        
      default:
        print('⚠️ [DynamicNav] Action non reconnue: $action, redirection vers notifications');
        _navigateToNotifications();
    }
  }
  
  // Appel API pour obtenir les informations de navigation (uniquement pour call_to_api)
  static Future<Map<String, dynamic>?> _getNavigationInfoFromAPI(Map<String, dynamic>? additionalData) async {
    try {
      final requestBody = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        ...?additionalData, // Toutes les données supplémentaires
      };
      
      print('📡 [DynamicNav] Appel API: $baseUrl/notification_navigation');
      print('📦 [DynamicNav] Payload: ${json.encode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/notification_navigation'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));
      
      print('📊 [DynamicNav] Status: ${response.statusCode}');
      print('📄 [DynamicNav] Response: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print('⚠️ [DynamicNav] API error: ${response.statusCode}');
        return null;
      }
      
    } catch (e) {
      print('❌ [DynamicNav] Erreur API: $e');
      return null;
    }
  }
  
  // Navigation vers la page basée sur la réponse API (pour call_to_api uniquement)
  static Future<void> _navigateToPage(Map<String, dynamic> navigationInfo) async {
    try {
      final pageType = navigationInfo['page_type'];
      final pageData = navigationInfo['data'] ?? {};
      
      print('🚀 [DynamicNav] Navigation API vers: $pageType');
      
      switch (pageType) {
        case 'notifications':
          _navigateToNotifications();
          break;
          
        case 'homepage':
          _navigateToHomePage();
          break;
          
        case 'transaction_history':
          _navigateToTransactionHistory();
          break;
          
        case 'specific_transaction':
          final transactionId = pageData['transaction_id'];
          _navigateToSpecificTransaction(transactionId);
          break;
          
        case 'account':
          _navigateToAccount();
          break;
          
        case 'service':
          final serviceName = pageData['service_name'] ?? 'Louer un Véhicule';
          await _navigateToService(serviceName);
          break;
          
        case 'webview':
          final url = pageData['url'];
          final title = pageData['title'] ?? 'Page Web';
          _navigateToWebView(url, title);
          break;
          
        case 'external_url':
          final url = pageData['url'];
          await _openExternalUrl(url);
          break;
          
        default:
          print('⚠️ [DynamicNav] Type de page non reconnu: $pageType');
          _navigateToNotifications();
      }
      
    } catch (e) {
      print('❌ [DynamicNav] Erreur navigation: $e');
      _navigateToNotifications();
    }
  }
  
  // Méthodes de navigation spécifiques (inchangées)
  static void _navigateToNotifications() {
    print('📱 [DynamicNav] Navigation vers Notifications Dynamic page');
    final context = _getCurrentContext();
    if (context != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const NotificationPage()),
        (route) => false,
      );
    }
  }
  
  static void _navigateToHomePage() {
    print('🏠 [DynamicNav] Navigation vers HomePage');
    final context = _getCurrentContext();
    if (context != null) {
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
          MaterialPageRoute(builder: (context) => HomePage(routeObserver: routeObserver)),
          (route) => false,
        );
      }
    }
  }
  
  static void _navigateToTransactionHistory() {
    print('📊 [DynamicNav] Navigation vers Historique des transactions');
    final context = _getCurrentContext();
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TransactionHistoryPage(sourcePageType: 'notification')
        ),
      );
    }
  }
  
  static void _navigateToSpecificTransaction(String? transactionId) {
    print('🧾 [DynamicNav] Navigation vers transaction: $transactionId');
    final context = _getCurrentContext();
    if (context != null && transactionId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionHistoryPage(
            sourcePageType: 'notification',
          )
        ),
      );
    } else {
      _navigateToTransactionHistory();
    }
  }
  
  static void _navigateToAccount() {
    print('👤 [DynamicNav] Navigation vers Mon Compte');
    final context = _getCurrentContext();
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MonComptePage()),
      );
    }
  }
  
  static Future<void> _navigateToService(String? serviceName) async {
    print('⚙️ [DynamicNav] Navigation vers service: $serviceName');
    final context = _getCurrentContext();
    if (context != null && serviceName != null) {
      await SessionManager.checkSessionAndNavigate(
        context: context,
        authenticatedRoute: MaterialPageRoute(
          builder: (context) => FormService(serviceName: serviceName)
        ),
        unauthenticatedRoute: const AuthentificationPage(),
      );
    } else {
      _navigateToNotifications();
    }
  }
  
  static void _navigateToWebView(String? url, String title) {
    print('🌐 [DynamicNav] Navigation vers WebView: $url');
    final context = _getCurrentContext();
    if (context != null && url != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServiceWebView(
            url: url,
          )
        ),
      );
    } else {
      _navigateToNotifications();
    }
  }
  
  static Future<void> _openExternalUrl(String? url) async {
    print('🔗 [DynamicNav] Ouverture URL externe: $url');
    if (url != null) {
      // Naviguer vers une WebView interne pour l'URL externe
      _navigateToWebView(url, 'Page externe');
    } else {
      _navigateToNotifications();
    }
  }
  
  // Méthode utilitaire pour obtenir le contexte actuel
  static BuildContext? _getCurrentContext() {
    // Adaptez selon votre architecture
    return navigatorKey.currentContext;
  }
}
