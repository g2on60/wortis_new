# 🚀 Intégration Catalog Service - Documentation Complète

## 📋 Vue d'ensemble

Cette documentation explique l'intégration complète entre Flutter (catalog_service.dart) et Flask pour le système de commande et paiement des services de type catalogue (Vival, etc.).

**Note:** Le `catalog_service.dart` est **générique** et peut gérer n'importe quel service de type catalogue, pas uniquement Vival.

---

## 🔄 Flux de données complet

```
Flutter App → Flask API → WortisPay → MongoDB
    ↓                          ↓
CheckoutPage             vival_payment_route.py
```

---

## 📤 Structure des données envoyées depuis Flutter

### Format JSON envoyé par `_submitOrder()`:

```json
{
  "montant": 4200,
  "momo": "242066985554",
  "name": "John Doe",
  "mobile": "242066985554",
  "adresse": "Brazzaville, Congo",
  "nom": "John Doe",
  "commande": {
    "65cf5106abf1d162d35664ae": {
      "nom": "Pack de 8 x 1.5",
      "prix": 2100,
      "quantite": 2,
      "description": "Le grand classique de notre gamme..."
    }
  },
  "delivery_option": "standard",
  "delivery_fee": 500,
  "notes": "Livraison avant 18h"
}
```

### Correspondance des champs:

| Champ Flutter | Champ Flask | Source | Description |
|--------------|-------------|--------|-------------|
| `montant` | `montant` | `total` (subtotal + delivery_fee) | Montant total FCFA |
| `momo` | `momo` | `userData.enregistrement['mobile']` | Numéro Mobile Money |
| `name` | `name` | `userData.enregistrement['username']` ou `['nom']` | Nom pour paiement |
| `mobile` | `mobile` | `_phoneController.text` | Téléphone de contact |
| `adresse` | `adresse` | `_addressController.text` | Adresse de livraison |
| `nom` | `nom` | `userData.enregistrement['username']` ou `['nom']` | Nom du client |
| `commande` | `commande` | `widget.cart` transformé | Détails des produits |

---

## 📥 Traitement côté Flask

### Étape 1: Validation

```python
# Vérification des champs obligatoires
required_fields = ['montant', 'momo', 'name', 'mobile', 'adresse', 'nom', 'commande']

# Validation de la commande
validate_commandes_vival(data['commande'])  # Vérifie dans cat_vival

# Calcul et vérification du montant
calculated_total = calculate_order_total(data['commande'])
```

### Étape 2: Paiement WortisPay

```python
payment_data = {
    "numc": "4b851209-4de0-4581-9eb5-2225f9925d12",
    "montant": data['montant'],
    "numPaid": data['momo'],
    "typeVersement": "Commande Vival",
    "name": data['name']
}

response = requests.post('https://wortispay.com/api/paiement/json', json=payment_data)
```

### Étape 3: Enrichissement des données

La fonction `enrich_order_with_catalog_data()` transforme:

**Avant (reçu de Flutter):**
```json
{
  "65cf5106abf1d162d35664ae": {
    "nom": "Pack de 8 x 1.5",
    "prix": 2100,
    "quantite": 2
  }
}
```

**Après (enrichi avec cat_vival):**
```json
{
  "65cf5106abf1d162d35664ae": {
    "product_id": "65cf5106abf1d162d35664ae",
    "nom": "Pack de 8 x 1.5",
    "prix_unitaire": 2100,
    "quantite": 2,
    "total": 4200,
    "description": "Le grand classique de notre gamme!...",
    "fileLink": "1_5l.png",
    "l": "L",
    "vendu": 56
  }
}
```

### Étape 4: Enregistrement MongoDB

```python
order_data = {
    'transID': trans_id,
    'mobile': data['mobile'],
    'adresse': data['adresse'],
    'nom': data['nom'],
    'commande': enriched_commande,  # Enrichie
    'commande_originale': data['commande'],  # Originale
    'montant': data['montant'],
    'payment_status': 'pending',
    'payment_response': payment_result,
    'created_at': datetime.utcnow(),
    'updated_at': datetime.utcnow()
}

euroshop_db.vival.insert_one(order_data)
```

### Étape 5: Mise à jour compteur ventes

```python
# Incrémente le champ 'vendu' dans cat_vival
euroshop_db.cat_vival.update_one(
    {'_id': ObjectId(product_id)},
    {'$inc': {'vendu': quantite}}
)
```

---

## 📊 Collections MongoDB

### Collection: `cat_vival` (Catalogue produits)

```json
{
  "_id": ObjectId("65cf5106abf1d162d35664ae"),
  "nom": "Pack de 8 x 1.5",
  "prix": 2100,
  "description": "Le grand classique...",
  "l": "L",
  "vendu": 56,
  "fileLink": "1_5l.png",
  "pop": ""
}
```

### Collection: `vival` (Commandes)

```json
{
  "_id": ObjectId("..."),
  "transID": "VIVAL_20250105123045_5554",
  "mobile": "242066985554",
  "adresse": "Brazzaville, Congo",
  "nom": "John Doe",
  "commande": {
    "65cf5106abf1d162d35664ae": {
      "product_id": "65cf5106abf1d162d35664ae",
      "nom": "Pack de 8 x 1.5",
      "prix_unitaire": 2100,
      "quantite": 2,
      "total": 4200,
      "description": "...",
      "fileLink": "1_5l.png",
      "l": "L",
      "vendu": 56
    }
  },
  "commande_originale": {...},
  "montant": 4200,
  "payment_status": "pending",
  "payment_response": {...},
  "created_at": ISODate("2025-01-05T12:30:45Z"),
  "updated_at": ISODate("2025-01-05T12:30:45Z")
}
```

---

## 🎯 Routes disponibles

### 1. POST `/vival/checkout` - Commande avec paiement

**Description:** Route principale pour créer une commande avec paiement

**Headers:**
```
Content-Type: application/json
Authorization: Bearer <token>
```

**Réponse succès (201):**
```json
{
  "code": 200,
  "message": "Paiement initié et commande enregistrée avec succès",
  "transID": "VIVAL_20250105123045_5554",
  "order_id": "67890abc123def456",
  "montant_total": 4200,
  "nombre_articles": 2,
  "payment_details": {...}
}
```

**Réponse erreur (400):**
```json
{
  "error": "Le montant ne correspond pas au total de la commande",
  "montant_envoye": 4000,
  "montant_calcule": 4200
}
```

### 2. POST `/vival` - Enregistrement direct

**Description:** Enregistre une commande sans passer par le paiement (besoin d'un transID)

### 3. POST `/vival/payment/callback` - Callback paiement

**Description:** Reçoit les mises à jour de statut depuis WortisPay

### 4. GET `/vival/orders/<order_id>` - Récupérer une commande

**Description:** Consulter les détails d'une commande spécifique

---

## 🛡️ Sécurité & Validations

### Validations Flutter (avant envoi):
✅ Formulaire validé (`_formKey.currentState!.validate()`)
✅ Champs obligatoires (téléphone, adresse)
✅ Montant calculé (subtotal + delivery_fee)

### Validations Flask (côté serveur):
✅ Champs obligatoires présents
✅ Produits existent dans `cat_vival`
✅ ObjectId valides
✅ Quantités > 0
✅ Prix correspondent à la base de données
✅ Montant total vérifié

---

## 🐛 Debugging

### Logs Flutter:
```dart
print('📦 [CATALOG] Envoi commande: ${jsonEncode(orderData)}');
print('📦 [CATALOG] Réponse: ${response.statusCode} - ${response.body}');
print('✅ [CATALOG] Commande réussie: ${responseData['transID']}');
print('❌ [CATALOG] Erreur commande: $e');
```

### Logs Flask:
```python
print("[VIVAL] Déclenchement du paiement pour {name} - Montant: {montant}")
print(f"[VIVAL] ✓ Produit validé: {nom} x{quantite} = {total} FCFA")
print(f"[VIVAL] Commande enregistrée avec ID: {inserted_id}")
print(f"[VIVAL] ✓ Compteur vendu mis à jour pour {nom}: +{quantite}")
```

---

## 🚀 Configuration dans l'API JSON

Dans votre JSON de configuration du service Vival, assurez-vous d'avoir:

```json
{
  "api_checkout": "https://api.live.wortis.cg/vival/checkout"
}
```

---

## ✅ Checklist d'intégration

- [x] Structure de données Flutter adaptée
- [x] Route Flask `/vival/checkout` créée
- [x] Validation des produits dans `cat_vival`
- [x] Intégration WortisPay
- [x] Enrichissement avec données catalogue
- [x] Mise à jour compteur `vendu`
- [x] Gestion des erreurs complète
- [x] Logs de debugging
- [ ] Tests avec vraies données
- [ ] Configuration production

---

## 📝 Notes importantes

1. **Récupération des données utilisateur:**
   ```dart
   final userData = await UserService.getUserInfo(token);
   final mobile = userData.enregistrement['mobile']?.toString();
   final username = userData.enregistrement['username']?.toString();
   ```

2. **SessionManager.getToken()** doit fournir le token d'authentification

3. **Format générique:** Le `catalog_service.dart` envoie un format standard qui peut être adapté pour n'importe quel service (Vival, etc.)

4. **Validation côté serveur:** Chaque backend doit valider les produits selon sa propre collection

5. **Pour Vival spécifiquement:**
   - Le **numc** WortisPay est hardcodé: `4b851209-4de0-4581-9eb5-2225f9925d12`
   - Le champ **vendu** dans `cat_vival` s'incrémente automatiquement
   - Les prix sont validés contre `cat_vival`

---

## 🔗 Références

- API WortisPay: `https://wortispay.com/api/paiement/json`
- API Checkout: `https://api.live.wortis.cg/vival/checkout`
- Collection MongoDB: `euroshop_db.vival`
- Catalogue: `euroshop_db.cat_vival`
