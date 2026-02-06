@catalog_apk_bp.route('/api/bookings/create-reservation', methods=['POST'])
def create_reservation():
    """
    Create a new reservation with integrated payment
    """
    try:
        data = request.get_json()

        # Validation des champs requis
        required_fields = ['date', 'timeSlot', 'prestation', 'nom', 'telephone', 'adresse', 'service_name', 'amount']
        missing_fields = [field for field in required_fields if field not in data]

        if missing_fields:
            return jsonify({
                'success': False,
                'error': f'Champs manquants: {", ".join(missing_fields)}'
            }), 400

        # Validation du format de date
        try:
            reservation_date = datetime.strptime(data['date'], '%Y-%m-%d')
        except ValueError:
            return jsonify({
                'success': False,
                'error': 'Format de date invalide. Utilisez YYYY-MM-DD'
            }), 400

        # Vérifier que la date n'est pas dans le passé
        if reservation_date.date() < datetime.now().date():
            return jsonify({
                'success': False,
                'error': 'Impossible de réserver dans le passé'
            }), 400

        # Validation du format de créneau horaire
        time_slot_pattern = r'^\d{2}:\d{2}\s*-\s*\d{2}:\d{2}$'
        if not re.match(time_slot_pattern, data['timeSlot']):
            return jsonify({
                'success': False,
                'error': 'Format de créneau horaire invalide. Utilisez HH:MM-HH:MM'
            }), 400

        # Validation du nom
        if not data['nom'].strip():
            return jsonify({
                'success': False,
                'error': 'Le nom est requis'
            }), 400

        # Validation du numéro de téléphone
        phone_pattern = r'^[\+\d][\d\s\-\(\)]{6,}$'
        if not re.match(phone_pattern, data['telephone']):
            return jsonify({
                'success': False,
                'error': 'Format de numéro de téléphone invalide'
            }), 400

        # Validation de l'adresse
        if not data['adresse'].strip():
            return jsonify({
                'success': False,
                'error': 'L\'adresse est requise'
            }), 400

        # Validation du montant
        try:
            amount = float(data['amount'])
            if amount <= 0:
                return jsonify({
                    'success': False,
                    'error': 'Le montant doit être supérieur à 0'
                }), 400
        except (ValueError, TypeError):
            return jsonify({
                'success': False,
                'error': 'Format de montant invalide'
            }), 400

        # Vérifier si le créneau est déjà occupé
        existing_booking = db['bookings_apk'].find_one({
            'date': data['date'],
            'timeSlot': data['timeSlot'].strip(),
            'service_name': data['service_name'],
            'status': {'$in': ['confirmed', 'pending_payment']},
            'payment_status': {'$ne': 'failed'}
        })

        if existing_booking:
            return jsonify({
                'success': False,
                'error': 'Ce créneau est déjà réservé. Veuillez choisir un autre créneau.'
            }), 409

        # Récupérer le service pour obtenir le numc
        service = None
        if data.get('service_id'):
            try:
                service = services_collection.find_one({'_id': ObjectId(data['service_id'])})
            except:
                pass

        if not service:
            # Chercher par nom si pas d'ID
            service = services_collection.find_one({'name': data['service_name']})

        if not service:
            return jsonify({
                'success': False,
                'error': 'Service non trouvé'
            }), 404

        if not service.get('numc'):
            return jsonify({
                'success': False,
                'error': 'Configuration du service incomplète (numc manquant)'
            }), 400

        # ÉTAPE 1: Initier le paiement via WortisPay
        try:
            payment_data = {
                "numc": service["numc"],
                "montant": int(amount),
                "numPaid": data['telephone'],
                "typeVersement": f"Reservation APK {service['name']}",
                "name": data['nom'],
                "date": data['date'],
                "timeSlot": data['timeSlot'],
                "prestation": data['prestation'],
                "variant": data.get('variant'),
                "adresse": data['adresse'],
                "commentaire": data.get('commentaire', ''),
                "service_name": data['service_name']
            }

            print(f"🔄 Déclenchement du paiement pour {data['nom']} - Montant: {amount}")

            payment_response = requests.post(
                'https://wortispay.com/api/paiement/json',
                json=payment_data,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )

            payment_result = payment_response.json()
            print(f"✅ Réponse paiement: {payment_result}")

            # Vérifier si le paiement a été initié avec succès
            if payment_response.status_code != 200:
                return jsonify({
                    'success': False,
                    'error': 'Échec du déclenchement du paiement',
                    'details': payment_result
                }), 400

            # Extraire le transID
            trans_id = payment_result.get('transID') or payment_result.get('transaction_id') or payment_result.get('id')

            if not trans_id:
                # Générer un transID si l'API n'en retourne pas
                trans_id = f"BOOK_{datetime.now().strftime('%Y%m%d%H%M%S')}_{data['telephone'][-4:]}"
                print(f"⚠️ Aucun transID retourné, génération: {trans_id}")

        except requests.exceptions.Timeout:
            return jsonify({
                'success': False,
                'error': 'Délai d\'attente dépassé lors du paiement'
            }), 504

        except requests.exceptions.RequestException as e:
            print(f"❌ Erreur paiement: {str(e)}")
            return jsonify({
                'success': False,
                'error': 'Erreur lors de la communication avec le service de paiement',
                'details': str(e)
            }), 500

        # ÉTAPE 2: Créer la réservation avec le transID
        reservation = {
            'date': data['date'],
            'timeSlot': data['timeSlot'].strip(),
            'prestation': data['prestation'],
            'variant': data.get('variant'),
            'nom': data['nom'].strip(),
            'telephone': data['telephone'].strip(),
            'adresse': data['adresse'].strip(),
            'commentaire': data.get('commentaire', ''),
            'service_name': data['service_name'],
            'service_id': str(service['_id']),
            'amount': amount,
            'payment_method': data.get('payment_method', 'MTN_MONEY'),
            'payment_reference': trans_id,  # Le transID pour le checking
            'transID': trans_id,  # Aussi en tant que transID
            'payment_status': payment_result.get('status', 'pending'),
            'status': 'pending_payment',
            'payment_response': payment_result,  # Garder la réponse complète
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }

        # Insérer dans MongoDB
        result = db['bookings_apk'].insert_one(reservation)

        # Préparer la réponse
        reservation['_id'] = str(result.inserted_id)
        reservation['created_at'] = reservation['created_at'].isoformat()
        reservation['updated_at'] = reservation['updated_at'].isoformat()

        print(f"✅ Réservation créée: {result.inserted_id} avec transID: {trans_id}")

        return jsonify({
            'success': True,
            'code': 200,
            'message': 'Réservation créée et paiement initié avec succès',
            'reservation': reservation,
            'booking_id': str(result.inserted_id),
            'transID': trans_id,
            'clientTransID': trans_id,  # Pour compatibilité avec le système existant
            'requires_payment': True,
            'amount': amount,
            'payment_details': payment_result
        }), 201

    except Exception as e:
        print(f"❌ Erreur lors de la création de la réservation: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': 'Erreur serveur lors de la création de la réservation',
            'details': str(e)
        }), 500
