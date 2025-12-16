// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static Future<void> requestModernPermissions(BuildContext? context) async {
    if (Platform.isIOS) {
      await _requestIOSNotificationPermission(context);
    } else {
      await _handleNotificationPermission(context);
    }
  }

  static Future<void> _requestIOSNotificationPermission(BuildContext? context) async {
    final status = await Permission.notification.status;
    
    if (status.isGranted) return;
    
    if (status.isPermanentlyDenied) {
      if (context != null) {
        await _showIOSSettingsDialog(context);
      }
      return;
    }

    if (context != null) {
      //await _showIOSPrivacyDialog(context);
    } else {
      await Permission.notification.request();
    }
  }

  static Future<void> _handleNotificationPermission(BuildContext? context) async {
    final status = await Permission.notification.status;

    if (status.isGranted) return;

    if (status.isPermanentlyDenied) {
      if (context != null) {
        await _showSettingsDialog(context);
      }
      return;
    }

    if (context != null) {
      await _showPrivacyDialog(context);
    } else {
      await Permission.notification.request();
    }
  }

  // ignore: unused_element
  static Future<void> _showIOSPrivacyDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 35,
                color: Colors.black87,
              ),
              SizedBox(height: 8),
              Text(
                'Notifications',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Wortis souhaite vous envoyer des notifications concernant vos transactions et paiements.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Vous pourrez modifier ce choix dans les Réglages.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text(
                'Refuser',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text(
                'Autoriser',
                style: TextStyle(color: Colors.blue),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Permission.notification.request();
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceEvenly,
        );
      },
    );
  }

  static Future<void> _showIOSSettingsDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 35,
                color: Colors.black87,
              ),
              SizedBox(height: 8),
              Text(
                'Notifications désactivées',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pour recevoir des notifications de Wortis, veuillez les activer dans les Réglages.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text(
                'Plus tard',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text(
                'Ouvrir les Réglages',
                style: TextStyle(color: Colors.blue),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceEvenly,
        );
      },
    );
  }

  static Future<void> _showPrivacyDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 40,
                color: Color(0xFF006699),
              ),
              SizedBox(height: 10),
              Text(
                'Votre expérience avec Wortis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006699),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pour vous offrir la meilleure expérience possible, Wortis a besoin de :',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Icon(Icons.notifications, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Vous envoyer des notifications pour vos transactions et mises à jour importantes',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'Vos données personnelles sont traitées de manière sécurisée conformément à notre politique de confidentialité.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Plus tard'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006699),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Autoriser'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Permission.notification.request();
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        );
      },
    );
  }

  static Future<void> _showSettingsDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 40,
                color: Color(0xFF006699),
              ),
              SizedBox(height: 10),
              Text(
                'Activation des notifications',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006699),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pour recevoir des notifications importantes concernant vos transactions, veuillez les activer dans les paramètres de votre appareil.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Vous pouvez modifier ce choix à tout moment dans les paramètres.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Plus tard'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006699),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Ouvrir les paramètres'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        );
      },
    );
  }
}