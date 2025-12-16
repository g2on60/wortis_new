# 🔧 Intégration Backend - Apple Sign In

## 📋 Vue d'ensemble

Ce guide explique comment intégrer les endpoints Apple dans votre backend Python/Flask existant.

---

## 📁 Fichiers fournis

- `BACKEND_APPLE_ENDPOINTS.py` - Code Python complet des 2 endpoints

---

## 🚀 Étape 1 : Copier le code dans app.py

Ouvrez `BACKEND_APPLE_ENDPOINTS.py` et copiez les deux endpoints dans votre fichier `app.py` :

1. **`/famlink/api/auth/apple/login`** (lignes 9-113)
2. **`/famlink/api/auth/apple/complete-profile`** (lignes 116-243)

**Emplacement recommandé** : Après vos endpoints existants `login_apk_wpay_v2_test` et `register_apk_wpay_v2_test`.

---

## 🗄️ Étape 2 : Créer la collection temporaire

Les données Apple sont stockées temporairement (15 minutes) avant finalisation.

### Option A : MongoDB (recommandé)

La collection `AppleAuthTemp` est créée automatiquement avec un TTL index.

**Vérifier l'index TTL** :
```python
# Dans votre terminal Python/MongoDB
client.APK_ARCHIVE.AppleAuthTemp.create_index(
    "created_at",
    expireAfterSeconds=900  # 15 minutes
)
```

### Option B : Redis (alternative)

Si vous utilisez Redis pour le cache, remplacez les lignes de stockage temporaire :

```python
# Au lieu de MongoDB
redis_client.setex(
    f"apple_auth:{completion_token}",
    900,  # 15 minutes
    json.dumps(temp_apple_data)
)
```

---

## 🔧 Étape 3 : Ajouter le champ apple_user_id

Ajoutez le champ `apple_user_id` à votre base de données.

### MongoDB

```python
# Script de migration (à exécuter une seule fois)
from pymongo import MongoClient

client = MongoClient('votre_connection_string')

result = client.APK_ARCHIVE.Users.update_many(
    {"apple_user_id": {"$exists": False}},
    {"$set": {
        "apple_user_id": None,
        "auth_provider": "phone"  # Pour distinguer les types d'auth
    }}
)

print(f"✅ {result.modified_count} utilisateurs mis à jour")
```

### Structure des champs utilisateur

Après migration, chaque utilisateur aura :

```python
{
    "_id": ObjectId("..."),
    "phone_number": "+242 06 123 45 67",
    "password": "hash...",  # None pour Apple
    "nom": "John Doe",
    "email": "user@privaterelay.appleid.com",  # Pour Apple
    "apple_user_id": "000326.abc123.0123",  # Pour Apple (unique)
    "auth_provider": "apple" | "phone" | "google",  # Type d'authentification
    "given_name": "John",  # Pour Apple
    "family_name": "Doe",  # Pour Apple
    "token": "...",
    "secure_token": "...",
    "check_verif": True,
    "country_code": "CG",
    "zone_benef_code": "CG",
    # ... autres champs existants
}
```

---

## 🧪 Étape 4 : Tester les endpoints

### Test 1 : Nouvelle inscription Apple

**Requête** :
```bash
curl -X POST https://api.live.wortis.cg/famlink/api/auth/apple/login \
  -H "Content-Type: application/json" \
  -d '{
    "apple_user_id": "000326.3387614d482f426986ac92a3d91a931d.1207",
    "identity_token": "eyJhbGciOiJSUzI1...",
    "authorization_code": "c12345...",
    "email": "test@privaterelay.appleid.com",
    "given_name": "John",
    "family_name": "Doe",
    "provider": "apk"
  }'
```

**Réponse attendue (201)** :
```json
{
  "Code": 201,
  "messages": "Finalisation du profil requise",
  "completion_token": "abc123def456...",
  "user": {
    "nom": "John Doe",
    "email": "test@privaterelay.appleid.com",
    "apple_user_id": "000326.3387614d482f426986ac92a3d91a931d.1207"
  }
}
```

### Test 2 : Complétion du profil

**Requête** :
```bash
curl -X POST https://api.live.wortis.cg/famlink/api/auth/apple/complete-profile \
  -H "Content-Type: application/json" \
  -d '{
    "completion_token": "abc123def456...",
    "phone": "+242 06 123 45 67",
    "country_name": "Congo",
    "country_code": "CG",
    "zone_benef": "Congo",
    "zone_benef_code": "CG",
    "provider": "apk"
  }'
```

**Réponse attendue (200)** :
```json
{
  "Code": 200,
  "messages": "Inscription Apple finalisée avec succès",
  "token": "secure_token_-_+242%2006%20123%2045%2067_-_John%20Doe",
  "user": {
    "_id": "...",
    "phone_number": "+242 06 123 45 67",
    "nom": "John Doe",
    "email": "test@privaterelay.appleid.com",
    "token": "...",
    "apple_user_id": "000326.3387614d482f426986ac92a3d91a931d.1207",
    "auth_provider": "apple"
  },
  "process_normal": true
}
```

### Test 3 : Connexion utilisateur existant

**Requête** : Même que Test 1

**Réponse attendue (200)** :
```json
{
  "Code": 200,
  "messages": "Connexion Apple réussie",
  "token": "...",
  "user": {
    "_id": "...",
    "phone_number": "+242 06 123 45 67",
    "nom": "John Doe",
    "email": "test@privaterelay.appleid.com",
    "apple_user_id": "000326.3387614d482f426986ac92a3d91a931d.1207"
  },
  "zone_benef": "Congo",
  "zone_benef_code": "CG"
}
```

---

## 🔍 Étape 5 : Vérifications

### 1. Vérifier que les endpoints sont actifs

```bash
curl -I https://api.live.wortis.cg/famlink/api/auth/apple/login
# Devrait retourner 200 ou 400 (pas 404)
```

### 2. Vérifier les logs backend

Ajoutez des prints pour déboguer :

```python
# Dans apple_login
print(f"🍎 [Apple Login] apple_user_id: {apple_user_id}")
print(f"📧 [Apple Login] email: {email}")

# Dans apple_complete_profile
print(f"✅ [Apple Complete] phone: {phone}")
print(f"🔑 [Apple Complete] token: {completion_token}")
```

### 3. Vérifier la base de données

```python
# Vérifier qu'un utilisateur Apple a été créé
user = client.APK_ARCHIVE.Users.find_one({
    "apple_user_id": "000326.3387614d482f426986ac92a3d91a931d.1207"
})
print(user)
```

---

## 🛡️ Sécurité et bonnes pratiques

### 1. Validation du identity_token (recommandé en production)

Pour plus de sécurité, validez le token JWT Apple :

```python
import jwt
import requests

def verify_apple_token(identity_token):
    """
    Vérifie l'authenticité du token Apple auprès des serveurs Apple
    """
    try:
        # Récupérer les clés publiques Apple
        keys_response = requests.get('https://appleid.apple.com/auth/keys')
        keys = keys_response.json()['keys']

        # Décoder le token
        header = jwt.get_unverified_header(identity_token)
        key = next(k for k in keys if k['kid'] == header['kid'])

        # Vérifier la signature
        decoded = jwt.decode(
            identity_token,
            key,
            algorithms=['RS256'],
            audience='cg.wortis.wortis',  # Votre Bundle ID
            issuer='https://appleid.apple.com'
        )

        return decoded

    except Exception as e:
        print(f"❌ Token Apple invalide: {e}")
        return None

# Utilisation dans apple_login
decoded_token = verify_apple_token(identity_token)
if not decoded_token:
    return jsonify({"Code": 401, "messages": "Token Apple invalide"}), 401
```

### 2. Rate limiting

Ajoutez un rate limiting pour éviter les abus :

```python
from flask_limiter import Limiter

limiter = Limiter(app, key_func=lambda: request.remote_addr)

@app.route('/famlink/api/auth/apple/login', methods=['POST'])
@limiter.limit("10 per minute")  # Max 10 requêtes/minute
def apple_login():
    # ...
```

### 3. Logs sécurisés

Ne loggez jamais les tokens en production :

```python
# ❌ MAL
print(f"Token: {identity_token}")

# ✅ BIEN
print(f"Token reçu (longueur: {len(identity_token)})")
```

---

## 🐛 Dépannage

### Erreur : "completion_token invalide ou expiré"

**Cause** : L'utilisateur a attendu plus de 15 minutes entre l'authentification Apple et la saisie du téléphone.

**Solution** :
- Augmenter le TTL : `expireAfterSeconds=1800` (30 minutes)
- Demander à l'utilisateur de recommencer

### Erreur : "Ce numéro de téléphone est déjà enregistré"

**Cause** : Le numéro existe déjà avec une autre méthode d'auth (phone/Google).

**Solutions possibles** :
1. Permettre de lier le compte Apple au compte existant
2. Demander à l'utilisateur de se connecter avec sa méthode habituelle
3. Fusionner les comptes (avancé)

### Erreur : "Ce compte Apple est déjà enregistré"

**Cause** : L'utilisateur essaie de créer un deuxième compte avec le même Apple ID.

**Solution** : Rediriger vers la connexion au lieu de l'inscription.

### Token Python manquant : `generate_secure_token_apk()`

Si la fonction n'existe pas, ajoutez :

```python
import secrets

def generate_secure_token_apk():
    return secrets.token_hex(16)
```

---

## 📊 Statistiques et monitoring

### Compter les utilisateurs Apple

```python
apple_users_count = client.APK_ARCHIVE.Users.count_documents({
    "auth_provider": "apple"
})
print(f"📊 Utilisateurs Apple: {apple_users_count}")
```

### Taux de conversion

```python
# Inscription partielle
temp_count = client.APK_ARCHIVE.AppleAuthTemp.count_documents({})

# Inscription complète
completed_count = client.APK_ARCHIVE.Users.count_documents({
    "auth_provider": "apple"
})

conversion_rate = (completed_count / (completed_count + temp_count)) * 100
print(f"📈 Taux de conversion: {conversion_rate:.1f}%")
```

---

## ✅ Checklist de déploiement

### Backend
- [ ] Code des 2 endpoints copié dans app.py
- [ ] Imports ajoutés (secrets, datetime, urllib.parse, bcrypt)
- [ ] Collection AppleAuthTemp créée avec index TTL
- [ ] Champ apple_user_id ajouté aux utilisateurs existants
- [ ] Tests effectués sur les 3 scénarios
- [ ] Logs ajoutés pour débogage
- [ ] Rate limiting configuré (optionnel)
- [ ] Validation token Apple (optionnel, prod)

### Base de données
- [ ] Index créé sur apple_user_id (unique)
- [ ] Index TTL créé sur AppleAuthTemp
- [ ] Migration exécutée pour utilisateurs existants

### Tests
- [ ] Test nouvelle inscription (201)
- [ ] Test complétion profil (200)
- [ ] Test connexion existante (200)
- [ ] Test avec email masqué @privaterelay.appleid.com
- [ ] Test expiration completion_token (15 min)
- [ ] Test doublon téléphone (409)
- [ ] Test doublon Apple ID (409)

### Production
- [ ] Variables d'environnement configurées
- [ ] HTTPS activé (obligatoire pour Apple)
- [ ] Monitoring des erreurs (Sentry, etc.)
- [ ] Backup base de données

---

## 🚀 Mise en production

### 1. Déployer le backend

```bash
# Redémarrer le serveur Flask
sudo systemctl restart wortis-api
# ou
gunicorn app:app --reload
```

### 2. Vérifier les endpoints

```bash
curl -X POST https://api.live.wortis.cg/famlink/api/auth/apple/login \
  -H "Content-Type: application/json" \
  -d '{"apple_user_id":"test"}'

# Devrait retourner Code 201 ou 400 (pas 404)
```

### 3. Tester depuis l'app Flutter

```bash
flutter run
# Cliquer sur "Se connecter avec Apple"
# Vérifier les logs : "📡 [AppleAuth] Réponse serveur: 201"
```

### 4. Monitorer les logs

```bash
# Logs Flask
tail -f /var/log/wortis/api.log

# Logs MongoDB
mongo
> use APK_ARCHIVE
> db.AppleAuthTemp.find()
> db.Users.find({"auth_provider": "apple"})
```

---

## 📞 Support

Si vous rencontrez des problèmes :

1. **Vérifier les logs backend** : `tail -f /var/log/wortis/api.log`
2. **Vérifier les logs Flutter** : `flutter run -v`
3. **Vérifier la base de données** : Collection Users et AppleAuthTemp
4. **Tester avec curl** : Voir section Tests ci-dessus

---

**Bonne intégration !** 🚀
