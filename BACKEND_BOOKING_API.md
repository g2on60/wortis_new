# API Backend - Enregistrement des Réservations

## 📋 Vue d'ensemble

Cette documentation fournit des exemples complets de code backend pour gérer les réservations du **ReservationService**.

## 📥 Données reçues du frontend

Le frontend envoie les données suivantes au format JSON :

```json
{
  "date": "2024-02-15",
  "timeSlot": "10:00-11:00",
  "prestation": "coupe_homme",
  "variant": "courte",
  "email": "client@example.com",
  "notes": "Préférence pour style moderne"
}
```

**Champs :**
- `date` : Date de réservation (YYYY-MM-DD)
- `timeSlot` : Créneau horaire (HH:MM-HH:MM)
- `prestation` : ID de la prestation
- `variant` : ID de la variante (optionnel)
- `email` : Email du client
- `notes` : Instructions particulières (optionnel)
- **Autres champs** : Selon votre configuration JSON

---

## 🛢️ Structure de la base de données

### MongoDB

```javascript
{
  _id: ObjectId("..."),
  service: "Coiffure Hommes",
  date: "2024-02-15",
  timeSlot: "10:00-11:00",
  prestation: "coupe_homme",
  variant: "courte",
  email: "client@example.com",
  notes: "Préférence pour style moderne",
  price: 5000,
  status: "confirmed", // confirmed, pending, cancelled, completed
  createdAt: ISODate("2024-02-06T10:00:00Z"),
  updatedAt: ISODate("2024-02-06T10:00:00Z")
}
```

### PostgreSQL / MySQL

```sql
CREATE TABLE bookings (
    id SERIAL PRIMARY KEY,
    service VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    time_slot VARCHAR(20) NOT NULL,
    prestation VARCHAR(100) NOT NULL,
    variant VARCHAR(100),
    email VARCHAR(255) NOT NULL,
    notes TEXT,
    price INTEGER,
    status VARCHAR(20) DEFAULT 'confirmed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(service, date, time_slot)
);

-- Index pour améliorer les performances
CREATE INDEX idx_bookings_date ON bookings(date);
CREATE INDEX idx_bookings_service ON bookings(service);
CREATE INDEX idx_bookings_email ON bookings(email);
```

---

## 💻 Node.js / Express + MongoDB

### Installation

```bash
npm install express mongoose cors dotenv nodemailer
```

### Modèle MongoDB (models/Booking.js)

```javascript
const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({
  service: {
    type: String,
    required: true,
    index: true
  },
  date: {
    type: String,
    required: true,
    index: true
  },
  timeSlot: {
    type: String,
    required: true
  },
  prestation: {
    type: String,
    required: true
  },
  variant: {
    type: String,
    default: null
  },
  email: {
    type: String,
    required: true,
    lowercase: true,
    trim: true
  },
  notes: {
    type: String,
    default: ''
  },
  price: {
    type: Number,
    default: 0
  },
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'cancelled', 'completed'],
    default: 'confirmed'
  }
}, {
  timestamps: true
});

// Index composé pour éviter les réservations en double
bookingSchema.index({ service: 1, date: 1, timeSlot: 1 }, { unique: true });

module.exports = mongoose.model('Booking', bookingSchema);
```

### Route API (routes/bookings.js)

```javascript
const express = require('express');
const router = express.Router();
const Booking = require('../models/Booking');
const nodemailer = require('nodemailer');

// Configuration de l'email (optionnel)
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: process.env.SMTP_PORT,
  secure: true,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS
  }
});

// POST /api/bookings/create-reservation
router.post('/create-reservation', async (req, res) => {
  try {
    const {
      service = 'Service inconnu',
      date,
      timeSlot,
      prestation,
      variant,
      email,
      notes,
      price
    } = req.body;

    // 1. Validation des données
    if (!date || !timeSlot || !prestation || !email) {
      return res.status(400).json({
        success: false,
        message: 'Données manquantes. Veuillez fournir la date, le créneau, la prestation et l\'email.'
      });
    }

    // Validation du format de la date
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(date)) {
      return res.status(400).json({
        success: false,
        message: 'Format de date invalide. Utilisez YYYY-MM-DD.'
      });
    }

    // Validation de l'email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Format d\'email invalide.'
      });
    }

    // 2. Vérifier que le créneau n'est pas déjà réservé
    const existingBooking = await Booking.findOne({
      service,
      date,
      timeSlot,
      status: { $in: ['confirmed', 'pending'] }
    });

    if (existingBooking) {
      return res.status(409).json({
        success: false,
        message: 'Ce créneau est déjà réservé. Veuillez choisir un autre créneau.',
        occupiedSlot: timeSlot
      });
    }

    // 3. Créer la réservation
    const booking = new Booking({
      service,
      date,
      timeSlot,
      prestation,
      variant,
      email,
      notes,
      price,
      status: 'confirmed'
    });

    await booking.save();

    // 4. Envoyer email de confirmation (optionnel)
    try {
      await sendConfirmationEmail(booking);
    } catch (emailError) {
      console.error('Erreur envoi email:', emailError);
      // Continue même si l'email échoue
    }

    // 5. Réponse de succès
    res.status(201).json({
      success: true,
      message: 'Réservation confirmée avec succès !',
      booking: {
        id: booking._id,
        service: booking.service,
        date: booking.date,
        timeSlot: booking.timeSlot,
        prestation: booking.prestation,
        variant: booking.variant,
        email: booking.email,
        status: booking.status
      }
    });

  } catch (error) {
    console.error('Erreur lors de la création de la réservation:', error);

    // Gestion des erreurs de duplication
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'Ce créneau est déjà réservé.'
      });
    }

    res.status(500).json({
      success: false,
      message: 'Erreur lors de la création de la réservation.',
      error: error.message
    });
  }
});

// GET /api/bookings/occupied-slots?date=YYYY-MM-DD&service=ServiceName
router.get('/occupied-slots', async (req, res) => {
  try {
    const { date, service } = req.query;

    if (!date || !service) {
      return res.status(400).json({
        success: false,
        message: 'Paramètres manquants: date et service requis.'
      });
    }

    // Récupérer tous les créneaux occupés pour cette date et ce service
    const bookings = await Booking.find({
      service,
      date,
      status: { $in: ['confirmed', 'pending'] }
    }).select('timeSlot');

    const occupiedSlots = bookings.map(booking => booking.timeSlot);

    res.json({
      success: true,
      date,
      service,
      occupied_slots: occupiedSlots,
      total_occupied: occupiedSlots.length
    });

  } catch (error) {
    console.error('Erreur lors de la récupération des créneaux occupés:', error);
    res.status(500).json({
      success: false,
      occupied_slots: [],
      error: error.message
    });
  }
});

// Fonction d'envoi d'email de confirmation
async function sendConfirmationEmail(booking) {
  const mailOptions = {
    from: `"${booking.service}" <${process.env.SMTP_USER}>`,
    to: booking.email,
    subject: `Confirmation de réservation - ${booking.service}`,
    html: `
      <h2>Réservation confirmée !</h2>
      <p>Bonjour,</p>
      <p>Votre réservation a été confirmée avec succès.</p>

      <h3>Détails de la réservation :</h3>
      <ul>
        <li><strong>Service :</strong> ${booking.service}</li>
        <li><strong>Date :</strong> ${new Date(booking.date).toLocaleDateString('fr-FR')}</li>
        <li><strong>Heure :</strong> ${booking.timeSlot}</li>
        <li><strong>Prestation :</strong> ${booking.prestation}${booking.variant ? ` (${booking.variant})` : ''}</li>
        ${booking.price ? `<li><strong>Prix :</strong> ${booking.price.toLocaleString('fr-FR')} FCFA</li>` : ''}
      </ul>

      ${booking.notes ? `<p><strong>Notes :</strong> ${booking.notes}</p>` : ''}

      <p>Merci pour votre confiance !</p>
    `
  };

  return await transporter.sendMail(mailOptions);
}

module.exports = router;
```

### Server.js

```javascript
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Connexion MongoDB
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => console.log('✅ MongoDB connecté'))
.catch(err => console.error('❌ Erreur MongoDB:', err));

// Routes
app.use('/api/bookings', require('./routes/bookings'));

// Démarrage du serveur
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Serveur démarré sur le port ${PORT}`);
});
```

### .env

```env
MONGODB_URI=mongodb://localhost:27017/bookings
PORT=3000

# Configuration SMTP (optionnel)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USER=votre-email@gmail.com
SMTP_PASS=votre-mot-de-passe-app
```

---

## 🐍 Python / Flask + MongoDB

### Installation

```bash
pip install flask flask-cors pymongo python-dotenv
```

### app.py

```python
from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
from datetime import datetime
import os
from dotenv import load_dotenv
import re

load_dotenv()

app = Flask(__name__)
CORS(app)

# Connexion MongoDB
client = MongoClient(os.getenv('MONGODB_URI', 'mongodb://localhost:27017/'))
db = client['bookings']
bookings_collection = db['bookings']

# Index unique pour éviter les doublons
bookings_collection.create_index([
    ('service', 1),
    ('date', 1),
    ('timeSlot', 1)
], unique=True)

@app.route('/api/bookings/create-reservation', methods=['POST'])
def create_reservation():
    try:
        data = request.get_json()

        # 1. Récupération des données
        service = data.get('service', 'Service inconnu')
        date = data.get('date')
        time_slot = data.get('timeSlot')
        prestation = data.get('prestation')
        variant = data.get('variant')
        email = data.get('email')
        notes = data.get('notes', '')
        price = data.get('price', 0)

        # 2. Validation
        if not all([date, time_slot, prestation, email]):
            return jsonify({
                'success': False,
                'message': 'Données manquantes'
            }), 400

        # Validation format date
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', date):
            return jsonify({
                'success': False,
                'message': 'Format de date invalide'
            }), 400

        # Validation email
        if not re.match(r'^[^\s@]+@[^\s@]+\.[^\s@]+$', email):
            return jsonify({
                'success': False,
                'message': 'Format d\'email invalide'
            }), 400

        # 3. Vérifier disponibilité
        existing = bookings_collection.find_one({
            'service': service,
            'date': date,
            'timeSlot': time_slot,
            'status': {'$in': ['confirmed', 'pending']}
        })

        if existing:
            return jsonify({
                'success': False,
                'message': 'Ce créneau est déjà réservé',
                'occupiedSlot': time_slot
            }), 409

        # 4. Créer la réservation
        booking = {
            'service': service,
            'date': date,
            'timeSlot': time_slot,
            'prestation': prestation,
            'variant': variant,
            'email': email.lower().strip(),
            'notes': notes,
            'price': price,
            'status': 'confirmed',
            'createdAt': datetime.utcnow(),
            'updatedAt': datetime.utcnow()
        }

        result = bookings_collection.insert_one(booking)

        # 5. Réponse
        return jsonify({
            'success': True,
            'message': 'Réservation confirmée avec succès !',
            'booking': {
                'id': str(result.inserted_id),
                'service': service,
                'date': date,
                'timeSlot': time_slot,
                'prestation': prestation,
                'variant': variant,
                'email': email,
                'status': 'confirmed'
            }
        }), 201

    except Exception as e:
        print(f'Erreur: {str(e)}')
        return jsonify({
            'success': False,
            'message': 'Erreur lors de la création de la réservation',
            'error': str(e)
        }), 500

@app.route('/api/bookings/occupied-slots', methods=['GET'])
def get_occupied_slots():
    try:
        date = request.args.get('date')
        service = request.args.get('service')

        if not date or not service:
            return jsonify({
                'success': False,
                'message': 'Paramètres manquants'
            }), 400

        # Récupérer les créneaux occupés
        bookings = bookings_collection.find({
            'service': service,
            'date': date,
            'status': {'$in': ['confirmed', 'pending']}
        }, {'timeSlot': 1})

        occupied_slots = [booking['timeSlot'] for booking in bookings]

        return jsonify({
            'success': True,
            'date': date,
            'service': service,
            'occupied_slots': occupied_slots,
            'total_occupied': len(occupied_slots)
        })

    except Exception as e:
        print(f'Erreur: {str(e)}')
        return jsonify({
            'success': False,
            'occupied_slots': [],
            'error': str(e)
        }), 500

if __name__ == '__main__':
    app.run(debug=True, port=3000)
```

---

## 🐘 PHP / Laravel

### Migration

```bash
php artisan make:migration create_bookings_table
```

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateBookingsTable extends Migration
{
    public function up()
    {
        Schema::create('bookings', function (Blueprint $table) {
            $table->id();
            $table->string('service');
            $table->date('date');
            $table->string('time_slot');
            $table->string('prestation');
            $table->string('variant')->nullable();
            $table->string('email');
            $table->text('notes')->nullable();
            $table->integer('price')->default(0);
            $table->enum('status', ['pending', 'confirmed', 'cancelled', 'completed'])
                  ->default('confirmed');
            $table->timestamps();

            // Index unique pour éviter les doublons
            $table->unique(['service', 'date', 'time_slot']);

            // Index pour améliorer les performances
            $table->index('date');
            $table->index('service');
            $table->index('email');
        });
    }

    public function down()
    {
        Schema::dropIfExists('bookings');
    }
}
```

### Modèle (app/Models/Booking.php)

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Booking extends Model
{
    protected $fillable = [
        'service',
        'date',
        'time_slot',
        'prestation',
        'variant',
        'email',
        'notes',
        'price',
        'status'
    ];

    protected $casts = [
        'date' => 'date',
        'price' => 'integer'
    ];
}
```

### Controller (app/Http/Controllers/BookingController.php)

```php
<?php

namespace App\Http\Controllers;

use App\Models\Booking;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class BookingController extends Controller
{
    public function createReservation(Request $request)
    {
        // 1. Validation
        $validator = Validator::make($request->all(), [
            'date' => 'required|date_format:Y-m-d',
            'timeSlot' => 'required|string',
            'prestation' => 'required|string',
            'email' => 'required|email',
            'service' => 'nullable|string',
            'variant' => 'nullable|string',
            'notes' => 'nullable|string',
            'price' => 'nullable|integer'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Données invalides',
                'errors' => $validator->errors()
            ], 400);
        }

        try {
            // 2. Vérifier disponibilité
            $existing = Booking::where('service', $request->input('service', 'Service inconnu'))
                ->where('date', $request->date)
                ->where('time_slot', $request->timeSlot)
                ->whereIn('status', ['confirmed', 'pending'])
                ->first();

            if ($existing) {
                return response()->json([
                    'success' => false,
                    'message' => 'Ce créneau est déjà réservé',
                    'occupiedSlot' => $request->timeSlot
                ], 409);
            }

            // 3. Créer la réservation
            $booking = Booking::create([
                'service' => $request->input('service', 'Service inconnu'),
                'date' => $request->date,
                'time_slot' => $request->timeSlot,
                'prestation' => $request->prestation,
                'variant' => $request->variant,
                'email' => strtolower(trim($request->email)),
                'notes' => $request->notes,
                'price' => $request->input('price', 0),
                'status' => 'confirmed'
            ]);

            // 4. Envoyer email de confirmation (optionnel)
            // Mail::to($booking->email)->send(new BookingConfirmation($booking));

            // 5. Réponse
            return response()->json([
                'success' => true,
                'message' => 'Réservation confirmée avec succès !',
                'booking' => [
                    'id' => $booking->id,
                    'service' => $booking->service,
                    'date' => $booking->date->format('Y-m-d'),
                    'timeSlot' => $booking->time_slot,
                    'prestation' => $booking->prestation,
                    'variant' => $booking->variant,
                    'email' => $booking->email,
                    'status' => $booking->status
                ]
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Erreur lors de la création de la réservation',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function getOccupiedSlots(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'date' => 'required|date_format:Y-m-d',
            'service' => 'required|string'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Paramètres manquants'
            ], 400);
        }

        try {
            $bookings = Booking::where('service', $request->service)
                ->where('date', $request->date)
                ->whereIn('status', ['confirmed', 'pending'])
                ->pluck('time_slot');

            return response()->json([
                'success' => true,
                'date' => $request->date,
                'service' => $request->service,
                'occupied_slots' => $bookings,
                'total_occupied' => $bookings->count()
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'occupied_slots' => [],
                'error' => $e->getMessage()
            ], 500);
        }
    }
}
```

### Routes (routes/api.php)

```php
<?php

use App\Http\Controllers\BookingController;
use Illuminate\Support\Facades\Route;

Route::prefix('bookings')->group(function () {
    Route::post('/create-reservation', [BookingController::class, 'createReservation']);
    Route::get('/occupied-slots', [BookingController::class, 'getOccupiedSlots']);
});
```

---

## 📧 Email de confirmation (optionnel)

### Template HTML

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #6366F1; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f9f9f9; }
        .details { background: white; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .footer { text-align: center; padding: 20px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>✅ Réservation confirmée</h1>
        </div>
        <div class="content">
            <p>Bonjour,</p>
            <p>Votre réservation a été confirmée avec succès !</p>

            <div class="details">
                <h3>Détails de votre réservation :</h3>
                <p><strong>📅 Date :</strong> {{date}}</p>
                <p><strong>🕐 Heure :</strong> {{timeSlot}}</p>
                <p><strong>✂️ Prestation :</strong> {{prestation}}</p>
                <p><strong>💰 Prix :</strong> {{price}} FCFA</p>
            </div>

            <p>Merci pour votre confiance !</p>
        </div>
        <div class="footer">
            <p>Cet email a été envoyé automatiquement, merci de ne pas y répondre.</p>
        </div>
    </div>
</body>
</html>
```

---

## 🧪 Test avec Postman / cURL

### Créer une réservation

```bash
curl -X POST https://api.live.wortis.cg/api/bookings/create-reservation \
  -H "Content-Type: application/json" \
  -d '{
    "service": "Coiffure Hommes",
    "date": "2024-02-15",
    "timeSlot": "10:00-11:00",
    "prestation": "coupe_homme",
    "variant": "courte",
    "email": "client@example.com",
    "notes": "Préférence pour style moderne",
    "price": 5000
  }'
```

### Récupérer les créneaux occupés

```bash
curl -X GET "https://api.live.wortis.cg/api/bookings/occupied-slots?date=2024-02-15&service=Coiffure%20Hommes"
```

---

## ✅ Checklist de déploiement

- [ ] Base de données configurée
- [ ] Variables d'environnement (.env) configurées
- [ ] Index de base de données créés
- [ ] Tests des endpoints réalisés
- [ ] Gestion des erreurs complète
- [ ] Logs configurés
- [ ] Email de confirmation configuré (optionnel)
- [ ] CORS configuré pour le domaine frontend
- [ ] HTTPS activé en production

---

**Version :** 1.0
**Date :** 2026-02-06
**Auteur :** Claude Sonnet 4.5
