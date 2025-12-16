# 🔧 Fix Google Sign-In - Connexion Google ne passe pas

## 🔍 Problème identifié

La connexion avec Google ne fonctionne pas car **les configurations iOS et Android manquent** dans les fichiers natifs.

## ✅ Configurations manquantes

### iOS - `Info.plist`
- ❌ Pas de `CFBundleURLTypes` pour le reversed client ID
- ❌ Pas de `GIDClientID`

### Android
- ✅ Permissions OK
- ⚠️ Vérifier le fichier `google-services.json`

---

## 🛠️ Solution : Configuration iOS

### Étape 1 : Modifier `ios/Runner/Info.plist`

Ajouter **AVANT** la balise fermante `</dict>` (ligne 60) :

```xml
<!-- ✨ CONFIGURATION GOOGLE SIGN-IN POUR iOS -->
<key>CFBundleURLTypes</key>
<array>
	<dict>
		<key>CFBundleTypeRole</key>
		<string>Editor</string>
		<key>CFBundleURLSchemes</key>
		<array>
			<!-- ⚠️ REMPLACER PAR VOTRE REVERSED CLIENT ID -->
			<string>com.googleusercontent.apps.632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb</string>
		</array>
	</dict>
</array>

<!-- Google Sign-In Client ID (pour iOS) -->
<key>GIDClientID</key>
<string>632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb.apps.googleusercontent.com</string>
```

### ⚠️ IMPORTANT : Reversed Client ID

Le reversed client ID se construit ainsi :
- **Client ID iOS** : `632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb.apps.googleusercontent.com`
- **Reversed** : `com.googleusercontent.apps.632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb`

**Comment le construire :**
1. Prendre le client ID : `632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb.apps.googleusercontent.com`
2. Retirer `.apps.googleusercontent.com`
3. Inverser : `com.googleusercontent.apps.632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb`

---

## 🛠️ Solution : Configuration Android

### Étape 1 : Vérifier le fichier `google-services.json`

**Chemin** : `android/app/google-services.json`

Ce fichier doit exister et contenir votre configuration Firebase/Google.

Si le fichier n'existe pas :

1. Aller sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionner votre projet
3. Aller dans **Paramètres du projet** (icône engrenage)
4. Onglet **Général**
5. Défiler vers **Vos applications**
6. Cliquer sur l'icône Android
7. Télécharger `google-services.json`
8. Placer le fichier dans `android/app/google-services.json`

### Étape 2 : Vérifier `android/build.gradle`

Le fichier doit contenir :

```gradle
buildscript {
    dependencies {
        // Google Services plugin
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

### Étape 3 : Vérifier `android/app/build.gradle`

À la fin du fichier, vérifier la présence de :

```gradle
apply plugin: 'com.google.gms.google-services'
```

---

## 🔐 Vérification des Client IDs

### Dans `lib/class/class.dart` (lignes 1547-1551)

```dart
await _googleSignIn.initialize(
  serverClientId: Platform.isIOS
      ? '632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb.apps.googleusercontent.com'  // iOS
      : '632922069265-e76ug6cklkbeda91ed8ht571um2fh7jl.apps.googleusercontent.com', // Android
);
```

### Vérifier sur Google Cloud Console

1. Aller sur [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionner votre projet
3. Menu **APIs & Services** > **Credentials**
4. Vérifier que vous avez bien :
   - **OAuth 2.0 Client ID (iOS)** : `632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb.apps.googleusercontent.com`
   - **OAuth 2.0 Client ID (Android)** : `632922069265-e76ug6cklkbeda91ed8ht571um2fh7jl.apps.googleusercontent.com`

### Configuration iOS sur Google Cloud

Pour l'iOS Client ID, vérifier :
- **Bundle ID** : `cg.wortis.wortis` (doit correspondre à votre app)
- **URL Scheme** : `com.googleusercontent.apps.632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb`

### Configuration Android sur Google Cloud

Pour l'Android Client ID, vérifier :
- **Package name** : doit correspondre à votre `applicationId` dans `android/app/build.gradle`
- **SHA-1 certificate fingerprint** : doit être configuré

---

## 📱 Obtenir le SHA-1 pour Android

### Debug SHA-1

```bash
cd android
./gradlew signingReport
```

Ou via keytool :

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Release SHA-1 (si vous testez en production)

```bash
keytool -list -v -keystore /path/to/your/release.keystore -alias your_alias
```

**Important** : Ajouter ce SHA-1 dans la configuration Android de Google Cloud Console.

---

## 🧪 Test après configuration

### 1. Nettoyer le projet

```bash
flutter clean
cd ios
pod deintegrate
pod install
cd ..
flutter pub get
```

### 2. Rebuild complet

Pour iOS :
```bash
flutter build ios --debug
```

Pour Android :
```bash
flutter build apk --debug
```

### 3. Lancer l'app

```bash
flutter run
```

### 4. Tester la connexion Google

1. Cliquer sur "Se connecter avec Google"
2. La popup Google devrait s'ouvrir
3. Sélectionner un compte
4. Accepter les permissions
5. Vérifier la redirection vers l'app

---

## 🐛 Débogage

### Activer les logs Google Sign In

Dans `lib/class/class.dart`, décommenter les prints (lignes 1561, 1582, 1596, etc.) :

```dart
print('🔵 [GoogleAuth] Début de la connexion Google');
print('✅ [GoogleAuth] Token Google obtenu');
print('📡 [GoogleAuth] Réponse serveur: ${response.statusCode}');
```

### Erreurs courantes

#### Erreur : "PlatformException(sign_in_failed)"

**Cause** : `Info.plist` mal configuré (iOS) ou SHA-1 manquant (Android)

**Solution** :
- iOS : Vérifier le reversed client ID dans Info.plist
- Android : Ajouter le SHA-1 dans Google Cloud Console

#### Erreur : "Developer Error"

**Cause** : Client ID incorrect ou pas configuré sur Google Cloud Console

**Solution** : Vérifier que le Bundle ID (iOS) ou Package Name (Android) correspond

#### Erreur : "Invalid_client"

**Cause** : Le serverClientId dans le code ne correspond pas à celui de Google Cloud

**Solution** : Copier exactement le Client ID depuis Google Cloud Console

#### L'écran Google ne s'ouvre pas (iOS)

**Cause** : `CFBundleURLTypes` manquant dans Info.plist

**Solution** : Ajouter la configuration URL Scheme dans Info.plist

---

## ✅ Checklist de configuration

### iOS
- [ ] `Info.plist` contient `CFBundleURLTypes` avec reversed client ID
- [ ] `Info.plist` contient `GIDClientID`
- [ ] Bundle ID correspond sur Google Cloud Console
- [ ] Client ID iOS existe sur Google Cloud Console
- [ ] Pod install exécuté après modifications

### Android
- [ ] `google-services.json` présent dans `android/app/`
- [ ] `android/build.gradle` contient google-services plugin
- [ ] `android/app/build.gradle` applique le plugin
- [ ] SHA-1 debug configuré sur Google Cloud Console
- [ ] SHA-1 release configuré (si test en production)
- [ ] Package name correspond sur Google Cloud Console

### Backend
- [ ] Endpoint `/famlink/api/auth/google/login` fonctionne
- [ ] Backend valide correctement le token Google
- [ ] Backend retourne `200` pour utilisateur existant
- [ ] Backend retourne `201` pour nouvel utilisateur

---

## 📄 Fichier Info.plist complet (iOS)

Voici le fichier complet avec Google Sign-In configuré :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>Wortis</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>wortis</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$(FLUTTER_BUILD_NAME)</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>$(FLUTTER_BUILD_NUMBER)</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>NSCameraUsageDescription</key>
	<string>Cette application a besoin d'accéder à votre appareil photo pour scanner des codes QR et prendre des photos.</string>
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>Nous utilisons votre localisation pour afficher le contenu adapté à votre pays.</string>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Nous utilisons votre localisation pour afficher le contenu adapté à votre pays et améliorer votre expérience.</string>
	<key>NSPhotoLibraryAddUsageDescription</key>
	<string>Cette application a besoin d'accéder à vos photos pour enregistrer des images.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Cette application a besoin d'accéder à vos photos pour sélectionner des images.</string>
	<key>NSUserTrackingUsageDescription</key>
	<string>Cette application nécessite votre autorisation pour suivre votre activité afin de vous proposer des publicités personnalisées et améliorer votre expérience.</string>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
	<key>UILaunchStoryboardName</key>
	<string>LaunchScreen</string>
	<key>UIMainStoryboardFile</key>
	<string>Main</string>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>

	<!-- ✨ CONFIGURATION GOOGLE SIGN-IN -->
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>com.googleusercontent.apps.632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb</string>
			</array>
		</dict>
	</array>

	<key>GIDClientID</key>
	<string>632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb.apps.googleusercontent.com</string>
</dict>
</plist>
```

---

## 🚀 Commandes rapides

### Nettoyer et rebuild iOS

```bash
flutter clean
cd ios
pod deintegrate
pod install
cd ..
flutter run
```

### Nettoyer et rebuild Android

```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter run
```

---

## 📞 Support supplémentaire

Si le problème persiste après avoir suivi ce guide :

1. Vérifier les logs Flutter : `flutter run -v`
2. Vérifier les logs Xcode (iOS) : ouvrir `ios/Runner.xcworkspace` dans Xcode
3. Vérifier les logs Android : `adb logcat | grep Google`
4. Vérifier que le backend `/famlink/api/auth/google/login` répond correctement

---

**Bonne chance !** 🎉
