# Guide des Créneaux Occupés - ReservationService

## 📅 Vue d'ensemble

Le système de créneaux occupés permet de **masquer automatiquement** les créneaux déjà réservés ou indisponibles. Le système supporte deux sources :

1. **Créneaux bloqués statiques** dans le JSON (fermetures exceptionnelles, maintenance, etc.)
2. **API dynamique** pour les réservations en temps réel

---

## 🎯 Fonctionnement

Quand l'utilisateur sélectionne une date :
1. Le système récupère tous les créneaux disponibles pour ce jour
2. Il récupère les créneaux occupés (JSON + API)
3. Il **filtre automatiquement** les créneaux occupés
4. L'utilisateur ne voit **que les créneaux disponibles** ✅

---

## 🔧 Configuration JSON

### Option 1 : Créneaux bloqués statiques uniquement

```json
{
  "availability": {
    "working_days": [1, 2, 3, 4, 5, 6],
    "excluded_days": [7],
    "time_slots": [
      "08:00-09:00",
      "09:00-10:00",
      "10:00-11:00",
      "11:00-12:00",
      "14:00-15:00",
      "15:00-16:00",
      "16:00-17:00",
      "17:00-18:00"
    ],
    "blocked_slots": {
      "2024-02-15": ["08:00-09:00", "14:00-15:00"],
      "2024-02-16": ["10:00-11:00", "11:00-12:00"],
      "2024-02-20": ["09:00-10:00"]
    }
  }
}
```

**Utilisation :**
- Fermetures exceptionnelles
- Jours fériés spécifiques
- Maintenance planifiée
- Événements spéciaux

### Option 2 : API dynamique uniquement

```json
{
  "availability": {
    "working_days": [1, 2, 3, 4, 5, 6],
    "excluded_days": [7],
    "time_slots": [
      "08:00-09:00",
      "09:00-10:00",
      "10:00-11:00",
      "11:00-12:00",
      "14:00-15:00",
      "15:00-16:00",
      "16:00-17:00",
      "17:00-18:00"
    ],
    "api_occupied_slots": "https://api.live.wortis.cg/api/bookings/occupied-slots?date={date}&service={service}"
  }
}
```

**Utilisation :**
- Réservations en temps réel
- Système de booking partagé
- Multi-utilisateurs

### Option 3 : Combinaison (Recommandé) ⭐

```json
{
  "availability": {
    "working_days": [1, 2, 3, 4, 5, 6],
    "excluded_days": [7],
    "time_slots": [
      "08:00-09:00",
      "09:00-10:00",
      "10:00-11:00",
      "11:00-12:00",
      "14:00-15:00",
      "15:00-16:00",
      "16:00-17:00",
      "17:00-18:00"
    ],
    "blocked_slots": {
      "2024-12-25": ["08:00-09:00", "09:00-10:00", "10:00-11:00", "11:00-12:00", "14:00-15:00", "15:00-16:00", "16:00-17:00", "17:00-18:00"],
      "2024-01-01": ["08:00-09:00", "09:00-10:00", "10:00-11:00", "11:00-12:00", "14:00-15:00", "15:00-16:00", "16:00-17:00", "17:00-18:00"]
    },
    "api_occupied_slots": "https://api.live.wortis.cg/api/bookings/occupied-slots?date={date}&service={service}"
  }
}
```

**Avantages :**
- ✅ Jours fériés bloqués dans le JSON (ne change pas)
- ✅ Réservations en temps réel via API (dynamique)
- ✅ Performance optimale

---

## 📝 Structure `blocked_slots`

### Format
```json
"blocked_slots": {
  "YYYY-MM-DD": ["HH:MM-HH:MM", "HH:MM-HH:MM", ...],
  "2024-02-15": ["08:00-09:00", "14:00-15:00"],
  "2024-02-16": ["10:00-11:00"]
}
```

### Règles
- **Clé** : Date au format `YYYY-MM-DD` (ISO 8601)
- **Valeur** : Tableau de créneaux au format `HH:MM-HH:MM`
- **Format** : Peut être `"08:00-09:00"` ou `"08:00 - 09:00"` (les deux fonctionnent)

### Exemples

**Bloquer toute une journée (jour férié) :**
```json
"blocked_slots": {
  "2024-12-25": [
    "08:00-09:00",
    "09:00-10:00",
    "10:00-11:00",
    "11:00-12:00",
    "14:00-15:00",
    "15:00-16:00",
    "16:00-17:00",
    "17:00-18:00"
  ]
}
```

**Bloquer seulement le matin :**
```json
"blocked_slots": {
  "2024-02-15": [
    "08:00-09:00",
    "09:00-10:00",
    "10:00-11:00",
    "11:00-12:00"
  ]
}
```

**Bloquer des créneaux spécifiques sur plusieurs jours :**
```json
"blocked_slots": {
  "2024-02-15": ["08:00-09:00", "14:00-15:00"],
  "2024-02-16": ["10:00-11:00"],
  "2024-02-17": ["09:00-10:00", "15:00-16:00"]
}
```

---

## 🌐 API des Créneaux Occupés

### URL de l'API

```json
"api_occupied_slots": "https://api.live.wortis.cg/api/bookings/occupied-slots?date={date}&service={service}"
```

**Paramètres disponibles :**
- `{date}` : Remplacé par la date sélectionnée au format `YYYY-MM-DD`
- `{service}` : Remplacé par le nom du service (encodé pour URL)

### Format de la requête

**GET** `https://api.live.wortis.cg/api/bookings/occupied-slots?date=2024-02-15&service=Coiffure%20Hommes`

### Format de la réponse

L'API doit retourner un JSON avec ce format :

```json
{
  "occupied_slots": [
    "08:00-09:00",
    "09:00-10:00",
    "14:00-15:00"
  ]
}
```

**Champs :**
- `occupied_slots` (requis) : Tableau de créneaux occupés

**Formats acceptés pour les créneaux :**
- `"08:00-09:00"` ✅
- `"08:00 - 09:00"` ✅
- `"08:00- 09:00"` ✅

Le système normalise automatiquement les formats.

### Exemple de réponse complète

```json
{
  "success": true,
  "date": "2024-02-15",
  "service": "Coiffure Hommes",
  "occupied_slots": [
    "08:00-09:00",
    "09:00-10:00",
    "14:00-15:00"
  ],
  "total_occupied": 3,
  "total_available": 5
}
```

**Note :** Seul le champ `occupied_slots` est obligatoire. Les autres champs sont optionnels.

---

## 💻 Implémentation Backend (Exemple)

### Node.js / Express

```javascript
app.get('/api/bookings/occupied-slots', async (req, res) => {
  const { date, service } = req.query;

  try {
    // Récupérer les réservations pour cette date et ce service
    const bookings = await Booking.find({
      date: date,
      service: service,
      status: { $in: ['confirmed', 'pending'] }
    });

    // Extraire les créneaux occupés
    const occupiedSlots = bookings.map(booking => booking.timeSlot);

    res.json({
      success: true,
      occupied_slots: occupiedSlots,
      total_occupied: occupiedSlots.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      occupied_slots: [],
      error: error.message
    });
  }
});
```

### Python / Flask

```python
@app.route('/api/bookings/occupied-slots', methods=['GET'])
def get_occupied_slots():
    date = request.args.get('date')
    service = request.args.get('service')

    try:
        # Récupérer les réservations
        bookings = Booking.query.filter_by(
            date=date,
            service=service
        ).filter(
            Booking.status.in_(['confirmed', 'pending'])
        ).all()

        # Extraire les créneaux
        occupied_slots = [booking.time_slot for booking in bookings]

        return jsonify({
            'success': True,
            'occupied_slots': occupied_slots,
            'total_occupied': len(occupied_slots)
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'occupied_slots': [],
            'error': str(e)
        }), 500
```

### PHP / Laravel

```php
Route::get('/api/bookings/occupied-slots', function (Request $request) {
    $date = $request->query('date');
    $service = $request->query('service');

    try {
        $bookings = Booking::where('date', $date)
            ->where('service', $service)
            ->whereIn('status', ['confirmed', 'pending'])
            ->get();

        $occupiedSlots = $bookings->pluck('time_slot')->toArray();

        return response()->json([
            'success' => true,
            'occupied_slots' => $occupiedSlots,
            'total_occupied' => count($occupiedSlots)
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'occupied_slots' => [],
            'error' => $e->getMessage()
        ], 500);
    }
});
```

---

## 🔄 Flux de traitement

```
1. Utilisateur sélectionne une date
   └─> Appel à _loadAvailableTimeSlots(date)

2. Récupération des créneaux par défaut
   └─> _getDefaultTimeSlots(date)
       ├─> Vérifie working_days
       ├─> Vérifie excluded_days
       ├─> Applique custom_schedules si défini
       ├─> Filtre les créneaux passés (si aujourd'hui)
       └─> Retourne liste de créneaux [8 créneaux]

3. Récupération des créneaux occupés
   └─> _getOccupiedSlots(date)
       ├─> Lecture blocked_slots du JSON
       │   └─> Exemple: ["08:00-09:00", "14:00-15:00"]
       └─> Appel API si api_occupied_slots défini
           └─> Exemple: ["09:00-10:00"]
       └─> Fusion: ["08:00-09:00", "14:00-15:00", "09:00-10:00"]

4. Filtrage
   └─> Créneaux totaux: 8
   └─> Créneaux occupés: 3
   └─> Créneaux disponibles: 5 ✅

5. Affichage
   └─> Utilisateur voit seulement les 5 créneaux disponibles
```

---

## 🎨 Interface Utilisateur

### Créneaux disponibles
```
┌──────────────────────────────┐
│  ⭕ 10:00 - 11:00            │ ← Disponible
│  ⭕ 11:00 - 12:00            │ ← Disponible
│  ⭕ 15:00 - 16:00            │ ← Disponible
│  ⭕ 16:00 - 17:00            │ ← Disponible
│  ⭕ 17:00 - 18:00            │ ← Disponible
└──────────────────────────────┘
```

**Créneaux occupés = Invisibles**
- `08:00-09:00` ❌ (Ne s'affiche pas)
- `09:00-10:00` ❌ (Ne s'affiche pas)
- `14:00-15:00` ❌ (Ne s'affiche pas)

### Si TOUS les créneaux sont occupés

```
┌──────────────────────────────┐
│      📅                       │
│  Aucun créneau disponible    │
│  Veuillez choisir une autre  │
│  date                         │
└──────────────────────────────┘
```

---

## 📊 Logs de débogage

Le système affiche des logs dans la console :

```
🔍 Récupération créneaux occupés: https://api.live.wortis.cg/api/bookings/occupied-slots?date=2024-02-15&service=Coiffure%20Hommes
✅ Créneaux occupés récupérés: 3
📅 Date: 2024-02-15
   Total créneaux: 8
   Créneaux occupés: 3
   Créneaux disponibles: 5
```

En cas d'erreur API :
```
⚠️ Erreur récupération créneaux occupés API: Failed to load
```

**Le système continue sans les créneaux de l'API** en cas d'erreur (fallback gracieux).

---

## ⚠️ Gestion des erreurs

### API indisponible
- ✅ Le système continue sans les créneaux de l'API
- ✅ Les créneaux bloqués statiques sont toujours appliqués
- ✅ Log d'avertissement dans la console

### Format de réponse invalide
- ✅ Le système ignore les données invalides
- ✅ Continue avec les créneaux bloqués statiques uniquement

### Pas de connexion internet
- ✅ Timeout automatique
- ✅ Utilise seulement les créneaux bloqués statiques

---

## 🎯 Cas d'usage

### Salon de coiffure

**Besoin :** Bloquer les jours fériés + gérer les réservations en temps réel

```json
{
  "blocked_slots": {
    "2024-12-25": ["08:00-09:00", "09:00-10:00", "10:00-11:00", "11:00-12:00", "14:00-15:00", "15:00-16:00", "16:00-17:00", "17:00-18:00"],
    "2024-01-01": ["08:00-09:00", "09:00-10:00", "10:00-11:00", "11:00-12:00", "14:00-15:00", "15:00-16:00", "16:00-17:00", "17:00-18:00"]
  },
  "api_occupied_slots": "https://api.salon.com/bookings/occupied?date={date}&service={service}"
}
```

### Service à domicile

**Besoin :** Seulement API (pas de fermetures fixes)

```json
{
  "api_occupied_slots": "https://api.service.com/occupied?date={date}"
}
```

### Maintenance planifiée

**Besoin :** Bloquer des jours spécifiques (pas d'API)

```json
{
  "blocked_slots": {
    "2024-03-15": ["08:00-09:00", "09:00-10:00", "10:00-11:00", "11:00-12:00"],
    "2024-03-16": ["08:00-09:00", "09:00-10:00", "10:00-11:00", "11:00-12:00"]
  }
}
```

---

## 🔧 Dépannage

### Les créneaux occupés ne sont pas masqués

**Vérifications :**
1. Format de date correct dans `blocked_slots` : `YYYY-MM-DD`
2. Format de créneau correct : `HH:MM-HH:MM`
3. L'API retourne bien `occupied_slots` dans la réponse
4. Vérifier les logs dans la console

### L'API n'est jamais appelée

**Vérifications :**
1. `api_occupied_slots` est bien défini dans `availability`
2. L'URL contient bien les paramètres `{date}` et/ou `{service}`
3. Vérifier les logs réseau dans DevTools

### Tous les créneaux sont bloqués

**Causes possibles :**
1. Tous les créneaux sont dans `blocked_slots` pour cette date
2. L'API retourne tous les créneaux comme occupés
3. Vérifier les logs : `Créneaux disponibles: 0`

---

## ✨ Avantages

✅ **Expérience utilisateur** : Pas de frustration (seulement des créneaux disponibles)
✅ **Temps réel** : Intégration API pour réservations live
✅ **Flexibilité** : Combinaison statique + dynamique
✅ **Performance** : Cache local + fallback gracieux
✅ **Maintenance** : Bloquer des jours sans toucher au code

---

**Version :** 1.0
**Date :** 2026-02-06
**Auteur :** Claude Sonnet 4.5
