# Khelo & Jeeto — Flutter + Firebase + AdMob Project

Aapki `google-services.json` (`khelo-jeeto-9ab5f`, package `com.khelojeeto.app`) pehle hi is project mein laga di gayi hai!

## Mobile Se APK / Play Store AAB Kaise Banayein (Bina Laptop Ke)
1. **GitHub** (`github.com`) par ek naya repository banayein (naam: `khelo-jeeto`).
2. Is `.zip` ko unzip karke saari files us GitHub repository mein upload karein.
3. GitHub par **Actions** tab kholein → **"Build Khelo & Jeeto APK and AAB"** par click karein → **Run workflow** dabayein.
4. 3–4 minute mein aapko **`khelo-jeeto-builds`** zip milegi jismein aapki **`app-release.apk`** (phone par install karne ke liye) aur **`app-release.aab`** (Google Play Console par upload karne ke liye) hogi!

## Live AdMob IDs Kab Aur Kahan Dalni Hain?
Abhi ismein Google ki official Test Ad IDs lagi hain. Play Store par daalne se pehle bas 2 jagah apni asli AdMob IDs dal dein:
1. `android/app/src/main/AndroidManifest.xml` -> `ca-app-pub-3940256099942544~3347511713` ki jagah apni **AdMob App ID**.
2. `lib/config/app_config.dart` -> `ca-app-pub-3940256099942544/5224354917` ki jagah apni **Rewarded Ad Unit ID**.
