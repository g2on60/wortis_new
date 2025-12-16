# ========== ENDPOINTS APPLE SIGN IN ==========
# À ajouter dans votre fichier app.py
from flask import Flask, request, jsonify, Blueprint
import urllib.parse
import bcrypt
from datetime import datetime
import secrets
import re
from pymongo import MongoClient


applebp = Blueprint('apple', __name__, url_prefix='')
client = MongoClient("mongodb://dipadmin:Cgt*2020#@31.207.36.187,62.210.100.14,62.210.101.31/admin?replicaSet=rs0&readPreference=secondaryPreferred&authSource=admin&connectTimeoutMS=30000", connect=False)

# Configuration pour SMS (à adapter selon votre système)
regextel = r"^(05|06|07)[0-9]{7}$"  # Pattern pour numéros congolais
# BD_e2c = MongoClient(...).e2c  # Décommenter et configurer si vous utilisez le système SMS

@applebp.route('/')
def hello():
    return jsonify({"message": "Hello from Apple Auth API"})
# ========== ENDPOINT 1 : LOGIN/REGISTER APPLE ==========
@applebp.route('/apple/login', methods=['POST'])
def apple_login():
    """
    Endpoint pour connexion/inscription avec Apple
    - Si utilisateur existe (apple_user_id trouvé) → Login (200)
    - Si nouvel utilisateur → Inscription partielle (201) avec completion_token
    """
    try:
        data = request.get_json()

        # Récupérer les données Apple
        apple_user_id = data.get('apple_user_id')  # Identifiant unique Apple
        identity_token = data.get('identity_token')  # Token JWT Apple
        authorization_code = data.get('authorization_code')  # Code d'autorisation
        email = data.get('email')  # Email (peut être masqué @privaterelay.appleid.com)
        given_name = data.get('given_name')  # Prénom (seulement 1ère fois)
        family_name = data.get('family_name')  # Nom (seulement 1ère fois)
        provider = data.get('provider', 'apk')

        # Validation des données requises
        if not apple_user_id:
            return jsonify({
                "Code": 400,
                "messages": "apple_user_id est requis"
            }), 400

        # 1. VÉRIFIER SI L'UTILISATEUR EXISTE DÉJÀ
        existing_user = client.APK_ARCHIVE.Users.find_one({
            "apple_user_id": apple_user_id,
            "check_verif": True
        })

        if existing_user:
            # ========== UTILISATEUR EXISTANT - LOGIN (200) ==========
            print(f"✅ [AppleAuth Backend] Utilisateur existant trouvé: {existing_user['nom']}")

            # Mise à jour de la dernière connexion
            client.APK_ARCHIVE.Users.update_one(
                {"apple_user_id": apple_user_id, "check_verif": True},
                {
                    "$set": {
                        "derniere_connexion": datetime.utcnow(),
                        "operating_system": provider
                    }
                }
            )

            # Préparer la réponse utilisateur (sans mot de passe)
            user_response = {
                "_id": str(existing_user["_id"]),
                "phone_number": existing_user.get("phone_number"),
                "nom": existing_user["nom"],
                "email": existing_user.get("email"),
                "role": existing_user.get("role", "utilisateur"),
                "secure_token": existing_user.get("secure_token"),
                "token": existing_user["token"],
                "check_verif": existing_user.get("check_verif", True),
                "operating_system": provider,
                "apple_user_id": existing_user["apple_user_id"]
            }

            return jsonify({
                "Code": 200,
                "messages": "Connexion Apple réussie",
                "token": existing_user["token"],
                "user": user_response,
                "zone_benef": existing_user.get("zone_benef", existing_user.get("country_name", "Congo")),
                "country_code": existing_user.get("country_code", "CG"),
                "zone_benef_code": existing_user.get("zone_benef_code", existing_user.get("country_code", "CG"))
            }), 200

        else:
            # ========== NOUVEL UTILISATEUR - INSCRIPTION PARTIELLE (201) ==========
            print(f"🆕 [AppleAuth Backend] Nouvel utilisateur Apple: {email}")

            # Générer un completion_token temporaire
            completion_token = secrets.token_urlsafe(32)

            # Construire le nom d'affichage
            if given_name and family_name:
                display_name = f"{given_name} {family_name}"
            elif given_name:
                display_name = given_name
            elif email:
                display_name = email.split('@')[0]
            else:
                display_name = "Utilisateur Apple"

            # Sauvegarder temporairement les données Apple (expiration 15 minutes)
            temp_apple_data = {
                "completion_token": completion_token,
                "apple_user_id": apple_user_id,
                "email": email,
                "given_name": given_name,
                "family_name": family_name,
                "display_name": display_name,
                "identity_token": identity_token,
                "authorization_code": authorization_code,
                "provider": provider,
                "created_at": datetime.utcnow()
            }

            # Insérer dans collection temporaire (ou Redis avec TTL)
            client.APK_ARCHIVE.AppleAuthTemp.insert_one(temp_apple_data)

            # Créer un index TTL pour auto-suppression après 15 minutes
            client.APK_ARCHIVE.AppleAuthTemp.create_index(
                "created_at",
                expireAfterSeconds=900  # 15 minutes
            )

            return jsonify({
                "Code": 201,
                "messages": "Finalisation du profil requise",
                "completion_token": completion_token,
                "user": {
                    "nom": display_name,
                    "email": email,
                    "apple_user_id": apple_user_id,
                    "given_name": given_name,
                    "family_name": family_name
                }
            }), 201

    except Exception as e:
        print(f"❌ [AppleAuth Backend] Erreur: {str(e)}")
        return jsonify({
            "Code": 500,
            "messages": f"Erreur serveur: {str(e)}"
        }), 500


# ========== ENDPOINT 2 : COMPLÉTION PROFIL APPLE ==========
@applebp.route('/apple/complete-profile', methods=['POST'])
def apple_complete_profile():
    """
    Endpoint pour finaliser l'inscription Apple avec numéro de téléphone
    """
    try:
        data = request.get_json()

        # Récupérer les données
        completion_token = data.get('completion_token')
        phone = data.get('phone')
        country_name = data.get('country_name', 'Congo')
        country_code = data.get('country_code', 'CG')
        zone_benef = data.get('zone_benef', country_name)
        zone_benef_code = data.get('zone_benef_code', country_code)
        provider = data.get('provider', 'apk')

        # Validation
        if not completion_token or not phone:
            return jsonify({
                "Code": 400,
                "messages": "completion_token et phone sont requis"
            }), 400

        # 1. RÉCUPÉRER LES DONNÉES APPLE TEMPORAIRES
        temp_data = client.APK_ARCHIVE.AppleAuthTemp.find_one({
            "completion_token": completion_token
        })

        if not temp_data:
            return jsonify({
                "Code": 400,
                "messages": "Token invalide ou expiré (15 minutes)"
            }), 400

        # 2. VÉRIFIER SI LE TÉLÉPHONE N'EST PAS DÉJÀ UTILISÉ
        existing_phone = client.APK_ARCHIVE.Users.find_one({
            "phone_number": phone,
            "check_verif": True
        })

        if existing_phone:
            # Supprimer les données temporaires
            client.APK_ARCHIVE.AppleAuthTemp.delete_one({"completion_token": completion_token})

            return jsonify({
                "Code": 409,
                "messages": "Ce numéro de téléphone est déjà enregistré."
            }), 409

        # 3. VÉRIFIER SI L'APPLE_USER_ID N'EST PAS DÉJÀ UTILISÉ
        existing_apple = client.APK_ARCHIVE.Users.find_one({
            "apple_user_id": temp_data["apple_user_id"],
            "check_verif": True
        })

        if existing_apple:
            # Supprimer les données temporaires
            client.APK_ARCHIVE.AppleAuthTemp.delete_one({"completion_token": completion_token})

            return jsonify({
                "Code": 409,
                "messages": "Ce compte Apple est déjà enregistré."
            }), 409

        # 4. CRÉER L'UTILISATEUR COMPLET
        secure_token = generate_secure_token_apk()  # Votre fonction existante
        nom = temp_data["display_name"]
        token = f"{secure_token}_-_{phone}_-_{nom}"
        token = urllib.parse.quote(token)

        user_document = {
            'phone_number': phone,
            'password': None,  # Pas de mot de passe pour Apple
            'nom': nom,
            'email': temp_data.get("email"),
            "miles": 10,
            'date_creation': datetime.utcnow(),
            'derniere_connexion': datetime.utcnow(),
            'role': 'utilisateur',
            'secure_token': secure_token,
            'token': token,
            'check_verif': True,
            "country_name": country_name,
            "zone_benef": zone_benef,
            "country_code": country_code,
            "zone_benef_code": zone_benef_code,
            'operating_system': provider,
            # Données Apple
            'apple_user_id': temp_data["apple_user_id"],
            'auth_provider': 'apple',
            'apple_email': temp_data.get("email"),
            'given_name': temp_data.get("given_name"),
            'family_name': temp_data.get("family_name")
        }

        # Insérer l'utilisateur
        result = client.APK_ARCHIVE.Users.insert_one(user_document)

        # Récupérer l'utilisateur créé
        created_user = client.APK_ARCHIVE.Users.find_one({"_id": result.inserted_id})

        # 5. SUPPRIMER LES DONNÉES TEMPORAIRES
        client.APK_ARCHIVE.AppleAuthTemp.delete_one({"completion_token": completion_token})

        # 6. PRÉPARER LA RÉPONSE
        user_response = {
            "_id": str(created_user["_id"]),
            "phone_number": created_user["phone_number"],
            "nom": created_user["nom"],
            "email": created_user.get("email"),
            "date_creation": created_user["date_creation"].isoformat(),
            "derniere_connexion": created_user["derniere_connexion"].isoformat(),
            "role": created_user["role"],
            "secure_token": created_user["secure_token"],
            "token": created_user["token"],
            "check_verif": created_user["check_verif"],
            "operating_system": created_user["operating_system"],
            "zone_benef": created_user.get("zone_benef"),
            "zone_benef_code": created_user.get("zone_benef_code"),
            "country_code": created_user["country_code"],
            "apple_user_id": created_user["apple_user_id"],
            "auth_provider": created_user["auth_provider"]
        }

        print(f"✅ [AppleAuth Backend] Utilisateur créé: {created_user['nom']} ({phone})")

        # 7. ENVOYER SMS DE BIENVENUE (optionnel)
        # Si vous voulez envoyer un SMS de bienvenue sans code de vérification
        # (car l'authentification Apple est déjà vérifiée)
        try:
            if re.match(regextel, phone.replace("+242", "")):
                # Décommenter et configurer BD_e2c pour activer les SMS
                # BD_e2c.e2c.sms_db.insert_one({
                #     "tel": phone.replace("+242", ""),
                #     "msg": f"Bienvenue sur Wortis {nom} ! Votre compte Apple a été créé avec succès.",
                #     "campagne": "APPLE SIGNIN"
                # })
                pass
        except Exception as sms_error:
            print(f"⚠️ [AppleAuth] SMS non envoyé: {str(sms_error)}")
            pass  # SMS non critique

        return jsonify({
            "Code": 200,
            "messages": "Inscription Apple finalisée avec succès",
            "token": token,
            "user": user_response,
            "process_normal": True
        }), 200

    except Exception as e:
        print(f"❌ [AppleAuth Backend] Erreur complétion: {str(e)}")
        return jsonify({
            "Code": 500,
            "messages": f"Erreur serveur: {str(e)}"
        }), 500


# ========== FONCTION UTILITAIRE (si elle n'existe pas déjà) ==========
def generate_secure_token_apk():
    """
    Génère un token sécurisé unique pour l'utilisateur
    (À adapter si vous avez déjà cette fonction)
    """
    return secrets.token_hex(16)  # 32 caractères hexadécimaux


# ========== MIGRATION : AJOUTER LE CHAMP apple_user_id AUX UTILISATEURS EXISTANTS ==========
# À exécuter une seule fois dans un script de migration
def migrate_add_apple_user_id():
    """
    Ajoute le champ apple_user_id à tous les utilisateurs existants (null par défaut)
    """
    try:
        result = client.APK_ARCHIVE.Users.update_many(
            {"apple_user_id": {"$exists": False}},
            {"$set": {"apple_user_id": None, "auth_provider": "phone"}}
        )
        print(f"✅ Migration: {result.modified_count} utilisateurs mis à jour")
    except Exception as e:
        print(f"❌ Erreur migration: {str(e)}")
