# Flask routes for ReservationService with Payment
# Integrate these routes into your existing Flask backend

from flask import request, jsonify
from datetime import datetime
from bson import ObjectId
import re

# Add these routes to your catalog_apk_bp Blueprint
# Make sure to import: from bson import ObjectId

@catalog_apk_bp.route('/api/bookings/create-reservation', methods=['POST'])
def create_reservation():
    """
    Create a new reservation with payment

    Expected JSON body:
    {
        "date": "2024-02-15",
        "timeSlot": "14:00-15:00",
        "prestation": "coupe_homme",
        "variant": "courte" (optional),
        "nom": "Jean Dupont",
        "telephone": "+242065551234",
        "adresse": "123 Rue de la Paix, Brazzaville",
        "commentaire": "Instructions particulières" (optional),
        "service_name": "Coiffure",
        "service_id": "65f8a2b3c4d5e6f7a8b9c0d3",
        "amount": 5000,
        "payment_method": "MTN_MONEY",
        "payment_reference": "REF123456789" (optional, généré par le système de paiement)
    }
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

        # Validation du nom (non vide)
        if not data['nom'].strip():
            return jsonify({
                'success': False,
                'error': 'Le nom est requis'
            }), 400

        # Validation du numéro de téléphone (format simple)
        phone_pattern = r'^[\+\d][\d\s\-\(\)]{6,}$'
        if not re.match(phone_pattern, data['telephone']):
            return jsonify({
                'success': False,
                'error': 'Format de numéro de téléphone invalide'
            }), 400

        # Validation de l'adresse (non vide)
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
        existing_booking = db['bookings'].find_one({
            'date': data['date'],
            'timeSlot': data['timeSlot'].strip(),
            'service_name': data['service_name'],
            'status': {'$in': ['confirmed', 'pending_payment']},
            'payment_status': {'$ne': 'failed'}  # Ne pas bloquer les créneaux avec paiement échoué
        })

        if existing_booking:
            return jsonify({
                'success': False,
                'error': 'Ce créneau est déjà réservé. Veuillez choisir un autre créneau.'
            }), 409

        # Créer le document de réservation avec status pending_payment
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
            'service_id': data.get('service_id'),
            'amount': amount,
            'payment_method': data.get('payment_method', 'MTN_MONEY'),
            'payment_reference': data.get('payment_reference'),
            'payment_status': 'pending',  # pending, successful, failed
            'status': 'pending_payment',  # pending_payment, confirmed, cancelled
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }

        # Insérer dans MongoDB
        result = db['bookings'].insert_one(reservation)

        # Préparer la réponse
        reservation['_id'] = str(result.inserted_id)
        reservation['created_at'] = reservation['created_at'].isoformat()
        reservation['updated_at'] = reservation['updated_at'].isoformat()

        return jsonify({
            'success': True,
            'message': 'Réservation créée. En attente de paiement.',
            'reservation': reservation,
            'booking_id': str(result.inserted_id),
            'requires_payment': True,
            'amount': amount
        }), 201

    except Exception as e:
        print(f"Erreur lors de la création de la réservation: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Erreur serveur lors de la création de la réservation'
        }), 500


@catalog_apk_bp.route('/api/bookings/confirm-payment', methods=['POST'])
def confirm_payment():
    """
    Confirm payment for a reservation
    Called after successful payment from mobile money provider

    Expected JSON body:
    {
        "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
        "payment_reference": "REF123456789",
        "payment_status": "SUCCESSFUL",
        "transaction_id": "TXN987654321" (optional)
    }
    """
    try:
        data = request.get_json()

        if not data.get('booking_id') or not data.get('payment_reference'):
            return jsonify({
                'success': False,
                'error': 'booking_id et payment_reference sont requis'
            }), 400

        # Vérifier que la réservation existe
        try:
            booking_id = ObjectId(data['booking_id'])
        except:
            return jsonify({
                'success': False,
                'error': 'ID de réservation invalide'
            }), 400

        booking = db['bookings'].find_one({'_id': booking_id})

        if not booking:
            return jsonify({
                'success': False,
                'error': 'Réservation non trouvée'
            }), 404

        # Vérifier que le paiement n'est pas déjà confirmé
        if booking.get('payment_status') == 'successful':
            return jsonify({
                'success': True,
                'message': 'Paiement déjà confirmé',
                'booking': {
                    '_id': str(booking['_id']),
                    'status': booking['status'],
                    'payment_status': booking['payment_status']
                }
            }), 200

        # Mettre à jour le statut du paiement
        payment_status = data.get('payment_status', 'SUCCESSFUL')

        if payment_status in ['SUCCESSFUL', 'SUCCESS', '200']:
            update_data = {
                'payment_status': 'successful',
                'status': 'confirmed',
                'payment_reference': data['payment_reference'],
                'transaction_id': data.get('transaction_id'),
                'payment_confirmed_at': datetime.utcnow(),
                'updated_at': datetime.utcnow()
            }
            new_status = 'confirmed'
        else:
            update_data = {
                'payment_status': 'failed',
                'status': 'cancelled',
                'payment_reference': data['payment_reference'],
                'transaction_id': data.get('transaction_id'),
                'payment_failed_at': datetime.utcnow(),
                'updated_at': datetime.utcnow()
            }
            new_status = 'cancelled'

        db['bookings'].update_one(
            {'_id': booking_id},
            {'$set': update_data}
        )

        return jsonify({
            'success': True,
            'message': 'Paiement confirmé' if new_status == 'confirmed' else 'Paiement échoué',
            'booking_id': str(booking_id),
            'status': new_status,
            'payment_status': update_data['payment_status']
        }), 200

    except Exception as e:
        print(f"Erreur lors de la confirmation du paiement: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Erreur serveur lors de la confirmation du paiement'
        }), 500


@catalog_apk_bp.route('/api/bookings/check-payment/<booking_id>', methods=['GET'])
def check_payment_status(booking_id):
    """
    Check payment status for a booking
    Used to poll payment status after initiating payment

    Returns:
    {
        "success": true,
        "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
        "payment_status": "successful",
        "status": "confirmed"
    }
    """
    try:
        # Vérifier que la réservation existe
        try:
            booking_oid = ObjectId(booking_id)
        except:
            return jsonify({
                'success': False,
                'error': 'ID de réservation invalide'
            }), 400

        booking = db['bookings'].find_one({'_id': booking_oid})

        if not booking:
            return jsonify({
                'success': False,
                'error': 'Réservation non trouvée'
            }), 404

        return jsonify({
            'success': True,
            'booking_id': str(booking['_id']),
            'payment_status': booking.get('payment_status', 'pending'),
            'status': booking.get('status', 'pending_payment'),
            'amount': booking.get('amount'),
            'payment_reference': booking.get('payment_reference'),
            'transaction_id': booking.get('transaction_id')
        }), 200

    except Exception as e:
        print(f"Erreur lors de la vérification du paiement: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Erreur serveur'
        }), 500


@catalog_apk_bp.route('/api/bookings/occupied-slots', methods=['GET'])
def get_occupied_slots():
    """
    Get occupied time slots for a specific date and service
    Only returns slots with confirmed or pending_payment status (not cancelled or failed)

    Query parameters:
    - date: Date in format YYYY-MM-DD (required)
    - service: Service name (required)

    Returns:
    {
        "success": true,
        "date": "2024-02-15",
        "service": "Coiffure",
        "occupied_slots": ["08:00-09:00", "14:00-15:00"],
        "total_occupied": 2
    }
    """
    try:
        date = request.args.get('date')
        service = request.args.get('service')

        # Validation des paramètres
        if not date or not service:
            return jsonify({
                'success': False,
                'occupied_slots': [],
                'error': 'Paramètres manquants: date et service sont requis'
            }), 400

        # Validation du format de date
        try:
            datetime.strptime(date, '%Y-%m-%d')
        except ValueError:
            return jsonify({
                'success': False,
                'occupied_slots': [],
                'error': 'Format de date invalide. Utilisez YYYY-MM-DD'
            }), 400

        # Récupérer les réservations confirmées et en attente de paiement
        # Exclure les réservations annulées et avec paiement échoué
        bookings = db['bookings'].find({
            'date': date,
            'service_name': service,
            'status': {'$in': ['confirmed', 'pending_payment']},
            'payment_status': {'$ne': 'failed'}
        })

        # Extraire les créneaux horaires
        occupied_slots = [booking['timeSlot'].strip() for booking in bookings]

        return jsonify({
            'success': True,
            'date': date,
            'service': service,
            'occupied_slots': occupied_slots,
            'total_occupied': len(occupied_slots)
        }), 200

    except Exception as e:
        print(f"Erreur lors de la récupération des créneaux occupés: {str(e)}")
        return jsonify({
            'success': False,
            'occupied_slots': [],
            'error': 'Erreur serveur'
        }), 500


@catalog_apk_bp.route('/api/bookings/cancel', methods=['POST'])
def cancel_reservation():
    """
    Cancel a reservation

    Expected JSON body:
    {
        "booking_id": "65f8a2b3c4d5e6f7a8b9c0d3",
        "telephone": "+242065551234"
    }
    """
    try:
        data = request.get_json()

        if not data.get('booking_id') or not data.get('telephone'):
            return jsonify({
                'success': False,
                'error': 'booking_id et telephone sont requis'
            }), 400

        # Vérifier que la réservation existe et appartient à l'utilisateur
        try:
            booking_id = ObjectId(data['booking_id'])
        except:
            return jsonify({
                'success': False,
                'error': 'ID de réservation invalide'
            }), 400

        booking = db['bookings'].find_one({
            '_id': booking_id,
            'telephone': data['telephone']
        })

        if not booking:
            return jsonify({
                'success': False,
                'error': 'Réservation non trouvée ou numéro de téléphone incorrect'
            }), 404

        # Vérifier que la réservation peut être annulée (pas déjà annulée)
        if booking.get('status') == 'cancelled':
            return jsonify({
                'success': False,
                'error': 'Cette réservation est déjà annulée'
            }), 400

        # Mettre à jour le statut
        db['bookings'].update_one(
            {'_id': booking_id},
            {
                '$set': {
                    'status': 'cancelled',
                    'cancelled_at': datetime.utcnow(),
                    'updated_at': datetime.utcnow()
                }
            }
        )

        return jsonify({
            'success': True,
            'message': 'Réservation annulée avec succès'
        }), 200

    except Exception as e:
        print(f"Erreur lors de l'annulation de la réservation: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Erreur serveur lors de l\'annulation'
        }), 500


@catalog_apk_bp.route('/api/bookings/user/<telephone>', methods=['GET'])
def get_user_bookings(telephone):
    """
    Get all bookings for a specific user by phone number

    Returns:
    {
        "success": true,
        "bookings": [...],
        "total": 5
    }
    """
    try:
        # Validation du numéro de téléphone
        phone_pattern = r'^[\+\d][\d\s\-\(\)]{6,}$'
        if not re.match(phone_pattern, telephone):
            return jsonify({
                'success': False,
                'bookings': [],
                'error': 'Format de numéro de téléphone invalide'
            }), 400

        # Récupérer les réservations de l'utilisateur
        bookings = list(db['bookings'].find({'telephone': telephone}).sort('date', -1))

        # Convertir ObjectId en string
        for booking in bookings:
            booking['_id'] = str(booking['_id'])
            if 'created_at' in booking:
                booking['created_at'] = booking['created_at'].isoformat()
            if 'updated_at' in booking:
                booking['updated_at'] = booking['updated_at'].isoformat()
            if 'cancelled_at' in booking:
                booking['cancelled_at'] = booking['cancelled_at'].isoformat()
            if 'payment_confirmed_at' in booking:
                booking['payment_confirmed_at'] = booking['payment_confirmed_at'].isoformat()
            if 'payment_failed_at' in booking:
                booking['payment_failed_at'] = booking['payment_failed_at'].isoformat()

        return jsonify({
            'success': True,
            'bookings': bookings,
            'total': len(bookings)
        }), 200

    except Exception as e:
        print(f"Erreur lors de la récupération des réservations: {str(e)}")
        return jsonify({
            'success': False,
            'bookings': [],
            'error': 'Erreur serveur'
        }), 500
