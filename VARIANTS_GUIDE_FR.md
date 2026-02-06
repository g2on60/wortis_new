# Guide des Variantes/Déclinaisons - ReservationService

## 📦 Vue d'ensemble

Le système de variantes permet d'offrir plusieurs options pour une même prestation, chacune avec son propre prix. Par exemple, une coupe de cheveux peut avoir des options différentes selon la longueur (courts/longs) avec des tarifs adaptés.

## 🎯 Cas d'utilisation

### Quand utiliser les variantes ?

✅ **Utilisez les variantes pour :**
- **Options de taille** : Cheveux courts, mi-longs, longs
- **Niveaux de service** : Basique, Standard, Premium
- **Compléments** : Avec/sans shampoing, avec/sans massage
- **Durées différentes** : Express (30min), Standard (45min), Complet (1h)
- **Catégories d'âge** : Enfant 3-6 ans, 7-12 ans, Ado, Adulte

❌ **N'utilisez PAS les variantes pour :**
- Des prestations complètement différentes (créez des prestations séparées)
- Plus de 6 options (trop de choix confond l'utilisateur)

---

## 🔧 Structure JSON

### Prestation SANS variantes (prix fixe)

```json
{
  "value": "coupe_simple",
  "label": "Coupe Simple",
  "category": "coupes",
  "description": "Coupe basique sans option",
  "price": 4500,
  "image": "https://..."
}
```

### Prestation AVEC variantes

```json
{
  "value": "coupe_homme",
  "label": "Coupe Homme",
  "category": "coupes",
  "description": "Coupe moderne ou classique",
  "image": "https://...",
  "variants": [
    {
      "id": "courte",
      "label": "Cheveux Courts",
      "price": 5000,
      "description": "Pour cheveux jusqu'aux oreilles"
    },
    {
      "id": "moyenne",
      "label": "Cheveux Mi-longs",
      "price": 6000,
      "description": "Pour cheveux jusqu'aux épaules"
    },
    {
      "id": "longue",
      "label": "Cheveux Longs",
      "price": 7500,
      "description": "Pour cheveux dépassant les épaules"
    }
  ]
}
```

**Important :** Quand `variants` est présent, le champ `price` de la prestation est ignoré. Chaque variante a son propre prix.

---

## 📋 Champs d'une variante

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `id` | String | ✅ Oui | Identifiant unique de la variante |
| `label` | String | ✅ Oui | Nom affiché de la variante |
| `price` | Integer | ✅ Oui | Prix en FCFA (ou votre devise) |
| `description` | String | ❌ Non | Description supplémentaire (max 1-2 lignes) |

---

## 🎨 Interface utilisateur

### Comportement

1. **Sans variantes** :
   - L'utilisateur clique sur la card
   - Le prix est affiché directement sur la card
   - Il peut passer à l'étape suivante

2. **Avec variantes** :
   - L'utilisateur clique sur la card
   - Un sélecteur de variantes apparaît en dessous avec animation
   - L'utilisateur doit sélectionner une option
   - Le prix change selon la variante sélectionnée
   - Impossible de passer à l'étape suivante sans sélectionner une variante

### Affichage

```
┌─────────────────────────────────┐
│  [🎨] Choisissez une option     │
│      3 options disponibles      │
├─────────────────────────────────┤
│  ○  Cheveux Courts           5000F │
│     Pour cheveux jusqu'aux oreilles│
│                                    │
│  ●  Cheveux Mi-longs         6000F │ ← Sélectionné
│     Pour cheveux jusqu'aux épaules │
│                                    │
│  ○  Cheveux Longs            7500F │
│     Pour cheveux dépassant...      │
└─────────────────────────────────┘
```

---

## 💡 Exemples complets

### Exemple 1 : Coupe avec options de longueur

```json
{
  "value": "coupe_homme",
  "label": "Coupe Homme",
  "category": "coupes",
  "description": "Coupe personnalisée selon vos préférences",
  "image": "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=400&q=80",
  "variants": [
    {
      "id": "courte",
      "label": "Cheveux Courts",
      "price": 5000,
      "description": "Jusqu'aux oreilles"
    },
    {
      "id": "moyenne",
      "label": "Cheveux Mi-longs",
      "price": 6000,
      "description": "Jusqu'aux épaules"
    },
    {
      "id": "longue",
      "label": "Cheveux Longs",
      "price": 7500,
      "description": "Dépassant les épaules"
    }
  ]
}
```

### Exemple 2 : Barbe avec niveaux de service

```json
{
  "value": "taille_barbe",
  "label": "Taille de Barbe",
  "category": "barbe",
  "description": "Taille et mise en forme professionnelle",
  "image": "https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=400&q=80",
  "variants": [
    {
      "id": "simple",
      "label": "Taille Simple",
      "price": 2500,
      "description": "Égalisation basique"
    },
    {
      "id": "design",
      "label": "Taille Design",
      "price": 3500,
      "description": "Avec dessin et contours précis"
    },
    {
      "id": "complete",
      "label": "Taille Complète",
      "price": 4000,
      "description": "Avec soin et huile de barbe inclus"
    }
  ]
}
```

### Exemple 3 : Forfaits avec niveaux Premium

```json
{
  "value": "forfait_complet",
  "label": "Forfait Complet",
  "category": "forfaits",
  "description": "Package tout inclus",
  "image": "https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=400&q=80",
  "variants": [
    {
      "id": "standard",
      "label": "Forfait Standard",
      "price": 10000,
      "description": "Coupe + Barbe + Shampoing"
    },
    {
      "id": "premium",
      "label": "Forfait Premium",
      "price": 13000,
      "description": "Coupe + Barbe + Soins + Massage"
    },
    {
      "id": "vip",
      "label": "Forfait VIP",
      "price": 18000,
      "description": "Service complet avec produits haut de gamme"
    }
  ]
}
```

### Exemple 4 : Coupe enfant par âge

```json
{
  "value": "coupe_enfant",
  "label": "Coupe Enfant",
  "category": "coupes",
  "description": "Coupe adaptée aux enfants",
  "image": "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=400&q=80",
  "variants": [
    {
      "id": "3-6ans",
      "label": "3 à 6 ans",
      "price": 3000
    },
    {
      "id": "7-12ans",
      "label": "7 à 12 ans",
      "price": 3500
    },
    {
      "id": "13-17ans",
      "label": "13 à 17 ans",
      "price": 4000
    }
  ]
}
```

---

## 🔄 Combinaison Catégories + Variantes

Vous pouvez combiner les catégories et les variantes :

```json
{
  "categories": [
    {"id": "coupes", "label": "Coupes", "icon": "content_cut"},
    {"id": "barbe", "label": "Barbe", "icon": "face_retouching_natural"}
  ],
  "fields": [{
    "name": "type_prestation",
    "options": [
      {
        "value": "coupe_homme",
        "label": "Coupe Homme",
        "category": "coupes",
        "variants": [
          {"id": "courte", "label": "Courts", "price": 5000},
          {"id": "longue", "label": "Longs", "price": 7500}
        ]
      },
      {
        "value": "taille_barbe",
        "label": "Barbe",
        "category": "barbe",
        "variants": [
          {"id": "simple", "label": "Simple", "price": 2500},
          {"id": "design", "label": "Design", "price": 3500}
        ]
      }
    ]
  }]
}
```

**Résultat** : L'utilisateur filtre d'abord par catégorie, puis sélectionne une prestation, puis choisit sa variante.

---

## 📤 Données envoyées à l'API

Quand l'utilisateur soumet une réservation avec une variante, les données suivantes sont envoyées :

```json
{
  "date": "2024-02-15",
  "timeSlot": "10:00 - 11:00",
  "prestation": "coupe_homme",
  "variant": "moyenne",
  "email": "client@example.com",
  "notes": "Préférence pour style moderne"
}
```

**Champs :**
- `prestation` : L'identifiant (`value`) de la prestation
- `variant` : L'identifiant (`id`) de la variante sélectionnée

**Configuration du mapping dans le JSON :**
```json
"body": {
  "date": "date",
  "timeSlot": "timeSlot",
  "prestation": "type_prestation",
  "variant": "variant",
  "email": "email",
  "notes": "notes"
}
```

---

## ⚙️ Validation automatique

Le système valide automatiquement :

1. ✅ Une prestation est sélectionnée
2. ✅ Si la prestation a des variantes, une variante est sélectionnée
3. ✅ Si changement de prestation, la variante est réinitialisée

**Messages d'erreur configurables :**
```json
"texts": {
  "error_no_prestation": "Veuillez sélectionner une prestation",
  "error_no_variant": "Veuillez sélectionner une option"
}
```

---

## 🎯 Bonnes pratiques

### Nommage des variantes

✅ **BIEN :**
- "Cheveux Courts" / "Mi-longs" / "Longs"
- "Basique" / "Standard" / "Premium"
- "30 minutes" / "45 minutes" / "1 heure"

❌ **À ÉVITER :**
- "Option 1" / "Option 2" (pas descriptif)
- "Coupe cheveux courts avec shampoing et massage relaxant..." (trop long)

### Nombre de variantes

- **2-3 variantes** : Idéal, choix simple
- **4-5 variantes** : Acceptable, mais attention à la clarté
- **6+ variantes** : À éviter, trop complexe

### Prix cohérents

- Progression logique : 5000 → 6000 → 7500 ✅
- Progression illogique : 5000 → 12000 → 6500 ❌

### Descriptions

- **Courtes** : 5-10 mots maximum
- **Utiles** : Aide à comprendre la différence
- **Optionnelles** : Si le label est clair, skip la description

---

## 🐛 Dépannage

### Les variantes ne s'affichent pas

**Problème** : Le sélecteur de variantes n'apparaît pas après avoir cliqué sur une prestation.

**Solutions** :
1. Vérifiez que le champ `variants` est bien un tableau
2. Vérifiez que le tableau n'est pas vide
3. Vérifiez que chaque variante a `id`, `label` et `price`

### Erreur "Veuillez sélectionner une option"

**Problème** : Impossible de passer à l'étape suivante malgré une sélection.

**Solutions** :
1. Vérifiez que vous avez bien cliqué sur une variante (cercle rempli)
2. Rechargez la page
3. Vérifiez que l'`id` de la variante est unique

### Le prix ne s'affiche pas

**Problème** : Pas de prix affiché sur les variantes.

**Solutions** :
1. Vérifiez que le champ `price` existe pour chaque variante
2. Vérifiez que le prix est un nombre (pas une chaîne)
3. Format correct : `"price": 5000` (pas `"price": "5000"`)

---

## 🔄 Migration

### Passer d'un prix fixe aux variantes

**Avant :**
```json
{
  "value": "coupe",
  "label": "Coupe",
  "price": 5000
}
```

**Après :**
```json
{
  "value": "coupe",
  "label": "Coupe",
  "variants": [
    {
      "id": "standard",
      "label": "Standard",
      "price": 5000,
      "description": "Coupe classique"
    },
    {
      "id": "premium",
      "label": "Premium",
      "price": 7000,
      "description": "Avec styling"
    }
  ]
}
```

**Note :** Le champ `price` de la prestation est ignoré si `variants` existe.

---

## 📊 Statistiques

Pour analyser vos ventes par variante, l'API reçoit :
- `prestation` : Quelle prestation (ex: "coupe_homme")
- `variant` : Quelle variante (ex: "moyenne")

Vous pouvez ainsi savoir :
- Quelles variantes sont les plus populaires
- Quel est le panier moyen par variante
- Optimiser vos tarifs

---

## ✨ Avantages

🎯 **Flexibilité** : Un seul service avec plusieurs prix
💰 **Optimisation tarifaire** : Adapter le prix selon le besoin
📊 **Meilleure segmentation** : Comprendre les préférences clients
🎨 **UX améliorée** : Choix clairs et organisés
⚡ **Conversion** : Offrir des options augmente les ventes

---

**Version :** 1.0
**Date :** 2026-02-06
**Auteur :** Claude Sonnet 4.5
