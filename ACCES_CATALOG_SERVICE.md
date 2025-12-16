# 🛒 Comment accéder au service Catalog ?

## ✅ Méthode 1 : Via l'API Backend (Production)

C'est la **méthode recommandée** pour un usage en production.

### Étape 1 : Ajouter le service dans votre API

Dans votre backend (fichier `app.py` ou équivalent), modifiez l'endpoint qui retourne la liste des services pour inclure :

```python
# Exemple avec Flask/Python
@app.route('/api/services')
def get_services():
    services = [
        # ... vos services existants (recharge, transfert, etc.) ...

        # ✨ NOUVEAU SERVICE CATALOG
        {
            "name": "boutique_alimentaire",
            "Type_Service": "Catalog",
            "title": "Boutique Alimentaire",
            "description": "Commandez vos produits alimentaires en ligne",
            "icon": "shopping_cart",
            "status": True,
            "image": None  # ou URL d'une image/icône
        }
    ]

    return jsonify({"services": services})
```

### Étape 2 : Redémarrer l'application Flutter

```bash
flutter run
```

### Étape 3 : Utiliser l'app

1. Se connecter à l'application
2. Aller sur la page d'accueil (Congo ou Diaspora)
3. Le service **"Boutique Alimentaire"** apparaîtra automatiquement avec l'icône panier 🛒
4. Cliquer dessus → Le `CatalogService` s'ouvrira automatiquement !

---

## 🧪 Méthode 2 : Test rapide sans modifier l'API

Si vous voulez tester **immédiatement** sans toucher au backend, voici 2 options :

### Option A : Bouton de test temporaire (le plus simple)

J'ai créé le fichier `lib/pages/test_catalog_button.dart`. Voici comment l'utiliser :

#### 1. Importer le bouton dans homepage_dias.dart

```dart
// En haut du fichier lib/pages/homepage_dias.dart, après les autres imports
import 'package:wortis/pages/test_catalog_button.dart';
```

#### 2. Ajouter le bouton dans le Scaffold

Chercher la ligne `return Scaffold(` (ligne ~1443) et ajouter après la fermeture du `body:` :

```dart
return Scaffold(
  backgroundColor: const Color(0xFF006699),
  resizeToAvoidBottomInset: true,
  body: Container(
    // ... tout le contenu existant ...
  ),
  // ✨ AJOUTER CETTE LIGNE :
  floatingActionButton: const TestCatalogButton(),
);
```

#### 3. Relancer l'app

Un bouton orange "Test Catalog" apparaîtra en bas à droite. Cliquez dessus pour ouvrir le catalogue !

### Option B : Modifier temporairement le Provider

Si vous voulez que le service apparaisse dans la liste normale :

#### 1. Trouver où le Provider charge les services

Probablement dans `lib/class/dataprovider.dart`

#### 2. Ajouter manuellement le service Catalog

```dart
// Dans la fonction qui charge les services
List<Map<String, dynamic>> services = [
  // Services chargés depuis l'API
  ...servicesFromAPI,

  // ✨ Service de test temporaire
  {
    "name": "boutique_alimentaire",
    "Type_Service": "Catalog",
    "title": "Boutique Alimentaire",
    "description": "Commandez vos produits alimentaires en ligne",
    "icon": "shopping_cart",
    "status": true,
    "image": null,
  }
];
```

---

## 🚀 Méthode 3 : Navigation directe (Debug uniquement)

Pour tester directement depuis n'importe où dans l'app :

```dart
// Dans n'importe quel widget avec accès au context :
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const CatalogService(
      serviceName: 'boutique_alimentaire',
    ),
  ),
);
```

Vous pouvez ajouter ce code temporairement dans un bouton pour tester.

---

## 📊 Vérification que tout fonctionne

Une fois que vous avez accès à la page Catalog, vous devriez voir :

1. ✅ AppBar avec titre "Boutique Alimentaire"
2. ✅ Icône panier en haut à droite (avec badge si items ajoutés)
3. ✅ Barre de recherche
4. ✅ TabBar avec catégories : All, Fruits & Légumes, Épicerie, Boissons, Viandes & Poissons
5. ✅ Grille de 12 produits (2 colonnes)
6. ✅ Prix en XAF (ex: 500 XAF, 5000 XAF)
7. ✅ Bouton "+" sur chaque produit
8. ✅ Badge "Featured" sur certains produits
9. ✅ Badge de réduction sur les produits en promo

---

## 🎯 Test complet du workflow

1. **Ajouter des produits au panier**
   - Cliquer sur le "+" de plusieurs produits
   - Vérifier que le badge du panier s'incrémente

2. **Ouvrir le panier**
   - Cliquer sur l'icône panier
   - Voir la liste des items ajoutés

3. **Modifier le panier**
   - Augmenter/diminuer les quantités avec +/-
   - Supprimer des items avec l'icône poubelle

4. **Aller au checkout**
   - Cliquer sur "Commander"
   - Remplir l'adresse et le téléphone
   - Sélectionner une option de livraison

5. **Valider**
   - Cliquer sur "Valider la commande"
   - Voir l'erreur (normal, l'API n'existe pas encore)

---

## 🐛 Dépannage

### Le service n'apparaît pas dans la liste

**Cause** : L'API ne retourne pas le service ou `Type_Service` n'est pas "Catalog"

**Solution** : Vérifier les logs Flutter pour voir ce que retourne l'API :
```bash
flutter run -v
```

### Erreur "Unable to load asset: catalog_service_test.json"

**Cause** : Le fichier JSON n'est pas dans les assets

**Solution** :
```bash
flutter clean
flutter pub get
flutter run
```

### Le panier ne fonctionne pas

**Cause** : Vérifier que vous avez bien ajouté l'import dans les fichiers de routage

**Solution** : Vérifier que ces lignes existent :
- `homepage_dias.dart:15` : `import 'package:wortis/class/catalog_service.dart';`
- `allservice.dart:8` : `import 'package:wortis/class/catalog_service.dart';`

---

## 💡 Recommandation

Pour la **production**, utilisez la **Méthode 1** (API Backend).

Pour **tester rapidement maintenant**, utilisez la **Méthode 2 - Option A** (bouton de test).

---

## 📝 Code du bouton de test (copier-coller)

Si vous voulez ajouter rapidement un bouton dans homepage_dias.dart :

```dart
// 1. Import en haut du fichier
import 'package:wortis/class/catalog_service.dart';

// 2. Quelque part dans le build(), ajouter ce FloatingActionButton :
FloatingActionButton.extended(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CatalogService(
          serviceName: 'boutique_alimentaire',
        ),
      ),
    );
  },
  label: const Text('Test Catalog'),
  icon: const Icon(Icons.shopping_cart),
  backgroundColor: Colors.orange,
)
```

---

**C'est tout !** Une fois que vous voyez la page Catalog s'ouvrir, tout le reste fonctionne automatiquement. 🎉
