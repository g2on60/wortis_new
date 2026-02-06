# Intégration Paiement Wortis - Réservations

## 🔄 Flux Complet avec votre API Wortis

```
1. Utilisateur remplit le formulaire de réservation
   └─> Calcul du montant (prestation + variante)

2. POST /api/bookings/create-reservation
   └─> Créer réservation avec status: pending_payment
   └─> Retourne: booking_id

3. Initier paiement Mobile Money (votre système existant)
   └─> Appel à votre API de paiement MoMo/CB
   └─> Retourne: clientTransID ou uniqueID

4. Frontend: Polling vers api.live.wortis.cg/check_transac_box
   └─> Paramètres: {transac: clientTransID, mode: "MoMo"}
   └─> Vérifie le status toutes les 2-3 secondes

5. Quand status = "SUCCESSFUL" ou "200"
   └─> POST /api/bookings/confirm-payment
   └─> Confirme la réservation avec le booking_id

6. Réservation confirmée ✅
   └─> Status: confirmed
   └─> Payment_status: successful
```

---

## 💻 Implémentation Flutter

### 1. Création de la réservation

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> createReservation({
  required String date,
  required String timeSlot,
  required String prestation,
  String? variant,
  required String nom,
  required String telephone,
  required String adresse,
  String? commentaire,
  required String serviceName,
  required double amount,
}) async {
  final response = await http.post(
    Uri.parse('https://api.live.wortis.cg/api/bookings/create-reservation'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'date': date,
      'timeSlot': timeSlot,
      'prestation': prestation,
      'variant': variant,
      'nom': nom,
      'telephone': telephone,
      'adresse': adresse,
      'commentaire': commentaire,
      'service_name': serviceName,
      'amount': amount,
      'payment_method': 'MTN_MONEY', // ou 'AIRTEL_MONEY'
    }),
  );

  if (response.statusCode == 201) {
    return json.decode(response.body);
  } else {
    throw Exception('Erreur création réservation');
  }
}
```

### 2. Initier le paiement avec votre système existant

```dart
Future<String> initiatePayment({
  required String bookingId,
  required double amount,
  required String telephone,
}) async {
  // Utiliser votre API de paiement MoMo existante
  // Cette partie utilise votre système actuel

  final response = await http.post(
    Uri.parse('https://api.live.wortis.cg/initiate-payment'), // Votre endpoint
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'amount': amount,
      'msisdn': telephone,
      'reference': bookingId, // Lier avec la réservation
      'mode': 'MoMo', // ou 'CB'
    }),
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final clientTransID = data['clientTransID']; // ou uniqueID pour CB
    return clientTransID;
  } else {
    throw Exception('Erreur initialisation paiement');
  }
}
```

### 3. Vérification du paiement (Polling)

```dart
import 'dart:async';

Future<void> checkAndConfirmPayment({
  required BuildContext context,
  required String bookingId,
  required String clientTransID,
  required String mode, // "MoMo" ou "CB"
}) async {
  bool isCompleted = false;
  Timer? timer;

  // Afficher le dialogue de chargement
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('En attente de paiement...'),
          SizedBox(height: 10),
          Text(
            'Veuillez confirmer le paiement sur votre téléphone',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  // Fonction de vérification
  Future<void> checkTransaction() async {
    if (isCompleted) return;

    try {
      final response = await http.post(
        Uri.parse('https://api.live.wortis.cg/check_transac_box'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'transac': clientTransID,
          'mode': mode,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];

        print('📊 Status paiement: $status');

        // Vérifier si le paiement est terminé
        if (status == "SUCCESSFUL" || status == "200") {
          isCompleted = true;
          timer?.cancel();

          // Confirmer la réservation
          await confirmReservation(
            bookingId: bookingId,
            paymentReference: clientTransID,
            paymentStatus: 'SUCCESSFUL',
            transactionId: clientTransID,
          );

          // Fermer le dialogue de chargement
          if (context.mounted) {
            Navigator.of(context).pop();
            _showSuccessDialog(context);
          }
        } else if (status == "FAILED" || status == "REJECTED") {
          isCompleted = true;
          timer?.cancel();

          // Marquer la réservation comme échouée
          await confirmReservation(
            bookingId: bookingId,
            paymentReference: clientTransID,
            paymentStatus: 'FAILED',
            transactionId: clientTransID,
          );

          // Fermer le dialogue et afficher l'erreur
          if (context.mounted) {
            Navigator.of(context).pop();
            _showErrorDialog(context, 'Paiement échoué');
          }
        }
        // Si status = "PENDING", on continue de vérifier
      }
    } catch (e) {
      print('❌ Erreur vérification: $e');
    }
  }

  // Démarrer le polling toutes les 3 secondes
  timer = Timer.periodic(Duration(seconds: 3), (_) {
    if (!isCompleted) {
      checkTransaction();
    }
  });

  // Timeout après 5 minutes
  Future.delayed(Duration(minutes: 5), () {
    if (!isCompleted) {
      timer?.cancel();
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorDialog(context, 'Délai d\'attente dépassé');
      }
    }
  });
}
```

### 4. Confirmation de la réservation

```dart
Future<void> confirmReservation({
  required String bookingId,
  required String paymentReference,
  required String paymentStatus,
  required String transactionId,
}) async {
  final response = await http.post(
    Uri.parse('https://api.live.wortis.cg/api/bookings/confirm-payment'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'booking_id': bookingId,
      'payment_reference': paymentReference,
      'payment_status': paymentStatus,
      'transaction_id': transactionId,
    }),
  );

  if (response.statusCode == 200) {
    print('✅ Réservation confirmée');
  } else {
    print('❌ Erreur confirmation réservation');
    throw Exception('Erreur confirmation');
  }
}
```

### 5. Dialogues de résultat

```dart
void _showSuccessDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 30),
          SizedBox(width: 10),
          Text('Réservation confirmée'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✅ Paiement effectué avec succès'),
          SizedBox(height: 10),
          Text('Votre réservation est confirmée.'),
          SizedBox(height: 10),
          Text(
            'Vous recevrez une confirmation par SMS.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop(); // Retour à l'écran principal
          },
          child: Text('OK'),
        ),
      ],
    ),
  );
}

void _showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error, color: Colors.red, size: 30),
          SizedBox(width: 10),
          Text('Erreur'),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

---

## 🎯 Intégration Complète dans ReservationService

### Modifier la fonction de soumission finale

```dart
Future<void> _submitReservation() async {
  try {
    // 1. Calculer le montant
    final amount = _calculateAmount();

    // 2. Créer la réservation
    final reservationData = await createReservation(
      date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
      timeSlot: _selectedTimeSlot!,
      prestation: formValues['type_prestation'],
      variant: formValues['variant'],
      nom: formValues['nom'],
      telephone: formValues['telephone'],
      adresse: formValues['adresse'],
      commentaire: formValues['commentaire'],
      serviceName: serviceData['name'],
      amount: amount,
    );

    final bookingId = reservationData['booking_id'];

    // 3. Initier le paiement
    final clientTransID = await initiatePayment(
      bookingId: bookingId,
      amount: amount,
      telephone: formValues['telephone'],
    );

    // 4. Vérifier et confirmer le paiement
    await checkAndConfirmPayment(
      context: context,
      bookingId: bookingId,
      clientTransID: clientTransID,
      mode: 'MoMo', // ou déterminer selon le choix utilisateur
    );

  } catch (e) {
    print('❌ Erreur: $e');
    _showErrorDialog(context, 'Une erreur est survenue. Veuillez réessayer.');
  }
}

double _calculateAmount() {
  double basePrice = 0;

  // Prix de base de la prestation
  if (_currentPrestationData != null) {
    basePrice = (_currentPrestationData['price'] ?? 0).toDouble();
  }

  // Prix de la variante (remplace le prix de base)
  if (_selectedVariantId != null && _currentPrestationData?['variants'] != null) {
    final variant = (_currentPrestationData['variants'] as List).firstWhere(
      (v) => v['id'] == _selectedVariantId,
      orElse: () => null,
    );
    if (variant != null && variant['price'] != null) {
      basePrice = (variant['price']).toDouble();
    }
  }

  return basePrice;
}
```

---

## 📊 Structure de Données

### Votre API check_transac_box retourne :

**Pour MoMo :**
```json
{
    "status": "SUCCESSFUL",
    "montant": 5000,
    "msisdn": "+242065551234",
    "date": "2024-02-06T10:00:00"
}
```

**Pour CB :**
```json
{
    "status": "SUCCESSFUL",
    "montant": 5000,
    "tel": "+242065551234",
    "date": "2024-02-06T10:00:00"
}
```

### Status possibles :
- `PENDING` : En attente
- `SUCCESSFUL` ou `200` : Paiement réussi ✅
- `FAILED` ou `REJECTED` : Paiement échoué ❌

---

## 🔐 Sécurité

### Validation côté backend

```python
@catalog_apk_bp.route('/api/bookings/confirm-payment', methods=['POST'])
def confirm_payment():
    data = request.get_json()

    # Vérifier que le paiement existe vraiment
    # Appeler check_transac_box côté backend pour vérifier
    transac_check = requests.post(
        'https://api.live.wortis.cg/check_transac_box',
        json={
            'transac': data['payment_reference'],
            'mode': 'MoMo'
        }
    )

    if transac_check.status_code == 200:
        transac_data = transac_check.json()

        # Vérifier que le montant correspond
        booking = db['bookings'].find_one({'_id': ObjectId(data['booking_id'])})

        if booking and transac_data['montant'] == booking['amount']:
            # OK, confirmer la réservation
            # ... code de confirmation
            pass
        else:
            return jsonify({'success': False, 'error': 'Montant incorrect'}), 400
```

---

## 🧪 Tests

### Test du flux complet

```dart
// Test dans votre environnement de développement
void testBookingWithPayment() async {
  // 1. Créer réservation
  final reservation = await createReservation(
    date: '2024-02-15',
    timeSlot: '14:00-15:00',
    prestation: 'coupe_homme',
    nom: 'Test User',
    telephone: '+242065551234',
    adresse: '123 Test Street',
    serviceName: 'Coiffure',
    amount: 5000,
  );

  print('✅ Réservation créée: ${reservation['booking_id']}');

  // 2. Initier paiement
  final clientTransID = await initiatePayment(
    bookingId: reservation['booking_id'],
    amount: 5000,
    telephone: '+242065551234',
  );

  print('✅ Paiement initié: $clientTransID');

  // 3. Simuler la vérification
  // Vous pouvez utiliser votre téléphone de test pour valider
}
```

---

## 📝 Checklist d'Intégration

- [ ] Backend: Routes de réservation déployées
- [ ] Backend: Index MongoDB créés (run setup_mongodb_indexes.py)
- [ ] Frontend: Fonction createReservation() implémentée
- [ ] Frontend: Fonction initiatePayment() implémentée
- [ ] Frontend: Fonction checkAndConfirmPayment() implémentée
- [ ] Frontend: Dialogues de succès/erreur créés
- [ ] Test: Flux complet testé en environnement de développement
- [ ] Test: Cas d'erreur testés (paiement échoué, timeout, etc.)
- [ ] Production: Configuration des URLs correctes
- [ ] Production: Logs et monitoring activés

---

## 💡 Recommandations

1. **Timeout** : Limiter l'attente du paiement à 5 minutes maximum
2. **Retry** : Permettre à l'utilisateur de réessayer en cas d'échec
3. **Feedback** : Afficher clairement l'état du paiement à l'utilisateur
4. **Notifications** : Envoyer un SMS de confirmation après paiement réussi
5. **Historique** : Permettre à l'utilisateur de voir ses réservations via GET /api/bookings/user/<telephone>

---

**Version :** 1.0
**Date :** 2026-02-06
**Auteur :** Claude Sonnet 4.5
