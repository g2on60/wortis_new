# Intégration Paiement Réservation - Guide Complet

## 🔄 Flux Complet avec Paiement

```
1. Frontend: Créer réservation
   POST /catalogue/api/bookings/create-reservation
   └─> Backend: Créer réservation (status: pending_payment)

2. Backend: Initier paiement automatiquement
   POST https://wortispay.com/api/paiement/json
   └─> Récupère transID

3. Backend: Enregistrer transID dans réservation
   └─> payment_reference = transID
   └─> Retourne transID au frontend

4. Frontend: Polling du paiement
   POST https://api.live.wortis.cg/check_transac_box
   Body: {transac: transID, mode: "MoMo"}
   └─> Vérifie status toutes les 3 secondes

5. Quand status = "SUCCESSFUL"
   POST /catalogue/api/bookings/confirm-payment
   Body: {booking_id, payment_reference: transID, payment_status: "SUCCESSFUL"}
   └─> Met à jour la réservation: status = "confirmed"

6. Réservation confirmée ✅
```

---

## 🔧 Backend: Remplacer la Route

Dans votre fichier Flask, **remplacez** la route `create-reservation` par le nouveau code dans [create_reservation_with_payment.py](create_reservation_with_payment.py).

### Points Clés de la Nouvelle Route

1. **Validation complète** des données de réservation
2. **Vérification du créneau** (pas de double réservation)
3. **Appel automatique** à wortispay.com pour initier le paiement
4. **Récupération du transID** pour le checking
5. **Enregistrement** de la réservation avec le transID

### Configuration Requise

⚠️ **Important** : Le service dans MongoDB doit avoir un champ `numc` :

```json
{
  "_id": ObjectId("..."),
  "name": "Coiffure avec Créneaux Occupés",
  "Type_Service": "ReservationService",
  "numc": "242065551234",  // ⬅️ REQUIS pour le paiement
  ...
}
```

---

## 💻 Frontend: Intégration Flutter

### Étape 1: Créer la Réservation (inchangé)

Le frontend n'a pas besoin de changement dans l'appel initial :

```dart
final response = await http.post(
  Uri.parse('https://api.live.wortis.cg/catalogue/api/bookings/create-reservation'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({
    'date': '2024-02-15',
    'timeSlot': '14:00 - 15:00',
    'prestation': 'coupe_homme',
    'variant': 'courte',
    'nom': 'Jean Dupont',
    'telephone': '242065551234',
    'adresse': '123 Rue, Brazzaville',
    'commentaire': 'Préfère le matin',
    'service_name': 'Coiffure',
    'service_id': '65f8a2b3...',
    'amount': 5000,
    'payment_method': 'MTN_MONEY',
  }),
);
```

### Étape 2: Récupérer le transID

```dart
if (response.statusCode == 201) {
  final data = json.decode(response.body);

  final bookingId = data['booking_id'];
  final transID = data['transID'];  // Le transID pour le checking

  print('📋 Réservation créée: $bookingId');
  print('💳 TransID paiement: $transID');

  // Lancer le checking du paiement
  await checkAndConfirmPayment(
    context: context,
    bookingId: bookingId,
    clientTransID: transID,
    mode: 'MoMo',
  );
}
```

### Étape 3: Checking du Paiement (utilise votre fonction existante)

La fonction `checkAndConfirmPayment` de [INTEGRATION_PAIEMENT_WORTIS.md](INTEGRATION_PAIEMENT_WORTIS.md) fonctionne directement :

```dart
Future<void> checkAndConfirmPayment({
  required BuildContext context,
  required String bookingId,
  required String clientTransID,
  required String mode,
}) async {
  bool isCompleted = false;
  Timer? timer;

  // Afficher dialogue d'attente
  showDialog(...);

  Future<void> checkTransaction() async {
    if (isCompleted) return;

    try {
      // Appel à votre API check_transac_box
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

        if (status == "SUCCESSFUL" || status == "200") {
          isCompleted = true;
          timer?.cancel();

          // Confirmer la réservation
          await confirmReservation(
            bookingId: bookingId,
            paymentReference: clientTransID,
            paymentStatus: 'SUCCESSFUL',
          );

          // Afficher succès
          if (context.mounted) {
            Navigator.of(context).pop();
            _showSuccessDialog(context);
          }
        } else if (status == "FAILED") {
          isCompleted = true;
          timer?.cancel();

          // Marquer comme échoué
          await confirmReservation(
            bookingId: bookingId,
            paymentReference: clientTransID,
            paymentStatus: 'FAILED',
          );

          // Afficher erreur
          if (context.mounted) {
            Navigator.of(context).pop();
            _showErrorDialog(context, 'Paiement échoué');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur vérification: $e');
    }
  }

  // Polling toutes les 3 secondes
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

### Étape 4: Confirmer la Réservation

```dart
Future<void> confirmReservation({
  required String bookingId,
  required String paymentReference,
  required String paymentStatus,
}) async {
  final response = await http.post(
    Uri.parse('https://api.live.wortis.cg/catalogue/api/bookings/confirm-payment'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'booking_id': bookingId,
      'payment_reference': paymentReference,
      'payment_status': paymentStatus,
    }),
  );

  if (response.statusCode == 200) {
    print('✅ Réservation confirmée');
  } else {
    print('❌ Erreur confirmation réservation');
  }
}
```

---

## 📊 Structure de Données

### Réponse de create-reservation

```json
{
  "success": true,
  "code": 200,
  "message": "Réservation créée et paiement initié avec succès",
  "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
  "transID": "WORTIS_20240206_123456",
  "clientTransID": "WORTIS_20240206_123456",
  "requires_payment": true,
  "amount": 5000,
  "reservation": {
    "_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "date": "2024-02-15",
    "timeSlot": "14:00 - 15:00",
    "nom": "Jean Dupont",
    "telephone": "242065551234",
    "adresse": "123 Rue, Brazzaville",
    "service_name": "Coiffure",
    "amount": 5000,
    "payment_reference": "WORTIS_20240206_123456",
    "transID": "WORTIS_20240206_123456",
    "payment_status": "pending",
    "status": "pending_payment"
  },
  "payment_details": {
    "transID": "WORTIS_20240206_123456",
    "status": "pending",
    ...
  }
}
```

### Document MongoDB (bookings_apk)

```javascript
{
    "_id": ObjectId("65f8a2b3c4d5e6f7a8b9c0d3"),
    "date": "2024-02-15",
    "timeSlot": "14:00 - 15:00",
    "prestation": "coupe_homme",
    "variant": "courte",
    "nom": "Jean Dupont",
    "telephone": "242065551234",
    "adresse": "123 Rue, Brazzaville",
    "commentaire": "Préfère le matin",
    "service_name": "Coiffure",
    "service_id": "65f8a2b3...",
    "amount": 5000,

    // PAIEMENT
    "payment_method": "MTN_MONEY",
    "payment_reference": "WORTIS_20240206_123456",  // transID
    "transID": "WORTIS_20240206_123456",
    "payment_status": "pending",  // → "successful" après confirmation
    "payment_response": {...},  // Réponse complète de wortispay

    // STATUS
    "status": "pending_payment",  // → "confirmed" après paiement
    "created_at": ISODate("2024-02-06T10:00:00.000Z"),
    "updated_at": ISODate("2024-02-06T10:00:00.000Z"),
    "payment_confirmed_at": null  // Rempli après confirmation
}
```

---

## 🧪 Tests

### Test Backend

```bash
curl -X POST https://api.live.wortis.cg/catalogue/api/bookings/create-reservation \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2024-02-15",
    "timeSlot": "14:00 - 15:00",
    "prestation": "coupe_homme",
    "variant": "courte",
    "nom": "Jean Dupont",
    "telephone": "242065551234",
    "adresse": "123 Rue, Brazzaville",
    "service_name": "Coiffure",
    "service_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "amount": 5000
  }'
```

**Réponse attendue :**
```json
{
  "success": true,
  "transID": "WORTIS_...",
  "booking_id": "...",
  ...
}
```

### Test Checking

```bash
curl -X POST https://api.live.wortis.cg/check_transac_box \
  -H "Content-Type: application/json" \
  -d '{
    "transac": "WORTIS_20240206_123456",
    "mode": "MoMo"
  }'
```

### Test Confirmation

```bash
curl -X POST https://api.live.wortis.cg/catalogue/api/bookings/confirm-payment \
  -H "Content-Type: application/json" \
  -d '{
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "payment_reference": "WORTIS_20240206_123456",
    "payment_status": "SUCCESSFUL"
  }'
```

---

## 📝 Checklist d'Intégration

- [ ] **Backend**: Ajouter `import re` dans Flask
- [ ] **Backend**: Remplacer la route `create-reservation` par la nouvelle version
- [ ] **MongoDB**: Ajouter le champ `numc` dans tous les services ReservationService
- [ ] **MongoDB**: Créer les index avec `python lib/setup_mongodb_indexes.py`
- [ ] **Frontend**: La fonction `checkAndConfirmPayment` est déjà implémentée
- [ ] **Test**: Créer une réservation de test
- [ ] **Test**: Vérifier que le transID est bien retourné
- [ ] **Test**: Vérifier le polling du paiement
- [ ] **Test**: Confirmer une réservation après paiement réussi

---

## ❓ FAQ

### Comment ajouter le numc dans un service ?

```javascript
// Dans MongoDB Compass ou mongosh
db.Service.updateOne(
  { name: "Coiffure avec Créneaux Occupés" },
  { $set: { numc: "242065551234" } }
)
```

### Que se passe-t-il si wortispay.com ne répond pas ?

Le système retourne une erreur 504 (Timeout) et la réservation n'est pas créée. L'utilisateur peut réessayer.

### Comment gérer un paiement échoué ?

Le frontend appelle `confirm-payment` avec `payment_status: "FAILED"`, ce qui met à jour la réservation avec `status: "cancelled"` et libère le créneau.

### Peut-on annuler une réservation avant le paiement ?

Oui, utilisez la route `/api/bookings/cancel` avec le `booking_id` et le `telephone`.

---

## 🎯 Avantages de cette Intégration

✅ **Paiement automatique** : Pas besoin d'action manuelle
✅ **TransID unique** : Suivi précis de chaque transaction
✅ **Checking en temps réel** : Frontend vérifie le status automatiquement
✅ **Sécurisé** : Le créneau est bloqué dès la création
✅ **Compatible** : Utilise votre infrastructure existante wortispay.com

---

**Version :** 1.0
**Date :** 2026-02-06
**Auteur :** Claude Sonnet 4.5
