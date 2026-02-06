# Intégration des Routes Flask - Réservations

## 📋 Vue d'ensemble

Ce guide explique comment intégrer les routes de réservation dans votre backend Flask existant.

---

## 🔧 Étapes d'intégration

### 1. Importer les routes dans votre fichier principal

Dans votre fichier `app.py` (ou le fichier contenant votre Blueprint `catalog_apk_bp`), copiez le contenu de `flask_reservation_routes.py`.

### 2. Vérifier les imports

Assurez-vous que ces imports sont présents :

```python
from flask import request, jsonify
from datetime import datetime
from bson import ObjectId
import re
```

### 3. Collection MongoDB

Les routes utilisent la collection `bookings`. Assurez-vous que votre connexion MongoDB est configurée :

```python
# Votre configuration existante
client = MongoClient(os.getenv('MONGODB_URI'))
db = client['wortis']  # ou votre nom de base de données
```

### 4. Créer les index MongoDB (Important !)

Pour des performances optimales, créez ces index :

```python
# À exécuter une seule fois au démarrage ou dans un script d'initialisation
db['bookings'].create_index([('date', 1), ('service_name', 1), ('status', 1)])
db['bookings'].create_index([('email', 1)])
db['bookings'].create_index([('created_at', -1)])
```

---

## 🌐 Routes disponibles

### 1. **POST** `/api/bookings/create-reservation`
Créer une nouvelle réservation

**Body (JSON) :**
```json
{
    "date": "2024-02-15",
    "timeSlot": "14:00-15:00",
    "prestation": "coupe_homme",
    "variant": "courte",
    "email": "user@example.com",
    "notes": "Instructions particulières",
    "service_name": "Coiffure",
    "service_id": "65f8a2b3c4d5e6f7a8b9c0d3"
}
```

**Réponse (201) :**
```json
{
    "success": true,
    "message": "Réservation créée avec succès",
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "reservation": {
        "_id": "65f8a2b3c4d5e6f7a8b9c0d3",
        "date": "2024-02-15",
        "timeSlot": "14:00-15:00",
        "prestation": "coupe_homme",
        "variant": "courte",
        "email": "user@example.com",
        "notes": "Instructions particulières",
        "service_name": "Coiffure",
        "status": "confirmed",
        "created_at": "2024-02-06T10:00:00.000Z"
    }
}
```

**Erreurs possibles :**
- 400 : Champs manquants ou invalides
- 409 : Créneau déjà réservé
- 500 : Erreur serveur

---

### 2. **GET** `/api/bookings/occupied-slots`
Récupérer les créneaux occupés pour une date et un service

**Query parameters :**
- `date` : Date au format YYYY-MM-DD (requis)
- `service` : Nom du service (requis)

**Exemple :**
```
GET /api/bookings/occupied-slots?date=2024-02-15&service=Coiffure
```

**Réponse (200) :**
```json
{
    "success": true,
    "date": "2024-02-15",
    "service": "Coiffure",
    "occupied_slots": ["08:00-09:00", "14:00-15:00"],
    "total_occupied": 2
}
```

---

### 3. **POST** `/api/bookings/cancel`
Annuler une réservation

**Body (JSON) :**
```json
{
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "email": "user@example.com"
}
```

**Réponse (200) :**
```json
{
    "success": true,
    "message": "Réservation annulée avec succès"
}
```

**Erreurs possibles :**
- 400 : Paramètres manquants ou réservation déjà annulée
- 404 : Réservation non trouvée
- 500 : Erreur serveur

---

### 4. **GET** `/api/bookings/user/<email>`
Récupérer toutes les réservations d'un utilisateur

**Exemple :**
```
GET /api/bookings/user/user@example.com
```

**Réponse (200) :**
```json
{
    "success": true,
    "bookings": [
        {
            "_id": "65f8a2b3c4d5e6f7a8b9c0d3",
            "date": "2024-02-15",
            "timeSlot": "14:00-15:00",
            "prestation": "coupe_homme",
            "status": "confirmed",
            "created_at": "2024-02-06T10:00:00.000Z"
        }
    ],
    "total": 1
}
```

---

## 📊 Structure MongoDB

### Collection `bookings`

```javascript
{
    "_id": ObjectId("65f8a2b3c4d5e6f7a8b9c0d3"),
    "date": "2024-02-15",                    // Format YYYY-MM-DD
    "timeSlot": "14:00-15:00",               // Format HH:MM-HH:MM
    "prestation": "coupe_homme",             // ID de la prestation
    "variant": "courte",                     // ID de la variante (optionnel)
    "email": "user@example.com",             // Email de l'utilisateur
    "notes": "Instructions particulières",   // Notes (optionnel)
    "service_name": "Coiffure",              // Nom du service
    "service_id": "65f8a2b3...",            // ID du service (optionnel)
    "status": "confirmed",                   // confirmed | pending | cancelled
    "created_at": ISODate("2024-02-06T10:00:00.000Z"),
    "updated_at": ISODate("2024-02-06T10:00:00.000Z"),
    "cancelled_at": ISODate("2024-02-06T11:00:00.000Z")  // Si annulé
}
```

### Status possibles
- `confirmed` : Réservation confirmée
- `pending` : Réservation en attente de confirmation
- `cancelled` : Réservation annulée

---

## 🔒 Sécurité et Validation

### Validations implémentées

✅ **Format de date** : `YYYY-MM-DD`
✅ **Format de créneau** : `HH:MM-HH:MM`
✅ **Format d'email** : Validation avec regex
✅ **Date passée** : Impossible de réserver dans le passé
✅ **Conflit de créneaux** : Vérifie que le créneau n'est pas déjà réservé
✅ **Annulation** : Vérification de l'email pour autoriser l'annulation

### Recommandations supplémentaires

1. **Ajouter l'authentification** : Protéger les routes avec JWT ou session
2. **Rate limiting** : Limiter le nombre de requêtes par IP
3. **CORS** : Configurer les origines autorisées
4. **Logs** : Logger les réservations et erreurs

```python
# Exemple avec Flask-CORS
from flask_cors import CORS

# Dans votre app
CORS(app, resources={
    r"/api/bookings/*": {
        "origins": ["https://votre-domaine.com"]
    }
})
```

---

## 🔄 Configuration Flutter

Dans votre configuration JSON du service, ajoutez :

```json
{
    "link_momo": "https://api.live.wortis.cg/api/bookings/create-reservation",
    "availability": {
        "api_occupied_slots": "https://api.live.wortis.cg/api/bookings/occupied-slots?date={date}&service={service}"
    }
}
```

---

## 🧪 Tests

### Test de création de réservation

```bash
curl -X POST https://api.live.wortis.cg/api/bookings/create-reservation \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2024-02-15",
    "timeSlot": "14:00-15:00",
    "prestation": "coupe_homme",
    "variant": "courte",
    "email": "test@example.com",
    "service_name": "Coiffure"
  }'
```

### Test de récupération des créneaux occupés

```bash
curl "https://api.live.wortis.cg/api/bookings/occupied-slots?date=2024-02-15&service=Coiffure"
```

### Test d'annulation

```bash
curl -X POST https://api.live.wortis.cg/api/bookings/cancel \
  -H "Content-Type: application/json" \
  -d '{
    "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
    "email": "test@example.com"
  }'
```

### Test de récupération des réservations d'un utilisateur

```bash
curl "https://api.live.wortis.cg/api/bookings/user/test@example.com"
```

---

## 🚀 Déploiement

### Variables d'environnement

Assurez-vous que ces variables sont configurées :

```bash
MONGODB_URI=mongodb://localhost:27017/
DATABASE_NAME=wortis
```

### Production

1. Activez HTTPS uniquement
2. Configurez un reverse proxy (Nginx)
3. Utilisez Gunicorn ou uWSGI
4. Activez les logs en production
5. Configurez un système de backup MongoDB

---

## 📈 Monitoring

### Métriques à surveiller

- Nombre de réservations créées par jour
- Taux d'échec des réservations
- Temps de réponse de l'API
- Conflits de créneaux (409)

### Logs

Les routes loggent automatiquement les erreurs dans la console. En production, configurez un système de logging approprié :

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('bookings.log'),
        logging.StreamHandler()
    ]
)
```

---

## ❓ FAQ

### Comment ajouter un email de confirmation ?

Utilisez Flask-Mail après la création de la réservation :

```python
from flask_mail import Mail, Message

mail = Mail(app)

# Après insert_one dans create_reservation
msg = Message(
    'Confirmation de réservation',
    sender='noreply@wortis.cg',
    recipients=[data['email']]
)
msg.body = f"Votre réservation pour le {data['date']} à {data['timeSlot']} est confirmée."
mail.send(msg)
```

### Comment limiter les réservations à X jours à l'avance ?

```python
max_days_ahead = 30
max_date = datetime.now() + timedelta(days=max_days_ahead)

if reservation_date.date() > max_date.date():
    return jsonify({
        'success': False,
        'error': f'Réservations limitées à {max_days_ahead} jours à l\'avance'
    }), 400
```

### Comment ajouter des notifications SMS ?

Intégrez un service comme Twilio après la création :

```python
from twilio.rest import Client

client = Client(account_sid, auth_token)
message = client.messages.create(
    body=f"Réservation confirmée: {data['date']} à {data['timeSlot']}",
    from_='+242XXXXXXXXX',
    to=user_phone
)
```

---

**Version :** 1.0
**Date :** 2026-02-06
**Auteur :** Claude Sonnet 4.5
