# Configuration des Disponibilités - ReservationService

## 📝 Structure de la configuration `texts`

### Textes personnalisables de l'interface

Tous les textes de l'interface peuvent être configurés depuis le JSON :

```json
"texts": {
  "step_1_title": "Étape 1 : Choisissez votre prestation",
  "step_2_title": "Étape 2 : Sélectionnez la date",
  "step_3_title": "Étape 3 : Finalisez votre réservation",
  "step_1_label": "Prestation",
  "step_2_label": "Date",
  "step_3_label": "Détails",
  "button_next": "Suivant",
  "button_previous": "Précédent",
  "button_confirm": "Confirmer",
  "error_no_prestation": "Veuillez sélectionner une prestation",
  "error_no_timeslot": "Veuillez sélectionner un créneau horaire"
}
```

**Textes disponibles :**
- `step_1_title`, `step_2_title`, `step_3_title` : Titres des étapes affichés en grand
- `step_1_label`, `step_2_label`, `step_3_label` : Labels courts dans l'indicateur de progression
- `button_next` : Texte du bouton pour passer à l'étape suivante
- `button_previous` : Texte du bouton pour revenir en arrière
- `button_confirm` : Texte du bouton de confirmation finale
- `error_no_prestation` : Message d'erreur si aucune prestation sélectionnée
- `error_no_timeslot` : Message d'erreur si aucun créneau sélectionné

**Note :** Si les textes ne sont pas définis dans le JSON, des valeurs par défaut en français seront utilisées.

---

## 📅 Structure de la configuration `availability`

### 1. **working_days** (Jours de travail)
Liste des jours de la semaine où le service est disponible.

```json
"working_days": [1, 2, 3, 4, 5, 6]
```

**Valeurs :**
- `1` = Lundi
- `2` = Mardi
- `3` = Mercredi
- `4` = Jeudi
- `5` = Vendredi
- `6` = Samedi
- `7` = Dimanche

**Exemple :** `[1, 2, 3, 4, 5, 6]` = Ouvert du Lundi au Samedi

---

### 2. **excluded_days** (Jours fermés)
Liste des jours où le service est fermé (prioritaire sur working_days).

```json
"excluded_days": [7]
```

**Exemple :** `[7]` = Fermé le Dimanche

---

### 3. **time_slots** (Créneaux horaires par défaut)
Liste des créneaux horaires disponibles par défaut pour tous les jours.

```json
"time_slots": [
  "08:00-09:00",
  "09:00-10:00",
  "10:00-11:00",
  "11:00-12:00",
  "14:00-15:00",
  "15:00-16:00",
  "16:00-17:00",
  "17:00-18:00"
]
```

**Format :** `"HH:MM-HH:MM"` (utiliser le format 24h)

---

### 4. **custom_schedules** (Horaires personnalisés)
Définit des horaires spécifiques pour certains jours (remplace les time_slots par défaut).

```json
"custom_schedules": {
  "6": {
    "time_slots": [
      "09:00-10:00",
      "10:00-11:00",
      "11:00-12:00",
      "14:00-15:00"
    ]
  }
}
```

**Clé :** Numéro du jour (`"1"` à `"7"`)
**Valeur :** Objet avec `time_slots` personnalisés

**Exemple :** Le samedi (jour 6) a des horaires réduits de 9h à 15h.

---

## 🎯 Exemples de Configuration

### Exemple 1 : Salon ouvert du Lundi au Vendredi (8h-18h)

```json
"availability": {
  "working_days": [1, 2, 3, 4, 5],
  "excluded_days": [6, 7],
  "time_slots": [
    "08:00-09:00",
    "09:00-10:00",
    "10:00-11:00",
    "11:00-12:00",
    "13:00-14:00",
    "14:00-15:00",
    "15:00-16:00",
    "16:00-17:00",
    "17:00-18:00"
  ]
}
```

---

### Exemple 2 : Service 7j/7 avec horaires réduits le weekend

```json
"availability": {
  "working_days": [1, 2, 3, 4, 5, 6, 7],
  "excluded_days": [],
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
  "custom_schedules": {
    "6": {
      "time_slots": ["10:00-11:00", "11:00-12:00", "14:00-15:00"]
    },
    "7": {
      "time_slots": ["10:00-11:00", "11:00-12:00"]
    }
  }
}
```

---

### Exemple 3 : Horaires matin uniquement

```json
"availability": {
  "working_days": [1, 2, 3, 4, 5, 6],
  "excluded_days": [7],
  "time_slots": [
    "08:00-09:00",
    "09:00-10:00",
    "10:00-11:00",
    "11:00-12:00"
  ]
}
```

---

## 🔧 Intégration API (Optionnel)

Si vous souhaitez récupérer les créneaux disponibles dynamiquement depuis une API :

```json
"api_timeslots": "https://api.example.com/available-slots"
```

L'API doit retourner un format JSON :
```json
{
  "slots": ["08:00-09:00", "09:00-10:00", "10:00-11:00"]
}
```

---

## ✨ Fonctionnalités Automatiques

### 1. **Calendrier intelligent**
- Les jours fermés sont automatiquement désactivés (grisés) dans le calendrier
- Seuls les jours de `working_days` sont sélectionnables
- Les jours dans `excluded_days` ne peuvent pas être choisis

### 2. **Créneaux dynamiques**
- Les créneaux affichés dépendent du jour sélectionné
- Si un `custom_schedule` existe pour le jour, il remplace les créneaux par défaut
- Les créneaux vides n'affichent pas d'options de réservation

### 3. **Validation automatique**
- Impossible de réserver sur un jour fermé
- Les créneaux non disponibles ne sont pas proposés
- Validation côté client avant envoi au serveur

---

## 📝 Notes Importantes

1. **Format des heures :** Toujours utiliser le format 24h (HH:MM)
2. **Compatibilité :** Si `availability` n'est pas défini dans le JSON, le système utilise une configuration par défaut
3. **Priorité :** `custom_schedules` > `time_slots` > configuration par défaut
4. **Jours exclus :** Les `excluded_days` ont priorité sur `working_days`

---

## 🚀 Pour Aller Plus Loin

### Ajouter des jours fériés

Vous pouvez créer une liste de dates spécifiques à exclure :

```json
"availability": {
  "working_days": [1, 2, 3, 4, 5, 6],
  "excluded_days": [7],
  "excluded_dates": [
    "2024-01-01",
    "2024-12-25",
    "2024-05-01"
  ],
  "time_slots": [...]
}
```

### Créneaux par prestation

Certaines prestations peuvent nécessiter plus de temps :

```json
"options": [
  {
    "value": "coupe_simple",
    "label": "Coupe Simple",
    "duration": 30,
    "time_slots": ["08:00-08:30", "08:30-09:00", ...]
  },
  {
    "value": "forfait_complet",
    "label": "Forfait Complet",
    "duration": 90,
    "time_slots": ["08:00-09:30", "09:30-11:00", ...]
  }
]
```

---

**Version :** 1.0
**Date :** 2026-02-05
**Auteur :** Claude Sonnet 4.5
