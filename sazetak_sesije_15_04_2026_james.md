# JAMES — Sažetak sesije
## 15. April 2026 | Flutter motion guard APK — od ideje do v1.2.8

---

## 1. Kontekst — što je James

James je **motion guard** Android aplikacija — čuva uređaj od neovlaštenog pomicanja.
Kad netko pomakne uređaj, James šalje push notifikaciju kroz ntfy, Telegram ili HTTP webhook.

Originalna implementacija bila je bash skripta (`~/james.sh`) na termux-s7plus koja koristila
`termux-sensor` i `termux-api`. APK verzija zamjenjuje Termux dependency kompletnom nativnom
Flutter aplikacijom.

### Infrastruktura
| Parametar | Vrijednost |
|---|---|
| GitHub repo | github.com/fladroid/flutter-james |
| App package | com.fladroid.james |
| Balsam server | ~/flutter-james/james/ |
| Flutter | 3.41.6 |
| Zadnja verzija | v1.2.8+11 |
| Sender uređaj | Samsung Galaxy Tab SA9+ (Android 16, 11") |
| Receiver uređaj | Samsung SA55 (Android 16) — ntfy app |
| ntfy server | ntfy-balsam.dynu.net/james_guard |
| ntfy token | ~/.env.ntfy → NTFY_TOKEN |

---

## 2. Arhitektura aplikacije

### Stack
- Flutter + Dart
- `sensors_plus` — čita `linear_acceleration` (UserAccelerometer)
- `http` — ntfy/Telegram/webhook pozivi
- `shared_preferences` — persistentna konfiguracija
- `flutter_local_notifications` — lokalne notifikacije
- Android background `Service` + `WakeLock` — keepalive bez ForegroundService

### Struktura fajlova
```
james/
  lib/
    main.dart                    ← app init, async settings reload
    models/
      app_settings.dart          ← konfiguracija + SharedPreferences
      event_log.dart             ← EventEntry model (armed/disarmed/intrusion)
    services/
      translation_service.dart   ← i18n iz config.json
      notification_service.dart  ← ntfy / Telegram / webhook
    screens/
      home_screen.dart           ← ARM/DISARM, live magnitude, event log
      sensor_screen.dart         ← Sensor Explorer (live 3 senzora)
      settings_screen.dart       ← konfiguracija + kalibrator dugme
      calibration_screen.dart    ← 3-fazni kalibrator
  android/
    app/src/main/kotlin/com/fladroid/james/
      MainActivity.kt            ← MethodChannel start/stop service
      JamesService.kt            ← background Service + WakeLock
      BootReceiver.kt            ← autostart pri paljenju uređaja
    AndroidManifest.xml
  assets/
    config.json                  ← i18n (EN/HR/SR-lat/SR-cyr) + default settings
```

### Notifikacijski kanali
| Kanal | Opis |
|---|---|
| ntfy | Self-hosted ili ntfy.sh. Token auth opciono. |
| Telegram Bot | Bot token + chat ID. |
| HTTP Webhook | Bilo koji POST endpoint. |

### Jezici
EN, HR, SR-lat, SR-cyr — JSON config, dodavanje novog jezika = novi blok, bez promjena u kodu.

---

## 3. Što je napravljeno u sesiji

### 3.1 Inicijalni Flutter projekt
- `flutter create james --org com.fladroid --platforms android`
- pubspec.yaml s dependencies: sensors_plus, http, shared_preferences, flutter_local_notifications
- Struktura direktorija: models, services, screens

### 3.2 Sensor Explorer
- Live prikaz sva 3 senzora: linear_acceleration, raw accelerometer, gyroscope
- Magnituda u realnom vremenu + peak vrijednost
- Tip `UserAccelerometer` (linear_acceleration) je ispravan za detekciju pokreta — filtrira gravitaciju

**Kalibracijske vrijednosti SA9+:**
| Stanje | Magnituda |
|---|---|
| Mirovanje | 0.003 – 0.005 m/s² |
| Blago pomicanje | 0.32 – 0.44 m/s² |
| Jasno pomicanje | 1.0 – 5.0 m/s² |

Default threshold postavljen na **0.25 m/s²**.

### 3.3 Kalibrator (3 faze, zasebna dugmad)
- Svaka faza ima svoje **Measure** dugme — korisnik kontroliše tempo
- Faza 🛑 Resting (5s) → mjeri peak šum
- Faza 🤏 Gentle (5s) → mjeri min i peak
- Faza 💥 Strong (5s) → mjeri min i peak
- Algoritam: `threshold = max(restMax * 3, gentleMin / 2)`
- **Apply & Save** → upisuje threshold i postavlja `isCalibrated = true`
- **Redo** za svaku fazu zasebno
- Upozorenje ako threshold može propustiti gentle movement

### 3.4 Notifikacijski servis
- `NotificationService` — pluggable: ntfy, Telegram, webhook
- Armed: priority=low, tags=lock
- Disarmed: priority=low, tags=unlock
- Intrusion: priority=urgent, tags=warning,bell

### 3.5 Kalibracija banner
- Ako `isCalibrated = false` → narančasti banner na HomeScreen
- Tap → otvara kalibrator direktno
- Nestaje trajno nakon kalibracije

### 3.6 Settings validacija pri ARM
- Ako ntfy URL prazan → crvena greška "ntfy URL is empty — configure in Settings"
- Isto za Telegram i webhook
- Ne može se armirati bez konfiguriranog kanala

### 3.7 App ikona
- Shield + lock motiv, tamna pozadina (#050a14), plavi tonovi (#4a9eff)
- Generirana Python + cairosvg iz SVG
- Sve mipmap veličine (48-192px) + 512px za Play Store

### 3.8 Battery optimization dijalog
- Narančasti banner u Settings
- Tap → dijalog s uputama za Samsung One UI
- Settings → Apps → James → Battery → Unrestricted

---

## 4. Kritični problem — ForegroundService na Android 16

### Problem
SA9+ i SA55 su **Android 16**. Svaki pokušaj `startForegroundService()` rezultirao je
crashem s porukom "James keeps stopping".

### Pokušaji i zašto nisu radili
| Verzija | Pristup | Rezultat |
|---|---|---|
| v1.2.2 | foregroundServiceType="specialUse" | Crash — zahtijeva korisničku dozvolu |
| v1.2.4 | foregroundServiceType="health" + FOREGROUND_SERVICE_HEALTH | Crash |
| v1.2.5 | ForegroundService bez tipa | Crash — Android 14+ obavezno traži tip |
| v1.2.6 | Background Service + file debug log | Ne pada, ali ntfy ne radi |

### Dijagnoza
- Termux `logcat` nema pristup crash logovima na Android 16 bez roota
- Debug tehnika: pisati log u `getExternalFilesDir()` — čitljivo iz Termux
- `startForegroundService()` baca `ForegroundServiceStartNotAllowedException` tiho
- Na Android 16 nije moguće koristiti ForegroundService bez posebnih uvjeta

### Rješenje (v1.2.7+)
**Potpuno ukloniti ForegroundService.** Koristiti samo:
- Background `Service` (bez `startForeground`)
- `WakeLock` (PARTIAL_WAKE_LOCK) — sprječava CPU sleep
- Senzori i ntfy pozivi ostaju u Flutter threadu

Kompromis: ako korisnik swajpa app iz taskbara, monitoring staje.
Za "tablet u fioci" use case — prihvatljivo.

### Za S7+ (Android 13)
ForegroundService će raditi na S7+. Ako se James bude koristio na S7+,
treba conditional logiku po Android verziji.

---

## 5. Verzijska historija

| Verzija | Commit | Opis |
|---|---|---|
| v1.0.0+1 | b9c14dc | Init — sensors_plus, ntfy/Telegram/webhook, 4 jezika |
| v1.0.0+1 | b3c4023 | Threshold 0.25 m/s² (kalibriran SA9+) |
| v1.0.0+1 | f802eca | ForegroundService + WakeLock + BootReceiver |
| v1.0.0+1 | e8cdd25 | Kalibrator + battery opt dijalog + app ikona |
| v1.1.0+2 | 00624f8 | Calibration flag + banner, fix settings reload |
| v1.2.0+3 | 1a6db98 | ntfy direktno iz Kotlin JamesService |
| v1.2.1+4 | bd3477b | Debug logging |
| v1.2.2+5 | cbf6637 | foregroundServiceType=dataSync (nije pomoglo) |
| v1.2.3+6 | 402ee77 | foregroundServiceType uklonjen (nije pomoglo) |
| v1.2.4+7 | 4e1f458 | foregroundServiceType=health (nije pomoglo) |
| v1.2.5+8 | c9d9d98 | ForegroundService samo WakeLock keepalive |
| v1.2.6+9 | b3230d3 | File debug log |
| v1.2.7+10 | dedcfcd | ForegroundService potpuno uklonjen — fix! |
| v1.2.8+11 | 28d5492 | Validacija settings pri ARM |

---

## 6. Trenutni status

| Stavka | Status |
|---|---|
| Sensor Explorer | ✅ |
| Detekcija pokreta (linear_acceleration) | ✅ |
| Threshold + cooldown | ✅ |
| Kalibrator (3 faze, zasebna dugmad) | ✅ |
| ntfy notifikacije | ✅ Potvrđeno SA9+ → ntfy balsam → SA55 |
| Telegram Bot | ✅ Implementirano, nije testirano |
| HTTP Webhook | ✅ Implementirano, nije testirano |
| 4 jezika (EN/HR/SR-lat/SR-cyr) | ✅ |
| Validacija settings pri ARM | ✅ |
| Upozorenje za kalibraciju | ✅ |
| WakeLock (ekran ugašen) | ✅ |
| BootReceiver (autostart) | ✅ Implementirano, nije testirano |
| App ikona (shield/lock) | ✅ |
| Battery optimization upute | ✅ |
| ForegroundService (Android 16) | ❌ Nije moguće |
| Play Store listing | 📋 Planirano |

---

## 7. Sljedeći koraci

### 7.1 James — ostaje
- **Play Store listing** — Privacy Policy, store tekst, screenshotovi, closed testing
- **Test BootReceiver** — reboot SA9+ dok je armed, provjeri autostart
- **Test Telegram** — bot token + chat ID konfiguracija
- **ForegroundService za S7+** — conditional po Android verziji ako bude potrebno

### 7.2 Guardian — novi projekt
Motivacija: fall detection i geofence su legitimni, ali drugačiji use case od Jamesa.
- **Fall detection** — slobodan pad (magnituda → 0) + udar (magnituda 20-50+)
- **Geofence** — GPS udaljenost od definirane točke
- Ciljni korisnici: stariji, djeca
- Package: `com.fladroid.guardian`
- Zaseban Play Store listing

### 7.3 Analiza senzora
Dogovorena analiza interesantnih senzora kao uvod u Guardian:
- Leži / stoji / hoda / trči — akcelerometar + giroscop potpisi
- Pick up gesture, step detector, motion detect (hardware)
- Barometar — promjena visine
- Magnetometar — orijentacija

---

## 8. Build komanda

```bash
export PATH="$HOME/flutter/bin:$HOME/android-sdk/cmdline-tools/latest/bin:$HOME/android-sdk/platform-tools:$PATH"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
cd ~/flutter-james/james
flutter clean && flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ~/flutter-james/james.apk
```

### Verzioniranje
- `pubspec.yaml`: `version: X.Y.Z+N` — N mora rasti
- `lib/screens/home_screen.dart`: `'James vX.Y.Z'` u AppBar title
- Oba ažurirati zajedno

### APK download
```
https://github.com/fladroid/flutter-james/raw/refs/heads/main/james.apk
```

---

## 9. Važne tehničke napomene

> ⚠️ **Android 16**: `startForegroundService()` crasha bez iznimke. Koristiti samo background
> `Service` + `WakeLock`. Debug: log u `getExternalFilesDir()`.

> ⚠️ **Termux logcat** na Android 16 nema pristup app crashevima bez roota.

> ⚠️ **ntfy token** je u `~/.env.ntfy` na balsam serveru: `NTFY_TOKEN=tk_mtyvgr59p5frygpxxpqimu1o3mmxt`

> ⚠️ **Settings se brišu** pri deinstalaciji — korisnik mora ponovo unositi ntfy URL i token.
> Dodati export/import konfiguracije u budućoj verziji.

> ℹ️ **Gentle movement upozorenje** u kalibratoru nije bug — informativno upozorenje.
> Korisnik može ignorisati.

> ℹ️ **ntfy zvuk** ovisi o postavkama ntfy app na SA55 — nije dio James konfiguracije.

---

James | github.com/fladroid/flutter-james | fladroid@gmail.com | Sesija 15.04.2026.
