from flask import Flask, request, jsonify
import requests
from bson import ObjectId
from datetime import datetime

@app.route('/vival/checkout', methods=['POST'])
def vival_checkout():
    """
    Route pour gérer le paiement et l'enregistrement de commande Vival

    Payload attendu:
    {
        "montant": 5000,
        "momo": "242066985554",
        "name": "John Doe",
        "mobile": "242066985554",
        "adresse": "Brazzaville, Congo",
        "nom": "John Doe",
        "commande": {
            "67890abc_1": {"nom": "Eau Vival 1.5L", "prix": 500, "quantite": 2},
            "67890def_2": {"nom": "Coca Cola", "prix": 600, "quantite": 3}
        }
    }
    """
    data = request.json

    # Validation des champs obligatoires
    required_fields = ['montant', 'momo', 'name', 'mobile', 'adresse', 'nom', 'commande']
    missing_fields = [field for field in required_fields if field not in data]

    if missing_fields:
        return jsonify({
            'error': f'Champs manquants: {", ".join(missing_fields)}'
        }), 400

    # Validation de la commande
    if not validate_commandes_vival(data.get('commande', {})):
        return jsonify({'msg': 'Données de commande invalides'}), 400

    # Étape 1: Déclencher le paiement via WortisPay
    try:
        payment_data = {
            "numc": "4b851209-4de0-4581-9eb5-2225f9925d12",
            "montant": data['montant'],
            "numPaid": data['momo'],
            "typeVersement": "Commande Vival",
            "name": data['name']
        }

        print(f"[VIVAL] Déclenchement du paiement pour {data['name']} - Montant: {data['montant']}")

        payment_response = requests.post(
            'https://wortispay.com/api/paiement/json',
            json=payment_data,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )

        payment_result = payment_response.json()

        print(f"[VIVAL] Réponse paiement: {payment_result}")

        # Vérifier si le paiement a été initié avec succès
        if payment_response.status_code != 200:
            return jsonify({
                'error': 'Échec du déclenchement du paiement',
                'details': payment_result
            }), 400

        # Extraire le transID du paiement
        trans_id = payment_result.get('transID') or payment_result.get('transaction_id') or payment_result.get('id')

        if not trans_id:
            # Si l'API ne retourne pas de transID, en générer un
            trans_id = f"VIVAL_{datetime.now().strftime('%Y%m%d%H%M%S')}_{data['momo'][-4:]}"
            print(f"[VIVAL] Aucun transID retourné, génération: {trans_id}")

    except requests.exceptions.Timeout:
        return jsonify({
            'error': 'Délai d\'attente dépassé lors du paiement'
        }), 504
    except requests.exceptions.RequestException as e:
        print(f"[VIVAL] Erreur paiement: {str(e)}")
        return jsonify({
            'error': 'Erreur lors de la communication avec le service de paiement',
            'details': str(e)
        }), 500

    # Étape 2: Enregistrer la commande dans MongoDB
    try:
        order_data = {
            'transID': trans_id,
            'mobile': data['mobile'],
            'adresse': data['adresse'],
            'nom': data['nom'],
            'commande': data['commande'],
            'montant': data['montant'],
            'payment_status': payment_result.get('status', 'pending'),
            'payment_response': payment_result,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }

        result = euroshop_db.vival.insert_one(order_data)

        print(f"[VIVAL] Commande enregistrée avec ID: {result.inserted_id}")

        return jsonify({
            'code': 200,
            'message': 'Paiement initié et commande enregistrée avec succès',
            'transID': trans_id,
            'order_id': str(result.inserted_id),
            'payment_details': payment_result
        }), 201

    except Exception as e:
        print(f"[VIVAL] Erreur enregistrement: {str(e)}")
        return jsonify({
            'error': 'Paiement initié mais erreur lors de l\'enregistrement de la commande',
            'transID': trans_id,
            'details': str(e)
        }), 500


@app.route('/vival', methods=['POST'])
def vival():
    """
    Route existante pour enregistrer directement une commande Vival
    (sans passer par le paiement)
    """
    data = request.json
    if 'transID' not in data or 'mobile' not in data or 'adresse' not in data or 'nom' not in data or 'commande' not in data:
        return jsonify({'error': 'Certains champs sont manquants'}), 400

    if not validate_commandes_vival(data.get('commande', {})):
        return jsonify({'msg': 'Données de commande invalides'}), 400

    try:
        data['created_at'] = datetime.utcnow()
        data['updated_at'] = datetime.utcnow()
        euroshop_db.vival.insert_one(data)
        return jsonify({'code': 200, 'message': 'Données insérées avec succès'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500


def validate_commandes_vival(commandes):
    """
    Valide que tous les produits de la commande existent dans la base de données
    """
    if not isinstance(commandes, dict) or len(commandes) == 0:
        print("[VIVAL] Commande vide ou format invalide")
        return False

    for cle, valeur in commandes.items():
        try:
            # Extraire l'ID du produit (format: "product_id_quantity")
            id_commande = cle.split("_")[0]

            # Valider que c'est un ObjectId valide
            if not ObjectId.is_valid(id_commande):
                print(f"[VIVAL] ObjectId invalide: {id_commande}")
                return False

            object_id = ObjectId(id_commande)

            # Vérifier que le produit existe dans le catalogue
            rep = euroshop_db.cat_vival.find_one({"_id": object_id})

            if not rep:
                print(f"[VIVAL] Produit non trouvé: {id_commande}")
                return False

            # Valider les données du produit dans la commande
            if not isinstance(valeur, dict):
                print(f"[VIVAL] Format de produit invalide pour: {cle}")
                return False

            # Vérifier les champs requis
            required_product_fields = ['nom', 'prix', 'quantite']
            for field in required_product_fields:
                if field not in valeur:
                    print(f"[VIVAL] Champ manquant '{field}' pour produit: {cle}")
                    return False

            print(f"[VIVAL] Produit validé: {valeur['nom']} x{valeur['quantite']}")

        except Exception as e:
            print(f"[VIVAL] Erreur validation produit {cle}: {str(e)}")
            return False

    return True


@app.route('/vival/payment/callback', methods=['POST'])
def vival_payment_callback():
    """
    Route de callback pour recevoir les mises à jour de statut de paiement
    """
    data = request.json

    if 'transID' not in data:
        return jsonify({'error': 'transID manquant'}), 400

    try:
        # Mettre à jour le statut du paiement dans la commande
        update_result = euroshop_db.vival.update_one(
            {'transID': data['transID']},
            {
                '$set': {
                    'payment_status': data.get('status', 'unknown'),
                    'payment_callback': data,
                    'updated_at': datetime.utcnow()
                }
            }
        )

        if update_result.matched_count == 0:
            return jsonify({
                'error': 'Commande non trouvée',
                'transID': data['transID']
            }), 404

        print(f"[VIVAL] Callback reçu pour {data['transID']}: {data.get('status')}")

        return jsonify({
            'code': 200,
            'message': 'Statut de paiement mis à jour'
        }), 200

    except Exception as e:
        print(f"[VIVAL] Erreur callback: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/vival/orders/<order_id>', methods=['GET'])
def get_vival_order(order_id):
    """
    Récupérer les détails d'une commande Vival
    """
    try:
        if not ObjectId.is_valid(order_id):
            return jsonify({'error': 'ID de commande invalide'}), 400

        order = euroshop_db.vival.find_one({'_id': ObjectId(order_id)})

        if not order:
            return jsonify({'error': 'Commande non trouvée'}), 404

        # Convertir ObjectId en string pour la sérialisation JSON
        order['_id'] = str(order['_id'])
        if 'created_at' in order:
            order['created_at'] = order['created_at'].isoformat()
        if 'updated_at' in order:
            order['updated_at'] = order['updated_at'].isoformat()

        return jsonify(order), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
