# 🧪 Comment tester le service Catalog

## 🚀 Démarrage rapide

### 1. Vérifier que tout est en place

✅ Fichiers créés :
- `lib/class/catalog_service.dart` - Widget du catalogue
- `catalog_service_test.json` - Données de test
- `INTEGRATION_CATALOG_SERVICE.md` - Documentation complète

✅ Fichiers modifiés :
- `lib/pages/homepage_dias.dart` - Routage ajouté
- `lib/pages/allservice.dart` - Routage ajouté
- `pubspec.yaml` - Asset ajouté

### 2. Compiler l'application

```bash
flutter pub get
flutter run
```

---

## 📝 Option 1 : Test avec le JSON local (recommandé pour débuter)

Le fichier `catalog_service_test.json` contient un catalogue complet de boutique alimentaire avec 12 produits.

### Configuration du service dans l'API

Pour tester, votre API backend doit retourner un service avec `Type_Service: "Catalog"` :

```json
{
  "services": [
    {
      "name": "boutique_alimentaire",
      "Type_Service": "Catalog",
      "title": "Boutique Alimentaire",
      "icon": "shopping_cart",
      "image": "https://example.com/icon.png"
    }
  ]
}
```

### Étapes de test

1. **Lancer l'app** et se connecter
2. **Cliquer sur le service** "boutique_alimentaire"
3. **Vérifier le chargement** du catalogue avec 12 produits
4. **Tester la recherche** : Taper "tomates" dans la barre de recherche
5. **Tester les catégories** : Cliquer sur les tabs (Fruits & Légumes, Épicerie, etc.)
6. **Ajouter au panier** : Cliquer sur le bouton "+" sur plusieurs produits
7. **Voir le badge** : Vérifier que le compteur du panier s'incrémente
8. **Ouvrir le panier** : Cliquer sur l'icône panier
9. **Modifier les quantités** : Utiliser les boutons +/- dans le panier
10. **Supprimer un item** : Cliquer sur l'icône poubelle
11. **Aller au checkout** : Cliquer sur "Commander"
12. **Remplir le formulaire** : Sélectionner livraison, adresse, téléphone
13. **Valider** : Cliquer sur "Valider la commande"

> ⚠️ **Note** : La validation finale échouera car l'endpoint API `api_checkout` n'existe pas encore. C'est normal !

---

## 📡 Option 2 : Test avec l'API backend

### Modification du code pour charger depuis l'API

Éditer `lib/class/catalog_service.dart`, ligne 187-195 :

**Remplacer :**
```dart
Future<void> _loadCatalogData() async {
  try {
    // Charger depuis le fichier JSON local
    final String jsonString = await DefaultAssetBundle.of(context)
        .loadString('catalog_service_test.json');
    final data = jsonDecode(jsonString);
```

**Par :**
```dart
Future<void> _loadCatalogData() async {
  try {
    // Charger depuis l'API
    final response = await http.get(
      Uri.parse('https://api.live.wortis.cg/api/service-fields/${widget.serviceName}'),
      headers: {
        'Authorization': 'Bearer ${await SessionManager.getToken()}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
```

### Structure de la réponse API attendue

L'endpoint `GET /api/service-fields/boutique_alimentaire` doit retourner :

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
      "image": "https://example.com/tomates.jpg",
      "stock": 50,
      "discount": 0,
      "featured": true
    }
  ],
  "payment_methods": [
    {
      "id": "mobile_money",
      "name": "Mobile Money",
      "icon": "phone_android",
      "enabled": true
    }
  ],
  "delivery_options": [
    {
      "id": "standard",
      "name": "Livraison standard",
      "description": "Livraison sous 24-48h",
      "fee": 1000,
      "estimated_time": "24-48h"
    }
  ],
  "api_checkout": "https://api.live.wortis.cg/api/catalog/checkout",
  "api_verify_stock": "https://api.live.wortis.cg/api/catalog/verify-stock"
}
```

---

## 🔧 Créer l'endpoint de checkout (Backend)

### Endpoint : `POST /api/catalog/checkout`

**Headers requis :**
```
Authorization: Bearer {token_utilisateur}
Content-Type: application/json
```

**Body reçu de l'app :**
```json
{
  "items": [
    {
      "product_id": "prod_001",
      "quantity": 2,
      "price": 500
    },
    {
      "product_id": "prod_003",
      "quantity": 1,
      "price": 5000
    }
  ],
  "delivery_option": "standard",
  "delivery_address": "123 Rue Example, Brazzaville",
  "phone": "06 123 45 67",
  "notes": "Livrer après 17h",
  "total": 7000
}
```

**Réponse à retourner (succès) :**
```json
{
  "order_id": "ORD-2025-001234",
  "status": "pending",
  "message": "Commande reçue avec succès",
  "total": 7000
}
```

**Réponse à retourner (erreur) :**
```json
{
  "error": "Stock insuffisant pour le produit prod_001"
}
```

### Exemple d'implémentation (Python/Flask)

```python
@app.route('/api/catalog/checkout', methods=['POST'])
def catalog_checkout():
    # Récupérer le token
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    if not token:
        return jsonify({'error': 'Non authentifié'}), 401

    # Vérifier l'utilisateur
    user = verify_token(token)  # Fonction à implémenter
    if not user:
        return jsonify({'error': 'Token invalide'}), 401

    # Récupérer les données
    data = request.json
    items = data.get('items', [])
    delivery_option = data.get('delivery_option')
    delivery_address = data.get('delivery_address')
    phone = data.get('phone')
    notes = data.get('notes', '')
    total = data.get('total')

    # Vérifier le stock
    for item in items:
        product = get_product(item['product_id'])  # Fonction à implémenter
        if not product or product['stock'] < item['quantity']:
            return jsonify({
                'error': f"Stock insuffisant pour {product['name']}"
            }), 400

    # Créer la commande
    order_id = create_order(
        user_id=user['id'],
        items=items,
        delivery_option=delivery_option,
        delivery_address=delivery_address,
        phone=phone,
        notes=notes,
        total=total
    )  # Fonction à implémenter

    # Décrémenter le stock
    for item in items:
        decrement_stock(item['product_id'], item['quantity'])

    # Réponse
    return jsonify({
        'order_id': order_id,
        'status': 'pending',
        'message': 'Commande reçue avec succès',
        'total': total
    }), 200
```

---

## 🧪 Scénarios de test

### Scénario 1 : Commande simple
1. Ajouter 2 tomates au panier
2. Ajouter 1 riz au panier
3. Vérifier le total : (500 × 2) + 5000 + 1000 (livraison) = 7000 XAF
4. Passer commande
5. Vérifier la confirmation

### Scénario 2 : Test des réductions
1. Ajouter "Pommes de terre" (discount 10%)
2. Vérifier le prix : 800 - 10% = 720 XAF
3. Ajouter 2 unités
4. Total : 720 × 2 = 1440 XAF

### Scénario 3 : Test du montant minimum
1. Ajouter seulement 1 tomate (500 XAF)
2. Essayer de valider
3. Vérifier le message : "Montant minimum de commande : 5000 XAF"

### Scénario 4 : Test de recherche
1. Taper "poulet" dans la recherche
2. Vérifier qu'on voit "Poulet frais"
3. Vérifier que les autres produits sont cachés

### Scénario 5 : Test de filtrage par catégorie
1. Cliquer sur la catégorie "Boissons"
2. Vérifier qu'on voit seulement : Eau minérale, Jus d'orange, Coca-Cola
3. Cliquer sur "All" pour tout réafficher

### Scénario 6 : Test du panier vide
1. Vider complètement le panier
2. Vérifier le message "Votre panier est vide"
3. Vérifier que le badge du panier disparaît

### Scénario 7 : Test des options de livraison
1. Ajouter des produits
2. Aller au checkout
3. Sélectionner "Livraison express" (2500 XAF)
4. Vérifier que le total est mis à jour
5. Sélectionner "Retrait en magasin" (0 XAF)
6. Vérifier que les frais de livraison sont à 0

---

## 🐛 Débogage

### Le catalogue ne se charge pas

1. **Vérifier le fichier JSON** :
```bash
cat catalog_service_test.json
```

2. **Vérifier les assets dans pubspec.yaml** :
```yaml
assets:
  - catalog_service_test.json
```

3. **Recompiler** :
```bash
flutter pub get
flutter clean
flutter run
```

### L'erreur "Unable to load asset"

Exécuter :
```bash
flutter clean
flutter pub get
flutter run
```

### Le service ne s'affiche pas dans la liste

Vérifier que l'API retourne bien `Type_Service: "Catalog"` pour le service.

### Le checkout échoue toujours

C'est normal si l'endpoint `api_checkout` n'existe pas encore. Vérifier les logs :

```dart
// Dans catalog_service.dart, ligne 944
print('✅ Réponse checkout : ${response.body}');
```

### Le panier se vide tout seul

Le panier n'est pas persistant entre sessions. C'est le comportement attendu pour le moment.

---

## 📸 Checklist de vérification visuelle

- [ ] Logo/icône du service s'affiche
- [ ] Titre du catalogue s'affiche
- [ ] Barre de recherche présente
- [ ] TabBar avec catégories visible
- [ ] Grille de produits (2 colonnes)
- [ ] Images des produits (ou icônes par défaut)
- [ ] Prix affichés correctement
- [ ] Badge "Featured" sur les produits vedettes
- [ ] Badge de réduction avec pourcentage
- [ ] Badge du panier avec compteur
- [ ] Modal du panier s'ouvre
- [ ] Liste des items du panier
- [ ] Boutons +/- fonctionnent
- [ ] Bouton supprimer fonctionne
- [ ] Total calculé correctement
- [ ] Page de checkout s'ouvre
- [ ] Formulaire de livraison fonctionnel
- [ ] Radio buttons de livraison fonctionnent
- [ ] Bouton "Valider la commande" présent
- [ ] Dialog de confirmation s'affiche (si API OK)

---

## 🎉 Prochaines étapes

Une fois que le test avec le JSON local fonctionne :

1. **Implémenter l'API backend** :
   - Endpoint de récupération du catalogue
   - Endpoint de checkout
   - Endpoint de vérification de stock (optionnel)

2. **Modifier le code pour charger depuis l'API** (voir Option 2 ci-dessus)

3. **Ajouter des fonctionnalités** :
   - Persistance du panier (SharedPreferences)
   - Historique des commandes
   - Suivi de livraison
   - Notifications de confirmation
   - Gestion des favoris
   - Partage de produits

4. **Optimisations** :
   - Cache des images
   - Pagination des produits
   - Chargement lazy
   - Gestion offline

---

## 📞 Support

Si vous rencontrez des problèmes, vérifier :

1. **Les logs Flutter** :
```bash
flutter run -v
```

2. **Les erreurs de compilation** :
```bash
flutter analyze
```

3. **Le fichier de documentation** :
```bash
cat INTEGRATION_CATALOG_SERVICE.md
```

---

**Bon test !** 🚀
