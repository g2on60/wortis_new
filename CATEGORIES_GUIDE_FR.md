# Guide de Catégorisation des Prestations - ReservationService

## 📦 Vue d'ensemble

Le système de catégorisation permet d'organiser vos prestations en catégories lorsque vous avez beaucoup d'articles. Les utilisateurs peuvent filtrer les prestations par catégorie via des onglets.

## 🎯 Structure JSON

### 1. **Définir les catégories** (Optionnel)

Ajoutez un champ `categories` dans votre service JSON :

```json
"categories": [
  {
    "id": "coupes",
    "label": "Coupes",
    "icon": "content_cut",
    "color": "#6366F1"
  },
  {
    "id": "barbe",
    "label": "Barbe & Rasage",
    "icon": "face_retouching_natural",
    "color": "#EC4899"
  },
  {
    "id": "forfaits",
    "label": "Forfaits",
    "icon": "auto_awesome",
    "color": "#10B981"
  }
]
```

**Champs d'une catégorie :**
- `id` (requis) : Identifiant unique de la catégorie
- `label` (requis) : Nom affiché de la catégorie
- `icon` (optionnel) : Nom de l'icône Material Icons
- `color` (optionnel) : Couleur en hexadécimal (non utilisé actuellement)

### 2. **Assigner les prestations aux catégories**

Ajoutez un champ `category` à chaque prestation dans `options` :

```json
"options": [
  {
    "value": "coupe_simple",
    "label": "Coupe Simple",
    "category": "coupes",
    "description": "Coupe moderne ou classique",
    "price": 5000,
    "image": "https://..."
  },
  {
    "value": "taille_barbe",
    "label": "Taille de Barbe",
    "category": "barbe",
    "description": "Taille et mise en forme",
    "price": 3000,
    "image": "https://..."
  }
]
```

**Important :** La valeur de `category` doit correspondre à l'`id` d'une catégorie définie.

---

## 🎨 Icônes disponibles

Liste des icônes Material supportées (vous pouvez en ajouter d'autres dans le code) :

- `content_cut` - Ciseaux (coupe)
- `face_retouching_natural` - Visage (barbe)
- `auto_awesome` - Étoile (forfaits)
- `spa` - Spa (soins)
- `brush` - Pinceau (coloration)
- `style` - Style (mode)
- `category` - Catégorie (défaut)

---

## 🚀 Comment ça fonctionne ?

### Avec catégories

1. Des onglets s'affichent en haut de la liste des prestations
2. L'utilisateur peut cliquer sur une catégorie pour filtrer
3. Un onglet "Toutes" permet de voir toutes les prestations
4. Le compteur affiche le nombre de prestations visibles

### Sans catégories

Si vous ne définissez pas de `categories` dans le JSON :
- Le système fonctionne normalement
- Toutes les prestations sont affichées
- Aucun onglet de filtrage n'apparaît

**Le système est rétro-compatible** : vos anciens services sans catégories continuent de fonctionner.

---

## 📝 Exemple complet

```json
{
  "name": "Coiffure Homme",
  "Type_Service": "ReservationService",
  "title": "Salon de Coiffure",

  "categories": [
    {
      "id": "coupes",
      "label": "Coupes",
      "icon": "content_cut"
    },
    {
      "id": "barbe",
      "label": "Barbe",
      "icon": "face_retouching_natural"
    },
    {
      "id": "forfaits",
      "label": "Forfaits",
      "icon": "auto_awesome"
    }
  ],

  "fields": [
    {
      "name": "type_prestation",
      "type": "selecteur",
      "label": "Type de prestation",
      "required": true,
      "options": [
        {
          "value": "coupe_simple",
          "label": "Coupe Simple",
          "category": "coupes",
          "description": "Coupe moderne",
          "price": 5000,
          "image": "https://..."
        },
        {
          "value": "coupe_barbe",
          "label": "Coupe + Barbe",
          "category": "forfaits",
          "description": "Package complet",
          "price": 7500,
          "image": "https://..."
        },
        {
          "value": "taille_barbe",
          "label": "Taille de Barbe",
          "category": "barbe",
          "description": "Taille et mise en forme",
          "price": 3000,
          "image": "https://..."
        }
      ]
    }
  ]
}
```

---

## 🎯 Bonnes pratiques

### Quand utiliser les catégories ?

✅ **OUI** - Utilisez les catégories si :
- Vous avez plus de 6-8 prestations
- Vos prestations appartiennent à des groupes distincts
- Vous voulez améliorer l'expérience utilisateur

❌ **NON** - Ne les utilisez pas si :
- Vous avez moins de 6 prestations
- Toutes vos prestations sont similaires
- La catégorisation n'apporte pas de valeur

### Nommage des catégories

- **Court et clair** : "Coupes", "Barbe", "Soins"
- **Évitez** : "Toutes nos prestations de coupe de cheveux pour hommes"
- **Maximum** : 15 caractères pour un bon affichage

### Organisation

- Mettez les catégories les plus populaires en premier
- Groupez logiquement (ex: "Coupes" + "Barbe" + "Forfaits Complet")
- Évitez trop de catégories (4-6 maximum)

---

## 🔧 Ajouter de nouvelles icônes

Pour ajouter une nouvelle icône, modifiez le fichier `reservation_service.dart` dans la méthode `_buildCategoryTabs` :

```dart
switch (iconName) {
  case 'content_cut':
    icon = Icons.content_cut;
    break;
  case 'votre_nouvelle_icone':
    icon = Icons.votre_nouvelle_icone;
    break;
  // ... autres icônes
}
```

Liste complète des icônes Material : [https://api.flutter.dev/flutter/material/Icons-class.html](https://api.flutter.dev/flutter/material/Icons-class.html)

---

## ⚠️ Dépannage

### Les catégories ne s'affichent pas
- Vérifiez que `categories` est bien au niveau racine du JSON
- Vérifiez que chaque catégorie a un `id` et un `label`

### Les prestations ne sont pas filtrées
- Vérifiez que le champ `category` de chaque prestation correspond à un `id` de catégorie
- Assurez-vous que le champ `category` est bien au même niveau que `value`, `label`, etc.

### Message "Aucune prestation dans cette catégorie"
- Aucune prestation n'a le bon `category` pour cette catégorie
- Vérifiez l'orthographe des `id` et des `category` (sensible à la casse)

---

## 📊 Exemple d'utilisation réelle

**Salon de coiffure avec 12 prestations :**

- **Catégorie "Coupes"** (5 prestations)
  - Coupe Homme Simple
  - Coupe Stylisée
  - Coupe Enfant
  - Coupe + Shampoing
  - Coupe Dégradé

- **Catégorie "Barbe"** (3 prestations)
  - Taille de Barbe
  - Rasage Traditionnel
  - Soin Barbe

- **Catégorie "Forfaits"** (4 prestations)
  - Coupe + Barbe
  - Forfait Complet
  - Forfait Premium
  - Forfait Express

**Résultat :** L'utilisateur peut rapidement trouver ce qu'il cherche en filtrant par catégorie au lieu de scroller dans une longue liste.

---

## 🎉 Avantages

✨ **Meilleure organisation** : Navigation plus intuitive
⚡ **Gain de temps** : L'utilisateur trouve rapidement sa prestation
📱 **Meilleure UX mobile** : Moins de scroll nécessaire
🎨 **Interface moderne** : Onglets animés et visuels
🔄 **Rétro-compatible** : Fonctionne avec ou sans catégories

---

**Version :** 1.0
**Date :** 2026-02-05
**Auteur :** Claude Sonnet 4.5
