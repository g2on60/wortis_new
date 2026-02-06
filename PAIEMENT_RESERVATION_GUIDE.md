# Guide du Système de Paiement - Réservations

## 📋 Vue d'ensemble

Le système de réservation intègre maintenant un processus de paiement obligatoire. Une réservation n'est confirmée qu'après la validation du paiement.

---

## 🔄 Flux de Réservation avec Paiement

```
1. Utilisateur choisit prestation + date + créneau
   └─> Calcul du montant (prix prestation + variante)

2. Utilisateur remplit ses coordonnées
   └─> Nom, Téléphone, Adresse, Commentaire

3. Création de la réservation (status: pending_payment)
   └─> POST /api/bookings/create-reservation
   └─> Retourne booking_id

4. Redirection vers paiement Mobile Money
   └─> MTN Money / Airtel Money / etc.
   └─> L'utilisateur valide le paiement sur son téléphone

5. Vérification du paiement
   └─> Polling GET /api/bookings/check-payment/<booking_id>
   └─> Ou Callback POST /api/bookings/confirm-payment

6. Confirmation finale
   ├─> Paiement réussi → status: confirmed ✅
   └─> Paiement échoué → status: cancelled ❌
```

---

## 🌐 Routes API avec Paiement

### 1. POST `/api/bookings/create-reservation`

Créer une réservation avec paiement requis.

**Body (JSON) :**
```json
{
    "date": "2024-02-15",
    "timeSlot": "14:00-15:00",
    "prestation": "coupe_homme",
    "variant": "courte",
    "nom": "Jean Dupont",
    "telephone": "+242065551234",
    "adresse": "123 Rue de la Paix, Brazzaville",
    "commentaire": "Préfère le matin",
    "service_name": "Coiffure",
    "service_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "amount": 5000,
    "payment_method": "MTN_MONEY",
    "payment_reference": "REF123456789"
}
```

**Champs requis :**
- `amount` : Montant du paiement (calculé depuis le prix de la prestation/variante)
- `payment_method` : Méthode de paiement (MTN_MONEY, AIRTEL_MONEY, etc.)
- `payment_reference` : Référence générée par le système de paiement (optionnel au moment de la création)

**Réponse (201) :**
```json
{
    "success": true,
    "message": "Réservation créée. En attente de paiement.",
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "requires_payment": true,
    "amount": 5000,
    "reservation": {
        "_id": "65f8a2b3c4d5e6f7a8b9c0d3",
        "date": "2024-02-15",
        "timeSlot": "14:00-15:00",
        "status": "pending_payment",
        "payment_status": "pending",
        "amount": 5000,
        ...
    }
}
```

---

### 2. POST `/api/bookings/confirm-payment`

Confirmer ou rejeter un paiement (webhook/callback).

**Body (JSON) :**
```json
{
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "payment_reference": "REF123456789",
    "payment_status": "SUCCESSFUL",
    "transaction_id": "TXN987654321"
}
```

**Valeurs de payment_status :**
- `SUCCESSFUL`, `SUCCESS`, `200` → Paiement réussi
- Toute autre valeur → Paiement échoué

**Réponse (200) - Succès :**
```json
{
    "success": true,
    "message": "Paiement confirmé",
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "status": "confirmed",
    "payment_status": "successful"
}
```

**Réponse (200) - Échec :**
```json
{
    "success": true,
    "message": "Paiement échoué",
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "status": "cancelled",
    "payment_status": "failed"
}
```

---

### 3. GET `/api/bookings/check-payment/<booking_id>`

Vérifier le statut du paiement (polling).

**Exemple :**
```
GET /api/bookings/check-payment/65f8a2b3c4d5e6f7a8b9c0d3
```

**Réponse (200) :**
```json
{
    "success": true,
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "payment_status": "successful",
    "status": "confirmed",
    "amount": 5000,
    "payment_reference": "REF123456789",
    "transaction_id": "TXN987654321"
}
```

**Usage :**
Utilisez cette route pour vérifier le statut du paiement toutes les 2-3 secondes après avoir initié le paiement.

---

### 4. GET `/api/bookings/occupied-slots`

**⚠️ Important :** Cette route a été mise à jour pour ne retourner que les créneaux avec :
- `status` = `confirmed` ou `pending_payment`
- `payment_status` ≠ `failed`

Les créneaux avec paiement échoué sont libérés automatiquement.

---

## 📊 Structure MongoDB Mise à Jour

### Collection `bookings`

```javascript
{
    "_id": ObjectId("65f8a2b3c4d5e6f7a8b9c0d3"),
    "date": "2024-02-15",
    "timeSlot": "14:00-15:00",
    "prestation": "coupe_homme",
    "variant": "courte",
    "nom": "Jean Dupont",
    "telephone": "+242065551234",
    "adresse": "123 Rue de la Paix, Brazzaville",
    "commentaire": "Préfère le matin",
    "service_name": "Coiffure",
    "service_id": "65f8a2b3...",

    // 💰 PAIEMENT
    "amount": 5000,
    "payment_method": "MTN_MONEY",
    "payment_reference": "REF123456789",
    "transaction_id": "TXN987654321",
    "payment_status": "successful",        // pending | successful | failed
    "payment_confirmed_at": ISODate("2024-02-06T10:05:00.000Z"),
    "payment_failed_at": null,

    // 📋 STATUS
    "status": "confirmed",                  // pending_payment | confirmed | cancelled
    "created_at": ISODate("2024-02-06T10:00:00.000Z"),
    "updated_at": ISODate("2024-02-06T10:05:00.000Z"),
    "cancelled_at": null
}
```

### Status expliqués

**payment_status :**
- `pending` : En attente de paiement
- `successful` : Paiement réussi
- `failed` : Paiement échoué

**status :**
- `pending_payment` : Réservation créée, en attente du paiement
- `confirmed` : Réservation confirmée (paiement réussi)
- `cancelled` : Réservation annulée (par l'utilisateur ou échec du paiement)

---

## 💻 Intégration Frontend (Flutter)

### Étape 1 : Calcul du montant

```dart
double _calculateAmount() {
  double basePrice = 0;

  // Prix de base de la prestation
  if (_currentPrestationData != null) {
    basePrice = _currentPrestationData['price'] ?? 0;
  }

  // Prix de la variante (remplace le prix de base)
  if (_selectedVariantId != null && _currentPrestationData?['variants'] != null) {
    final variant = _currentPrestationData['variants'].firstWhere(
      (v) => v['id'] == _selectedVariantId,
      orElse: () => null,
    );
    if (variant != null && variant['price'] != null) {
      basePrice = variant['price'];
    }
  }

  return basePrice;
}
```

### Étape 2 : Création de la réservation

```dart
final amount = _calculateAmount();

final response = await http.post(
  Uri.parse('${serviceData['link_momo']}'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({
    'date': selectedDate,
    'timeSlot': selectedTimeSlot,
    'prestation': formValues['type_prestation'],
    'variant': formValues['variant'],
    'nom': formValues['nom'],
    'telephone': formValues['telephone'],
    'adresse': formValues['adresse'],
    'commentaire': formValues['commentaire'],
    'service_name': serviceData['name'],
    'service_id': serviceData['_id'],
    'amount': amount,
    'payment_method': 'MTN_MONEY',
  }),
);

if (response.statusCode == 201) {
  final data = json.decode(response.body);
  final bookingId = data['booking_id'];

  // Initier le paiement Mobile Money
  await initiatePayment(bookingId, amount);
}
```

### Étape 3 : Initier le paiement Mobile Money

```dart
Future<void> initiatePayment(String bookingId, double amount) async {
  // Utiliser votre service de paiement Mobile Money existant
  // Exemple avec l'API que vous utilisez déjà

  final paymentResponse = await ApiService.callService(
    context: context,
    serviceData: {
      'link_momo': 'https://votre-api-paiement.com/initiate',
      'body': {
        'amount': amount,
        'telephone': formValues['telephone'],
        'booking_id': bookingId,
      }
    },
    formValues: {}
  );

  if (paymentResponse['success']) {
    final paymentReference = paymentResponse['reference'];

    // Afficher le dialogue d'attente
    showTransactionCheckingDialog(context, bookingId, paymentReference);
  }
}
```

### Étape 4 : Vérification du paiement (Polling)

```dart
Future<void> checkPaymentStatus(String bookingId) async {
  Timer.periodic(Duration(seconds: 3), (timer) async {
    final response = await http.get(
      Uri.parse('https://api.live.wortis.cg/api/bookings/check-payment/$bookingId'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['payment_status'] == 'successful') {
        timer.cancel();
        // Paiement réussi, réservation confirmée
        _showSuccessDialog();
      } else if (data['payment_status'] == 'failed') {
        timer.cancel();
        // Paiement échoué
        _showErrorDialog();
      }
      // Si pending, on continue de vérifier
    }
  });
}
```

---

## 🔐 Sécurité

### Validation du montant côté backend

⚠️ **IMPORTANT** : Ne jamais faire confiance au montant envoyé par le frontend !

```python
@catalog_apk_bp.route('/api/bookings/create-reservation', methods=['POST'])
def create_reservation():
    data = request.get_json()

    # Récupérer le service depuis la base
    service = db['services_collection'].find_one({'name': data['service_name']})

    # Récupérer le prix réel depuis le service
    prestation = next((p for p in service['fields'][0]['options']
                      if p['value'] == data['prestation']), None)

    if prestation:
        # Vérifier si c'est une variante
        if data.get('variant') and prestation.get('variants'):
            variant = next((v for v in prestation['variants']
                          if v['id'] == data['variant']), None)
            expected_amount = variant['price'] if variant else 0
        else:
            expected_amount = prestation.get('price', 0)

        # Vérifier que le montant correspond
        if data['amount'] != expected_amount:
            return jsonify({
                'success': False,
                'error': 'Montant invalide'
            }), 400

    # Continuer avec la création...
```

### Webhook sécurisé

```python
@catalog_apk_bp.route('/api/bookings/confirm-payment', methods=['POST'])
def confirm_payment():
    # Vérifier la signature du webhook
    signature = request.headers.get('X-Signature')
    if not verify_signature(request.data, signature):
        return jsonify({'success': False, 'error': 'Invalid signature'}), 401

    # Continuer avec la confirmation...
```

---

## 🧪 Tests

### Test de création avec paiement

```bash
curl -X POST https://api.live.wortis.cg/api/bookings/create-reservation \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2024-02-15",
    "timeSlot": "14:00-15:00",
    "prestation": "coupe_homme",
    "variant": "courte",
    "nom": "Jean Dupont",
    "telephone": "+242065551234",
    "adresse": "123 Rue, Brazzaville",
    "commentaire": "Test",
    "service_name": "Coiffure",
    "amount": 5000,
    "payment_method": "MTN_MONEY"
  }'
```

### Test de confirmation de paiement

```bash
curl -X POST https://api.live.wortis.cg/api/bookings/confirm-payment \
  -H "Content-Type: application/json" \
  -d '{
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "payment_reference": "REF123456789",
    "payment_status": "SUCCESSFUL",
    "transaction_id": "TXN987654321"
  }'
```

### Test de vérification du statut

```bash
curl "https://api.live.wortis.cg/api/bookings/check-payment/65f8a2b3c4d5e6f7a8b9c0d3"
```

---

## 📈 Monitoring et Analytics

### Métriques importantes

1. **Taux de conversion** : Réservations créées vs confirmées
2. **Taux d'échec de paiement** : Paiements échoués / Total tentatives
3. **Temps moyen de paiement** : De pending_payment à confirmed
4. **Méthodes de paiement** : Distribution MTN, Airtel, etc.

### Requêtes MongoDB utiles

**Réservations en attente de paiement :**
```javascript
db.bookings.find({
    status: "pending_payment",
    created_at: { $gte: new Date(Date.now() - 30*60000) } // Dernières 30 min
})
```

**Taux de réussite par jour :**
```javascript
db.bookings.aggregate([
    {
        $group: {
            _id: { $dateToString: { format: "%Y-%m-%d", date: "$created_at" } },
            total: { $sum: 1 },
            confirmed: {
                $sum: { $cond: [{ $eq: ["$payment_status", "successful"] }, 1, 0] }
            }
        }
    }
])
```

---

## ❓ FAQ

### Comment gérer les paiements expirés ?

Ajoutez un job cron qui annule les réservations en `pending_payment` depuis plus de 15 minutes :

```python
from datetime import timedelta

def cancel_expired_payments():
    expiration_time = datetime.utcnow() - timedelta(minutes=15)

    db['bookings'].update_many(
        {
            'status': 'pending_payment',
            'created_at': {'$lt': expiration_time}
        },
        {
            '$set': {
                'status': 'cancelled',
                'payment_status': 'failed',
                'updated_at': datetime.utcnow()
            }
        }
    )
```

### Comment gérer les remboursements ?

Ajoutez une route pour gérer les remboursements :

```python
@catalog_apk_bp.route('/api/bookings/refund', methods=['POST'])
def refund_booking():
    # Logique de remboursement
    # Mettre à jour le status et payment_status
    pass
```

---

**Version :** 1.0
**Date :** 2026-02-06
**Auteur :** Claude Sonnet 4.5
