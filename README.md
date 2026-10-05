# BAM King / Kumakan

Application mobile Android de **banque vocale en bambara** pour les utilisateurs non-lettrés en français.

> **Prototype de démonstration** — Ce projet est une preuve de concept UX/recherche. Les soldes, comptes et transactions sont des données Firebase fictives. Il n'a pas été audité pour la sécurité, ni certifié, ni conçu pour manipuler de vrais fonds.

---

## 🎯 Objectif

Démontrer qu'une interface bancaire vocale utile en bambara **ne nécessite pas** une pile lourde de type ASR multilingue + LLM + traduction + TTS. Une **petite collection de modèles étroits exécutés localement** peut reconnaître des intentions bancaires ciblées, collecter des slots numériques, et vocaliser des réponses dans la langue de l'utilisateur.

---

## ✨ Fonctionnalités

| Domaine | Actions supportées |
|---|---|
| **Navigation** | Home, Operations, FAQ, Profile, Déconnexion |
| **Consultation** | Solde du compte de démonstration |
| **Transfert** | Préparation et confirmation de virements compte/mobile-money |
| **FAQ** | Recherche vocale dans une FAQ bambara |
| **Saisie** | Montants et numéros dictés à la voix |
| **Synthèse** | Retour vocal en bamanankan via VITS |

---

## 🏗️ Architecture

```
Microphone
   ├─> SLU (Speech Intent + Slots)  ─> Intent validé ─> Action / Firestore
   └─> Number ASR ─> Normaliseur bambara ─> Slots de transfert
                                                    │
Template de réponse <─ Cache VITS (TTS) <───────────┘
```

**Tout tourne sur l'appareil.** Firebase fournit uniquement :
- L'**authentification** (Firebase Auth)
- Les **données de démonstration** (Cloud Firestore)
- Le **stockage des modèles ONNX** (Firebase Storage — bucket `africa-voice-mali`)

---

## 🧠 Modèles et provenance

Tous les modèles vocaux proviennent de [RobotsMali / mobilebamspeech](https://github.com/RobotsMali-AI/mobilebamspeech).

| Composant | Objet Firebase | Rôle |
|---|---|---|
| **Number ASR** | `models/2026-09-02-v1/asr/quartznum.onnx` | Reconnaît les montants et chiffres |
| **SLU (intent + slots)** | `models/2026-09-02-v1/slu/soloni-ic-slot-fintech-v0-{encoder,embedding,decoder,classifier}.onnx` | Produit `scenario`, `action`, `entities` |
| **VITS TTS** | `models/2026-09-02-v1/vits/bam-vits.onnx` | Synthétise les retours vocaux bambara |

**Vocabulaire TTS** : `assets/vits/tokens.txt` est inclus dans le bundle.

---

## 📋 Prérequis

| Outil | Version |
|---|---|
| **Flutter** | avec Dart ≥ 3.7 |
| **Android SDK** | 36 |
| **Android NDK** | 27.0.12077973 ou 28.x |
| **Appareil Android** | **arm64-v8a**, minSdk 24, 2018+ |
| **Python** | 3.12 + pip |
| **Firebase** | projet avec Auth + Firestore + Storage |

### Téléphones compatibles

- Samsung Galaxy S8 et plus récents
- Google Pixel (tous)
- Xiaomi Redmi Note 8 et plus récents
- OnePlus 6 et plus récents
- Huawei P20 et plus récents
- Tout Android 2018+ arm64-v8a

### Vérification de l'environnement

```bash
flutter doctor
flutter pub get
```

### Vérifier que le téléphone est arm64-v8a

```bash
adb devices
adb shell getprop ro.product.cpu.abi
```

**Résultat attendu** : `arm64-v8a`

Si le résultat est `armeabi-v7a` ou `x86_64`, le téléphone **n'est pas compatible**.

---

## 🔥 Configuration Firebase

1. **Créer un projet Firebase** : `mobamking`
2. **Package Android** : `com.example.kumakan_flutter`
3. **Générer les fichiers FlutterFire** :

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

4. **Activer les services** :
   - Authentication → Email/Password
   - Firestore Database → Créer une base
   - Storage → Créer un bucket

5. **Règles Firestore** :

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} { allow read, write: if request.auth != null; }
    match /transactions/{txId} { allow read, write: if request.auth != null; }
    match /FAQ/{docId} { allow read: if true; }
    match /voice_collection/{docId} { allow read, write: if request.auth != null; }
  }
}
```

6. **Règles Storage** :

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /models/{allPaths=**} { allow read: if true; }
    match /{allPaths=**} { allow read, write: if request.auth != null; }
  }
}
```

---

## 📦 Empaqueter le normaliseur Python

```bash
mkdir -p build/site-packages/arm64-v8a
python3.12 -m pip install \
  -r app/src/requirements.txt \
  --target build/site-packages/arm64-v8a

export SERIOUS_PYTHON_SITE_PACKAGES="$PWD/build/site-packages"
dart run serious_python:main package app/src -p Android -r Flask -r bambara-normalizer
```

**Attendu** : `Package created: .../app/app.zip`

### Vérifier `build.gradle.kts`

```bash
grep -A 3 "ndk" android/app/build.gradle.kts
```

Attendu :

```kotlin
ndk {
    abiFilters.clear()
    abiFilters.addAll(listOf("x86_64", "arm64-v8a"))
}
```

---

##  Lancer l'application

### Sur un téléphone arm64-v8a (mode debug)

```bash
flutter devices
SERIOUS_PYTHON_SITE_PACKAGES="$PWD/build/site-packages" \
  flutter run -d <device-id>
```

Le build prend 2 à 5 minutes la première fois. Au premier lancement, le SplashScreen télécharge ~692 MB de modèles ONNX (5 à 15 minutes selon la connexion) — ne pas fermer l'app pendant le téléchargement.

### Sur Waydroid (x86_64 — pour tester l'UI uniquement)

```bash
waydroid show-full-ui &
SERIOUS_PYTHON_SITE_PACKAGES="$PWD/build/site-packages" \
  flutter run -d <waydroid-ip>:5555
```

**Sur Waydroid** : l'ASR, le SLU et le Python **ne fonctionnent pas** (libs arm64-v8a uniquement). Le TTS et Firebase fonctionnent.

---

##  Construire un APK

```bash
SERIOUS_PYTHON_SITE_PACKAGES="$PWD/build/site-packages" \
  flutter build apk --release \
  --target-platform android-arm64 \
  --split-per-abi
```

APK généré : `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

---

##  Guide de test manuel

### 1. Créer un compte

Sur **LoginScreen** → **« Kɔnti kura »**, remplir :

| Champ | Valeur |
|---|---|
| Nom complet | `Test User` |
| Adresse email | (laisser vide) |
| Téléphone | `76000001` (numéro jamais utilisé) |
| PIN | `1234` |
| Confirmer le PIN | `1234` |
| Conditions | Cocher |

**Résultat attendu** : message vert « Compte créé avec succès ! », redirection vers AppShell, solde de démonstration affiché à **50 000 FCFA**.

### 2. Tester le micro

1. Depuis AppShell, appuyer sur le micro en bas
2. VoiceScreen s'ouvre
3. Appuyer longuement sur l'orbe central
4. Accepter la permission micro demandée par Android

### 3. Tester une phrase vocale

Appui long sur l'orbe et dire :

> « Ci Boubacar Koné ma 5000 »

Relâcher. Résultat attendu :

1. **Transcription** (ASR) : le texte s'affiche
2. **Interprétation** (SLU) : `5000 FCFA` + `Boubacar Koné`
3. Le bouton **« Confirmer la transaction »** apparaît
4. Le **TTS** vocalise : *« I ye 5000 ci ni kɔnti la: Boubacar Koné »*

Confirmer ensuite la transaction : le transfert s'exécute dans Firestore, l'app redirige vers HistoryTab où la transaction apparaît en surbrillance.

### 4. Autres commandes vocales

| Commande | Résultat attendu |
|---|---|
| « N ka wari jate » | Le solde est affiché et lu à voix haute |
| « K'i ɲɛda Home kan » | Navigation vers HomeTab + confirmation TTS |
| « Bɔ » | Déconnexion et retour à LoginScreen |

### 5. Vérifications dans Firebase

- **Authentication** : l'utilisateur `76000001@kumakan.app` doit être créé
- **Firestore** :
  - Collection `users` → document avec `fullName`, `phone`, `balance: 50000`
  - Collection `transactions` → document du transfert effectué

### Résumé des tests

| # | Test | Résultat attendu |
|---|---|---|
| 1 | Inscription | Compte créé dans Firebase |
| 2 | Connexion | Accès à AppShell |
| 3 | Solde affiché | 50 000 FCFA |
| 4 | Appui long sur orbe | Enregistrement micro |
| 5 | Parle bambara | Transcription ASR |
| 6 | Interprétation | Montant + bénéficiaire |
| 7 | Confirmation | Transfert Firestore |
| 8 | TTS | Confirmation vocale bambara |
| 9 | Historique | Transaction listée |
| 10 | Déconnexion | Retour LoginScreen |

---

## 🧪 Contrôles qualité

```bash
dart format lib test
flutter analyze
flutter test
PYTHONPATH=build/site-packages/arm64-v8a \
  python3.12 -m unittest app/test_main.py
```

---

## Diagnostic des erreurs

| Erreur / symptôme | Cause probable | Solution |
|---|---|---|
| `libNeMoOnnxSharp.so not found` | Le téléphone n'est pas arm64-v8a | Changer de téléphone |
| `libpyjni.so not found` | `app.zip` mal packagé | Relancer `serious_python:main package`, puis `flutter clean && flutter pub get && flutter run` |
| `The query requires an index` | Index Firestore manquant | Cliquer sur le lien fourni dans les logs pour créer l'index |
| TTS silencieux | Volume média à 0 | Monter le volume média du téléphone |
| Permission micro refusée | Permission refusée par l'utilisateur | Paramètres → Applications → Kumakan → Permissions → Micro → Autoriser |

### Logs utiles

```bash
adb logcat | grep -E "flutter|kumakan|TTS|SLU|ASR"
```

| Préfixe | Signification |
|---|---|
| `[BOOTSTRAP]` | Initialisation des services |
| `[MODEL:*]` | Téléchargement et cache des modèles |
| `[SLU]` | Reconnaissance vocale |
| `[TTS]` | Synthèse vocale |
| `[PY]` | Python embarqué |
| `[ACTION]` | Exécution des intentions |
| `[DB]` | Firestore |
| `[RECORD]` | Enregistrement micro |
| `[AUTH]` | Firebase Auth |

---

## Limitations connues

- **Android arm64-v8a uniquement** — les libs natives ne fonctionnent pas sur x86_64
- **Waydroid** — UI + Firebase + TTS OK, mais ASR/SLU/Python KO
- **Actions limitées** — seules celles de `VoiceIntent.supportedActions`
- **TTS lent** sur longs textes
- **Premier lancement** — 692 MB à télécharger, ~800 MB d'espace requis
- **Debug builds verbeux** — peuvent exposer les sorties modèle

---

##  Structure du dépôt

```
lib/
├── models/        Structures d'intent validées
├── services/      Vocaux, TTS, modèles, Python, Firebase, recording
├── screens/       Écrans d'application
├── widget/        Composants UI réutilisables
├── core/          Bindings natifs, vocabulaires, extraction d'assets
└── theme/         Thème global

assets/            FAQ bambara + tokens VITS
app/src/           Service Flask de normalisation bambara
python-utils/      Outils Firebase optionnels
test/              Tests Flutter
app/test_main.py   Tests Python
android/app/src/main/jniLibs/arm64-v8a/   Libs natives (.so)
```

---

## 🔗 Travaux liés

| Ressource | Lien |
|---|---|
| **mobilebamspeech** | https://github.com/RobotsMali-AI/mobilebamspeech |
| **bambara-asr** | https://github.com/RobotsMali-AI/bambara-asr |
| **vits-bam** | https://github.com/RobotsMali-AI/vits-bam |
| **bambara-normalizer** | https://github.com/diarray-hub/bambara-normalizer |
| **NeMoOnnxSharp** | https://github.com/kaiidams/NeMoOnnxSharp |

---

##  Licence

Apache 2.0 (voir `LICENSE`).

Les modèles vocaux conservent leurs licences respectives.

---

##  Remerciements

- **RobotsMali AI** pour les modèles vocaux bambara ouverts
- **NVIDIA NeMo** pour les architectures ASR/SLU
- **Katsuya Iida** pour NeMoOnnxSharp
- **L'équipe Flutter** pour l'écosystème mobile

---

**Prototype de recherche — 2026**
Ne pas utiliser avec de vrais fonds.