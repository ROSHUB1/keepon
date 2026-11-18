# KEEPON

Protection that keeps going. Android-first anti-theft and device protection app (Flutter + Kotlin).

## What is implemented
- Design system (light/dark, glass surfaces, floating navigation) and 5 screens: Home, Protection, Activity, Recovery, Settings.
- Local storage: settings, protection configuration, event history, last saved location.
- Native Android engine (Kotlin): foreground monitoring service, motion (accelerometer), charger, headphones (wired/USB/Bluetooth), SIM state, alarm with volume/vibration/auto-stop, boot restart, real location on demand, permission requests.

## Anti-theft core (v0.8)
- Detection: charger (2 s confirmation), sustained motion, headphones, SIM. Owner-present filter and an entry delay the owner cancels by unlocking.
- Protection session: saved to device-protected storage; survives process death and reboot (Direct Boot). Optional screen lock through Android device admin.
- Alarm: synthesized security siren (AudioTrack), audio focus, speaker routing, watchdog with fallback to the system alarm sound.
- Location: recorded during an alarm session (current vs last known, online/offline), encrypted with a Keystore key, kept on the phone only. No server exists yet, so nothing is transmitted.
- Reboot: LOCKED_BOOT_COMPLETED / BOOT_COMPLETED restart the single service; the alarm only resumes if a session was active.

## Not implemented yet
- In-app remote lock (Device Admin). Recovery uses Google Find Hub.
- Custom Inter font, app icon, splash screen, release signing.

## Not tested on a device yet
Everything here was written without running it. Test on a real phone and report what breaks.

## Build
Pushing to `main` runs GitHub Actions and builds a debug APK (Actions tab -> run -> Artifacts).
Never commit signing keys, `key.properties`, `.env` or API keys. See `.gitignore`.
