# 🛒 Intégration du Service Catalog - Guide Complet

## 📋 Vue d'ensemble

Un nouveau type de service **"Catalog"** a été ajouté à l'application Wortis, permettant aux utilisateurs de parcourir des produits, les ajouter à un panier, et passer commande avec livraison.

---

## ✅ Fichiers créés

### 1. `catalog_service_test.json` (racine du projet)

Fichier de test contenant la structure de données pour un catalogue de boutique alimentaire.

**Contenu :**
- 12 produits répartis en 4 catégories
- Options de livraison (standard, express, retrait)
- Méthodes de paiement (Mobile Money, Carte, Cash)
- Configuration du service (devise, frais de livraison, montant minimum)

### 2. `lib/class/catalog_service.dart` (~900 lignes)

Widget Flutter complet pour le service de catalogue avec panier.

**Composants principaux :**
- `Product` : Modèle de données pour les produits
- `CartItem` : Item du panier avec quantité
- `Category` : Catégorie de produits
- `DeliveryOption` : Options de livraison
- `CatalogService` : Widget principal avec TabBar, recherche, grille de produits
- `CheckoutPage` : Page de finalisation de commande

---

## 🔧 Fichiers modifiés

### 1. `lib/pages/homepage_dias.dart`

**Ligne 15 :** Ajout de l'import
```dart
import 'package:wortis/class/catalog_service.dart';
```

**Lignes 1105-1121 :** Logique de routage mise à jour
```dart
if (service['Type_Service'] == "WebView") {
  // WebView logic
} else if (service['Type_Service'] == "Catalog") {
  await SessionManager.checkSessionAndNavigate(
    context: context,
    authenticatedRoute: ServicePageTransitionDias(
      page: CatalogService(serviceName: label),
    ),
    unauthenticatedRoute: const AuthentificationPage(),
  );
} else {
  // FormService logic (par défaut)
}
```

### 2. `lib/pages/allservice.dart`

**Ligne 8 :** Ajout de l'import
```dart
import 'package:wortis/class/catalog_service.dart';
```

**Lignes 242-262 :** Logique de routage mise à jour
```dart
if (service['Type_Service'] == "WebView") {
  // WebView logic
} else if (service['Type_Service'] == "Catalog") {
  if (mounted && context.mounted) {
    await SessionManager.checkSessionAndNavigate(
      context: context,
      authenticatedRoute: ServicePageTransition(
        page: CatalogService(serviceName: serviceName),
      ),
      unauthenticatedRoute: const AuthentificationPage(),
    );
  }
} else {
  // FormService logic (par défaut)
}
```

### 3. `pubspec.yaml`

**Ligne 102 :** Ajout du fichier JSON aux assets
```yaml
assets:
  - assets/wortisapp.png
  - assets/wpay_.png
  - catalog_service_test.json  # ← NOUVEAU
```

---

## 🎯 Comment utiliser le service Catalog

### Configuration Backend (API)

Pour qu'un service soit reconnu comme Catalog, l'API doit retourner :

```json
{
  "name": "boutique_alimentaire",
  "Type_Service": "Catalog",
  "title": "Boutique Alimentaire",
  "description": "Commandez vos produits alimentaires en ligne",
  "icon": "shopping_cart",
  "currency": "XAF",
  "delivery_fee": 1000,
  "min_order": 5000,
  "categories": [
    {
      "id": "fruits",
      "name": "Fruits & Légumes",
      "icon": "apple",
      "color": "#4CAF50"
    }
  ],
  "products": [
    {
      "id": "prod_001",
      "name": "Tomates fraîches",
      "description": "Tomates rouges bien mûres",
      "category": "fruits",
      "price": 500,
      "unit": "kg",
      "image": "https://example.com/image.jpg",
      "stock": 50,
      "discount": 0,
      "featured": true
    }
  ],
  "payment_methods": [...],
  "delivery_options": [...],
  "api_checkout": "https://api.live.wortis.cg/api/catalog/checkout",
  "api_verify_stock": "https://api.live.wortis.cg/api/catalog/verify-stock"
}
```

### Workflow utilisateur

1. **Accès au service**
   - L'utilisateur clique sur un service avec `Type_Service: "Catalog"`
   - Vérification d'authentification (redirection si non connecté)
   - Chargement du `CatalogService`

2. **Navigation dans le catalogue**
   - Barre de recherche pour filtrer par nom
   - TabBar pour filtrer par catégorie
   - Badge sur l'icône panier indiquant le nombre d'items

3. **Ajout au panier**
   - Clic sur un produit pour l'ajouter
   - Notification Toast de confirmation
   - Mise à jour du compteur de panier

4. **Gestion du panier**
   - Clic sur l'icône panier pour voir le contenu
   - Modal Bottom Sheet avec liste des items
   - Possibilité d'augmenter/diminuer les quantités
   - Bouton supprimer pour retirer un item
   - Calcul automatique du total + frais de livraison

5. **Checkout**
   - Clic sur "Commander" dans le panier
   - Ouverture de la `CheckoutPage`
   - Sélection de l'option de livraison
   - Remplissage de l'adresse et du téléphone
   - Révision du récapitulatif de commande
   - Soumission de la commande à l'API

6. **Confirmation**
   - Dialog de confirmation avec numéro de commande
   - Vidage automatique du panier
   - Retour à la page d'accueil

---

## 🔄 Flux de données

### Chargement du catalogue

```
CatalogService.initState()
  ↓
_loadCatalogData()
  ↓
DefaultAssetBundle.loadString('catalog_service_test.json')
  ↓
jsonDecode()
  ↓
setState() avec catalogData, products, categories
```

### Ajout au panier

```
Utilisateur clique sur produit
  ↓
_addToCart(product)
  ↓
Vérification si produit déjà dans le panier
  ├─ OUI → Incrémenter quantité
  └─ NON → Créer nouveau CartItem
  ↓
setState() pour rafraîchir l'UI
  ↓
Afficher Toast de confirmation
```

### Soumission de commande

```
Utilisateur valide le checkout
  ↓
_submitOrder() dans CheckoutPage
  ↓
Préparation des données de commande (items, delivery, total)
  ↓
http.post() vers api_checkout avec token Authorization
  ↓
Réponse API
  ├─ Succès (200) → Dialog confirmation + vidage panier
  └─ Erreur → SnackBar avec message d'erreur
```

---

## 🛠️ APIs Backend requises

### 1. API de checkout

**Endpoint :** `POST https://api.live.wortis.cg/api/catalog/checkout`

**Headers :**
```
Authorization: Bearer {user_token}
Content-Type: application/json
```

**Body :**
```json
{
  "items": [
    {
      "product_id": "prod_001",
      "quantity": 2,
      "price": 500
    }
  ],
  "delivery_option": "standard",
  "delivery_address": "123 Rue Example, Brazzaville",
  "phone": "06 123 45 67",
  "notes": "Livrer après 17h",
  "total": 2000
}
```

**Réponse attendue (succès) :**
```json
{
  "order_id": "ORD-2025-001234",
  "status": "pending",
  "message": "Commande reçue avec succès"
}
```

### 2. API de vérification de stock (optionnel)

**Endpoint :** `POST https://api.live.wortis.cg/api/catalog/verify-stock`

**Body :**
```json
{
  "items": [
    {"product_id": "prod_001", "quantity": 2}
  ]
}
```

**Réponse :**
```json
{
  "available": true,
  "out_of_stock": []
}
```

---

## 📊 Structure de données

### Product
```dart
class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final String unit;
  final String? image;
  final int stock;
  final double discount;
  final bool featured;

  double get discountedPrice => price * (1 - discount / 100);
}
```

### CartItem
```dart
class CartItem {
  final Product product;
  int quantity;

  double get total => product.discountedPrice * quantity;
}
```

### Category
```dart
class Category {
  final String id;
  final String name;
  final String icon;
  final String color;
}
```

### DeliveryOption
```dart
class DeliveryOption {
  final String id;
  final String name;
  final String description;
  final double fee;
  final String estimatedTime;
}
```

---

## 🎨 UI/UX Features

### Écran principal (CatalogService)
- **AppBar** avec titre du catalogue
- **Badge de panier** avec compteur d'items
- **Barre de recherche** pour filtrer les produits
- **TabBar** avec catégories (All + catégories personnalisées)
- **GridView** avec 2 colonnes de produits
- **Cards produits** avec :
  - Image (ou icône par défaut)
  - Badge "Featured" si applicable
  - Badge de réduction si discount > 0
  - Nom du produit
  - Prix (avec prix barré si discount)
  - Bouton "+" pour ajouter au panier
  - Indicateur de stock

### Modal Panier (Bottom Sheet)
- **Liste des items** avec image, nom, prix, quantité
- **Boutons +/- ** pour ajuster les quantités
- **Bouton supprimer** pour retirer un item
- **Sous-total** des produits
- **Frais de livraison**
- **Total général**
- **Bouton "Commander"** pour aller au checkout

### Page Checkout
- **Récapitulatif de commande** avec liste des items
- **Sélection de livraison** (Radio buttons)
- **Formulaire adresse/téléphone**
- **Champ notes optionnel**
- **Affichage du total** avec frais
- **Bouton "Valider la commande"**
- **Dialog de confirmation** après soumission

---

## 🔐 Sécurité et validation

### Authentification
- ✅ Vérification automatique de la session avant accès au service
- ✅ Token Bearer envoyé dans les requêtes API
- ✅ Redirection vers login si non authentifié

### Validation côté client
- ✅ Vérification du montant minimum de commande
- ✅ Vérification de la disponibilité du stock
- ✅ Validation du formulaire de checkout (adresse, téléphone)
- ✅ Vérification du panier non vide avant checkout

### Gestion d'erreurs
- ✅ Try-catch sur les appels API
- ✅ Affichage de messages d'erreur explicites
- ✅ SnackBar pour les erreurs réseau
- ✅ Toast pour les confirmations d'ajout au panier

---

## 🚀 Prochaines étapes (Backend)

Pour rendre le service Catalog pleinement fonctionnel, il faut :

1. **Créer l'endpoint de checkout** (`POST /api/catalog/checkout`)
   - Validation des items et quantités
   - Vérification du stock disponible
   - Création de la commande en base de données
   - Déclenchement du processus de paiement si nécessaire
   - Envoi de notification de confirmation

2. **Créer l'endpoint de vérification de stock** (optionnel)
   - Vérification en temps réel de la disponibilité
   - Mise à jour des stocks réservés

3. **Ajouter le service dans la liste des services**
   - Endpoint `GET /api/services` doit retourner le service Catalog
   - Avec `Type_Service: "Catalog"` et toutes les données du catalogue

4. **Gérer les images des produits**
   - URLs publiques des images
   - Ou utilisation d'icônes Material si pas d'images

---

## 📱 Test du service

### En mode développement (avec JSON local)

1. Lancer l'app : `flutter run`
2. Le fichier `catalog_service_test.json` est chargé automatiquement
3. Tester toutes les fonctionnalités (recherche, filtres, panier, checkout)

### En mode production (avec API)

1. Modifier `_loadCatalogData()` dans `catalog_service.dart` pour charger depuis l'API :

```dart
Future<void> _loadCatalogData() async {
  try {
    final response = await http.get(
      Uri.parse('https://api.live.wortis.cg/api/service-fields/${widget.serviceName}'),
      headers: {
        'Authorization': 'Bearer ${await SessionManager.getToken()}',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        catalogData = data;
        // ... parsing des produits, catégories, etc.
      });
    }
  } catch (e) {
    // Gestion d'erreur
  }
}
```

---

## 🎯 Résumé des types de services

| Type | Description | Authentification | Fichier |
|------|-------------|------------------|---------|
| **WebView** | Page web embarquée | Non requise | `webviews.dart` |
| **FormService** | Formulaire dynamique natif | Requise | `form_service.dart` |
| **Catalog** | Boutique avec panier | Requise | `catalog_service.dart` |

---

## 📝 Notes importantes

1. **Badge natif** : Le package externe `badges` a été remplacé par une implémentation native avec `Stack` et `Positioned`

2. **État du panier** : Le panier est réinitialisé à chaque ouverture du service (pas de persistance entre sessions)

3. **Images** : Les images des produits utilisent `Image.network()` avec fallback sur une icône Material si l'URL est invalide

4. **Devise** : La devise est configurée dans le JSON (`currency: "XAF"`) et affichée sur tous les prix

5. **Livraison** : Le montant minimum de commande (`min_order`) doit être respecté avant de pouvoir valider

---

## ✅ Checklist de déploiement

- [x] Créer `catalog_service.dart`
- [x] Créer `catalog_service_test.json`
- [x] Intégrer dans `homepage_dias.dart`
- [x] Intégrer dans `allservice.dart`
- [x] Ajouter aux assets dans `pubspec.yaml`
- [ ] Créer l'API backend de checkout
- [ ] Créer l'API backend de vérification de stock
- [ ] Ajouter le service dans la liste des services API
- [ ] Tester le flux complet avec de vraies données
- [ ] Configurer les URLs des images produits

---

**Félicitations !** 🎉 Le service Catalog est maintenant intégré et prêt à être utilisé avec les données de test. Il ne reste plus qu'à implémenter les endpoints backend pour le rendre pleinement fonctionnel en production.
