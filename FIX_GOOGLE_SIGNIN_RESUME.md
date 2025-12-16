# 🔧 Fix Google Sign-In - Résumé

## ✅ Ce qui a été fait

### iOS - Info.plist
- ✅ **CORRIGÉ** : Ajout de `CFBundleURLTypes` avec reversed client ID
- ✅ **CORRIGÉ** : Ajout de `GIDClientID`

Fichier modifié : `ios/Runner/Info.plist`

---

## ⚠️ Ce qu'il reste à faire

### Android - Configuration Google Services

Le fichier `google-services.json` **n'existe pas** dans `android/app/`.

#### 🔥 Action requise (Android)

**Étape 1 : Obtenir le fichier google-services.json**

1. Aller sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionner votre projet **Wortis**
3. Cliquer sur l'icône **Paramètres** (engrenage) > **Paramètres du projet**
4. Onglet **Général**
5. Défiler vers **Vos applications**
6. Trouver l'application Android avec package : `cg.wortispay.wortispay`
7. Cliquer sur **Télécharger google-services.json**
8. Placer le fichier dans : `/Users/wortis/Downloads/wortis_new/android/app/google-services.json`

**Étape 2 : Configurer Google Sign-In dans Firebase**

1. Dans Firebase Console, aller dans **Authentication** (menu de gauche)
2. Onglet **Sign-in method**
3. Activer **Google** comme fournisseur
4. Sauvegarder

**Étape 3 : Configurer OAuth sur Google Cloud Console**

1. Aller sur [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionner votre projet
3. Menu **APIs & Services** > **Credentials**
4. Vérifier que vous avez un **OAuth 2.0 Client ID** pour Android :
   - **Application type** : Android
   - **Package name** : `cg.wortispay.wortispay`
   - **SHA-1 certificate fingerprint** : (voir ci-dessous comment l'obtenir)

**Étape 4 : Obtenir et ajouter le SHA-1**

Pour le mode **debug** :

```bash
cd /Users/wortis/Downloads/wortis_new/android
./gradlew signingReport
```

Copier le **SHA-1** qui apparaît dans la section `debug` et l'ajouter dans Google Cloud Console.

Pour le mode **release** (production) :

```bash
keytool -list -v -keystore /Users/wortis/Downloads/wortis_new/KeyStoreAndroid/deploy.3.0.0.wortispay.jks -alias key0 -storepass wortispay.cg
```

Copier le **SHA-1** et l'ajouter également dans Google Cloud Console.

---

## 🧪 Test après configuration

### 1. Nettoyer et rebuild

```bash
cd /Users/wortis/Downloads/wortis_new
flutter clean
flutter pub get
```

Pour iOS :
```bash
cd ios
pod deintegrate
pod install
cd ..
```

### 2. Rebuild l'app

```bash
flutter run
```

### 3. Tester la connexion Google

1. Cliquer sur **"Se connecter avec Google"**
2. La popup Google devrait s'ouvrir
3. Sélectionner un compte Google
4. Accepter les permissions
5. Vérifier la connexion réussie

---

## 🐛 Vérification des erreurs

### Logs à surveiller

```bash
flutter run -v | grep -i google
```

### Erreurs courantes

**"PlatformException(sign_in_failed)"**
- ❌ Cause : SHA-1 manquant (Android) ou Info.plist mal configuré (iOS)
- ✅ Solution : Ajouter SHA-1 dans Google Cloud Console (Android) ou vérifier Info.plist (iOS - déjà fait)

**"Developer Error"**
- ❌ Cause : Client ID incorrect ou package name ne correspond pas
- ✅ Solution : Vérifier que le package `cg.wortispay.wortispay` est configuré sur Google Cloud

**"INVALID_CLIENT"**
- ❌ Cause : Le serverClientId dans le code ne correspond pas à Google Cloud
- ✅ Solution : Vérifier les Client IDs dans `lib/class/class.dart:1548-1551`

---

## 📊 Récapitulatif des Client IDs

### Dans le code (lib/class/class.dart)

```dart
serverClientId: Platform.isIOS
    ? '632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb.apps.googleusercontent.com'  // iOS
    : '632922069265-e76ug6cklkbeda91ed8ht571um2fh7jl.apps.googleusercontent.com', // Android
```

### Sur Google Cloud Console

Vérifier que ces deux Client IDs existent avec :

**iOS Client ID** :
- Client ID : `632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb.apps.googleusercontent.com`
- Bundle ID : `cg.wortis.wortis`
- URL Scheme : `com.googleusercontent.apps.632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb`

**Android Client ID** :
- Client ID : `632922069265-e76ug6cklkbeda91ed8ht571um2fh7jl.apps.googleusercontent.com`
- Package name : `cg.wortispay.wortispay`
- SHA-1 : À ajouter via `gradlew signingReport`

---

## ✅ Checklist finale

### iOS
- [x] `Info.plist` contient `CFBundleURLTypes` ✅
- [x] `Info.plist` contient `GIDClientID` ✅
- [ ] Client ID iOS existe sur Google Cloud Console
- [ ] Bundle ID `cg.wortis.wortis` configuré sur Google Cloud
- [ ] Test connexion Google sur iPhone/Simulator

### Android
- [ ] Télécharger `google-services.json` depuis Firebase
- [ ] Placer `google-services.json` dans `android/app/`
- [ ] Obtenir SHA-1 debug via `gradlew signingReport`
- [ ] Obtenir SHA-1 release via keytool
- [ ] Ajouter les deux SHA-1 sur Google Cloud Console
- [ ] Client ID Android existe sur Google Cloud Console
- [ ] Package name `cg.wortispay.wortispay` configuré
- [ ] Test connexion Google sur appareil Android

### Backend
- [ ] Endpoint `/famlink/api/auth/google/login` fonctionne
- [ ] Backend accepte et valide le token Google
- [ ] Backend retourne `200` pour utilisateur existant
- [ ] Backend retourne `201` pour nouvel utilisateur

---

## 📞 Commandes utiles

### Obtenir SHA-1 debug (Android)
```bash
cd /Users/wortis/Downloads/wortis_new/android
./gradlew signingReport | grep SHA1
```

### Obtenir SHA-1 release (Android)
```bash
keytool -list -v -keystore /Users/wortis/Downloads/wortis_new/KeyStoreAndroid/deploy.3.0.0.wortispay.jks -alias key0 -storepass wortispay.cg | grep SHA1
```

### Nettoyer projet iOS
```bash
cd /Users/wortis/Downloads/wortis_new/ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

### Rebuild complet
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📝 Prochaine étape

**Action immédiate** : Télécharger et ajouter `google-services.json` pour Android.

Voir le fichier `FIX_GOOGLE_SIGNIN.md` pour la documentation complète.

---

**Note** : La configuration iOS est déjà corrigée. Il ne manque que la configuration Android (fichier `google-services.json` + SHA-1).
