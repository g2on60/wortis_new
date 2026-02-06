# Mise à Jour des Champs de Réservation

## 📋 Résumé des Changements

Les champs de saisie pour les réservations ont été modifiés :

### ❌ Anciens champs
- `email` : Email de l'utilisateur
- `notes` : Instructions particulières

### ✅ Nouveaux champs
- `nom` : Nom complet de l'utilisateur
- `telephone` : Numéro de téléphone
- `adresse` : Adresse complète
- `commentaire` : Commentaire optionnel

---

## 🔧 Configuration JSON

### Structure des fields

```json
{
  "fields": [
    {
      "name": "type_prestation",
      "type": "selecteur",
      "label": "Type de prestation",
      "required": true,
      "options": [...]
    },
    {
      "name": "nom",
      "type": "text",
      "label": "Nom complet",
      "required": true
    },
    {
      "name": "telephone",
      "type": "text",
      "label": "Numéro de téléphone",
      "required": true,
      "tag": "phone"
    },
    {
      "name": "adresse",
      "type": "text",
      "label": "Adresse",
      "required": true
    },
    {
      "name": "commentaire",
      "type": "text",
      "label": "Commentaire (optionnel)",
      "required": false
    }
  ]
}
```

### Mapping body

```json
{
  "body": {
    "date": "date",
    "timeSlot": "timeSlot",
    "prestation": "type_prestation",
    "variant": "variant",
    "nom": "nom",
    "telephone": "telephone",
    "adresse": "adresse",
    "commentaire": "commentaire"
  }
}
```

---

## 🌐 Routes Flask Mises à Jour

### 1. POST /api/bookings/create-reservation

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
    "service_id": "65f8a2b3c4d5e6f7a8b9c0d3"
}
```

**Validations :**
- ✅ `nom` : Non vide
- ✅ `telephone` : Format valide (commence par + ou chiffre, minimum 7 caractères)
- ✅ `adresse` : Non vide
- ✅ `commentaire` : Optionnel

### 2. POST /api/bookings/cancel

**Changement :** Utilise `telephone` au lieu de `email`

**Body (JSON) :**
```json
{
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "telephone": "+242065551234"
}
```

### 3. GET /api/bookings/user/<telephone>

**Changement :** URL utilise le téléphone au lieu de l'email

**Exemple :**
```
GET /api/bookings/user/+242065551234
```

**Note :** Le `+` dans l'URL doit être encodé comme `%2B` :
```
GET /api/bookings/user/%2B242065551234
```

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
    "nom": "Jean Dupont",                    // ✨ NOUVEAU
    "telephone": "+242065551234",            // ✨ NOUVEAU
    "adresse": "123 Rue, Brazzaville",      // ✨ NOUVEAU
    "commentaire": "Instructions...",        // ✨ NOUVEAU
    "service_name": "Coiffure",
    "service_id": "65f8a2b3...",
    "status": "confirmed",
    "created_at": ISODate("2024-02-06T10:00:00.000Z"),
    "updated_at": ISODate("2024-02-06T10:00:00.000Z")
}
```

### Index MongoDB

Nouvel index sur le téléphone (à la place de l'email) :

```python
db['bookings'].create_index([('telephone', ASCENDING)], name='idx_telephone')
```

---

## 🔄 Migration des Données Existantes

Si vous avez déjà des réservations avec l'ancien format (email, notes), voici un script de migration :

```python
from pymongo import MongoClient
import os

client = MongoClient(os.getenv('MONGODB_URI', 'mongodb://localhost:27017/'))
db = client['wortis']

# Script de migration (optionnel)
# À adapter selon vos besoins

def migrate_bookings():
    """
    Migre les anciennes réservations vers le nouveau format
    """
    bookings = db['bookings'].find({'email': {'$exists': True}})

    for booking in bookings:
        # Convertir email en nom (exemple simple)
        # Vous devrez adapter selon vos données
        update_data = {}

        if 'email' in booking and 'nom' not in booking:
            # Extraire le nom de l'email (exemple basique)
            email = booking['email']
            nom = email.split('@')[0].replace('.', ' ').title()
            update_data['nom'] = nom

        if 'notes' in booking and 'commentaire' not in booking:
            update_data['commentaire'] = booking['notes']

        # Ajouter des champs vides pour téléphone et adresse si non présents
        if 'telephone' not in booking:
            update_data['telephone'] = 'À renseigner'

        if 'adresse' not in booking:
            update_data['adresse'] = 'À renseigner'

        if update_data:
            db['bookings'].update_one(
                {'_id': booking['_id']},
                {'$set': update_data}
            )

    print("Migration terminée")

# Exécuter la migration
# migrate_bookings()
```

---

## 🧪 Tests

### Test avec les nouveaux champs

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
    "adresse": "123 Rue de la Paix, Brazzaville",
    "commentaire": "Préfère le matin",
    "service_name": "Coiffure"
  }'
```

### Test annulation avec téléphone

```bash
curl -X POST https://api.live.wortis.cg/api/bookings/cancel \
  -H "Content-Type: application/json" \
  -d '{
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "telephone": "+242065551234"
  }'
```

### Test récupération par téléphone

```bash
curl "https://api.live.wortis.cg/api/bookings/user/%2B242065551234"
```

---

## ⚠️ Points d'Attention

### Format du numéro de téléphone

Le pattern accepté : `^[\+\d][\d\s\-\(\)]{6,}$`

**Exemples valides :**
- `+242065551234`
- `0655512345`
- `+33 6 55 51 23 45`
- `065-551-2345`
- `(065) 551-2345`

**Exemples invalides :**
- `abc123` (contient des lettres)
- `123` (trop court)
- `@065551234` (caractère invalide)

### Encodage URL

Quand vous utilisez le téléphone dans l'URL (GET /api/bookings/user/<telephone>), pensez à l'encoder :

| Caractère | Encodé |
|-----------|--------|
| `+`       | `%2B`  |
| ` ` (espace) | `%20` ou `+` |
| `-`       | `-` (pas besoin d'encoder) |

---

## ✨ Avantages des Nouveaux Champs

✅ **Nom** : Identification claire de l'utilisateur
✅ **Téléphone** : Contact direct, plus rapide que l'email
✅ **Adresse** : Indispensable pour les services à domicile
✅ **Commentaire** : Instructions libres (au lieu de "notes")

---

## 📝 Checklist de Mise en Production

- [ ] Mettre à jour le JSON de configuration du service dans MongoDB
- [ ] Déployer les nouvelles routes Flask
- [ ] Exécuter le script setup_mongodb_indexes.py pour créer l'index telephone
- [ ] (Optionnel) Migrer les anciennes données
- [ ] Tester avec les nouvelles données
- [ ] Supprimer l'ancien index sur email (optionnel)

```python
# Supprimer l'ancien index email
db['bookings'].drop_index('idx_email')
```

---

**Version :** 2.0
**Date :** 2026-02-06
**Auteur :** Claude Sonnet 4.5
