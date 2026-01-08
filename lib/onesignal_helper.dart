/// Fichier d'aide pour gérer OneSignal
///
/// Ce fichier contient des fonctions utilitaires pour gérer les notifications
/// OneSignal dans votre application.
library;

import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:wortis/main.dart' show forceOneSignalSubscription;

/// Classe helper pour OneSignal
class OneSignalHelper {
  /// Forcer la souscription aux notifications push
  ///
  /// Cette fonction peut être appelée à tout moment pour forcer
  /// l'abonnement de l'utilisateur aux notifications push.
  ///
  /// Exemple d'utilisation dans un bouton:
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () async {
  ///     final success = await OneSignalHelper.forceSubscription();
  ///     if (success) {
  ///       ScaffoldMessenger.of(context).showSnackBar(
  ///         SnackBar(content: Text('Abonné aux notifications ✅')),
  ///       );
  ///     }
  ///   },
  ///   child: Text('Activer les notifications'),
  /// )
  /// ```
  static Future<bool> forceSubscription() async {
    return await forceOneSignalSubscription();
  }

  /// Vérifier l'état d'abonnement actuel
  static bool isSubscribed() {
    return OneSignal.User.pushSubscription.optedIn ?? false;
  }

  /// Obtenir le Subscription ID (Player ID)
  static String? getSubscriptionId() {
    return OneSignal.User.pushSubscription.id;
  }

  /// Obtenir le Push Token
  static String? getPushToken() {
    return OneSignal.User.pushSubscription.token;
  }

  /// Désabonner l'utilisateur des notifications
  static void unsubscribe() {
    OneSignal.User.pushSubscription.optOut();
  }

  /// Afficher les informations actuelles de OneSignal
  static void printInfo() {
    // Logs supprimés
  }
}
