# Interface Modale des Variantes - ReservationService

## 🎯 Comportement

### Prestations SANS variantes
- L'utilisateur clique sur la prestation
- La prestation est sélectionnée immédiatement
- Le prix est enregistré
- ✅ Prêt à passer à l'étape suivante

### Prestations AVEC variantes
- L'utilisateur clique sur la prestation
- **Une modale s'ouvre depuis le bas de l'écran** 📱
- L'utilisateur choisit une variante
- Il valide sa sélection
- La modale se ferme
- ✅ Prêt à passer à l'étape suivante

---

## 📱 Fonctionnalités de la modale

### Ouverture
- ✨ Animation fluide depuis le bas
- 🎨 Fond transparent avec overlay
- 📏 Hauteur maximale : 60% de l'écran
- 🔄 Scroll automatique si beaucoup de variantes

### Navigation
- **Fermeture par :**
  - ✅ Toucher à l'extérieur de la modale
  - ✅ Swipe vers le bas (handle bar en haut)
  - ✅ Bouton X en haut à droite
  - ✅ Bouton "Valider la sélection" après avoir choisi

### Interface
```
┌────────────────────────────────┐
│       ▬▬▬▬ Handle bar          │
├────────────────────────────────┤
│  🎨 Coupe Homme            ✕   │
│     Choisissez une option      │
├────────────────────────────────┤
│                                │
│  ⭕ Cheveux Courts      5000F   │
│     Pour cheveux courts        │
│                                │
│  ● Cheveux Mi-longs    6000F   │ ← Sélectionné
│     Pour cheveux mi-longs      │
│                                │
│  ⭕ Cheveux Longs       7500F   │
│     Pour cheveux longs         │
│                                │
├────────────────────────────────┤
│  [Valider la sélection ✓]     │
└────────────────────────────────┘
```

### Sélection
- **Radio buttons** : Un seul choix possible
- **Animation** : Changement de couleur instantané
- **Prix** : Affiché clairement pour chaque option
- **État** : Le bouton est désactivé tant qu'aucune sélection

---

## 🎨 Design

### Header de la modale
- Icône de réglage (🎚️)
- Nom de la prestation en gras
- Sous-titre "Choisissez une option"
- Bouton X pour fermer

### Variantes
- **Cards** avec bordure animée
- **Radio button** à gauche
- **Label + description** au centre
- **Prix** à droite dans une pastille
- **Highlight** : Bordure et fond colorés quand sélectionné

### Bouton de validation
- **Désactivé** (gris) : Aucune sélection
- **Actif** (bleu) : Variante sélectionnée
- Icône check quand actif

---

## 💻 Implémentation technique

### Fonction appelée
```dart
_showVariantModal(Map<String, dynamic> prestationData)
```

### Type de widget
- `showModalBottomSheet` : Modale depuis le bas
- `isScrollControlled: true` : Hauteur personnalisable
- `backgroundColor: Colors.transparent` : Fond transparent pour l'overlay

### StatefulBuilder
La modale utilise `StatefulBuilder` pour mettre à jour l'UI quand une variante est sélectionnée, sans recharger toute la page.

### Gestion de l'état
```dart
// Dans le parent
String? _selectedVariantId;
Map<String, dynamic>? _currentPrestationData;

// Dans formValues
formValues['variant'] = variantId;
formValues['variant_price'] = price;
```

---

## 🔄 Flux utilisateur complet

```
1. Page Prestations
   └─> Clic sur prestation
       ├─> Pas de variantes → Sélection directe ✅
       └─> Avec variantes → Ouvrir modale 📱
           └─> Modale ouverte
               ├─> Toucher dehors → Fermer sans sélection
               ├─> Bouton X → Fermer sans sélection
               └─> Choisir variante + Valider → Fermer avec sélection ✅
                   └─> Retour à la page
                       └─> Bouton "Suivant" activé
```

---

## 🎯 Avantages

✅ **UX améliorée** : Focus sur le choix, pas de distraction
✅ **Mobile-friendly** : Bottom sheet natif iOS/Android
✅ **Visibilité** : Les variantes sont mises en avant
✅ **Accessibilité** : Facile à fermer (toucher dehors, swipe, X)
✅ **Validation claire** : Bouton explicite pour confirmer

---

## 📝 Configuration JSON

Rien ne change dans la structure JSON ! Le système détecte automatiquement les variantes :

```json
{
  "value": "coupe_homme",
  "label": "Coupe Homme",
  "variants": [
    {
      "id": "courte",
      "label": "Cheveux Courts",
      "price": 5000,
      "description": "Pour cheveux jusqu'aux oreilles"
    }
  ]
}
```

Si `variants` existe → Modale
Si `variants` absent → Sélection directe

---

## 🔧 Personnalisation

### Hauteur de la modale
Modifiez la constante dans `_showVariantModal` :
```dart
maxHeight: MediaQuery.of(context).size.height * 0.6, // 60% de l'écran
```

### Textes
Tous les textes sont personnalisables :
```json
"texts": {
  "variant_modal_title": "Choisissez une option",
  "variant_modal_validate": "Valider la sélection",
  "variant_modal_select_first": "Sélectionnez une option"
}
```

---

**Version :** 1.0
**Date :** 2026-02-06
**Type :** Interface Modale Bottom Sheet
