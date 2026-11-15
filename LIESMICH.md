# 🛡 Schildwall für iPhone

Werbeblocker-Browser fürs iPhone (ab iOS 15, z. B. iPhone 13).
Gleiche Blocklisten und YouTube-Regeln wie die Android-Version.

**Funktionen:** Werbe- und Tracking-Server blockieren, YouTube-Werbung überspringen,
Werbeflächen ausblenden, Popups blockieren, Knopf «Cookies & Website-Daten löschen».

**Nicht möglich (mit Gratis-Apple-ID):** Hintergrund-Schutz für alle Apps.
Dafür verlangt Apple ein kostenpflichtiges Entwicklerkonto.

---

## 1. App bauen lassen (GitHub, gratis)
1. Auf github.com einloggen → oben rechts **+** → **New repository**
2. Name: `Schildwall-iOS`, **Public** wählen → **Create repository**
3. Auf **uploading an existing file** klicken
4. Den **Inhalt** des entpackten Ordners `Schildwall-iOS` (alle Dateien und Ordner, auch `.github`) ins Browserfenster ziehen → **Commit changes**
5. Oben auf **Actions** → der Bau «iPhone-App bauen» startet automatisch (ca. 5–10 Min.)
6. Wenn er grün ist: anklicken → unten bei **Artifacts** «Schildwall-iPhone» herunterladen → ZIP entpacken → `Schildwall.ipa`

Falls der Ordner `.github` beim Hochladen fehlt: im Repository **Add file → Create new file**,
Name `.github/workflows/build.yml` eintippen und den Inhalt der Datei hineinkopieren.

## 2. Aufs iPhone installieren (Sideloadly, Windows)
1. Auf dem PC installieren: **iTunes** und **iCloud** (Versionen direkt von apple.com, nicht aus dem Microsoft Store), dann **Sideloadly** (sideloadly.io)
2. iPhone per Kabel anschliessen, auf dem iPhone «Vertrauen» tippen
3. Sideloadly öffnen → `Schildwall.ipa` ins Fenster ziehen → Apple-ID eintragen → **Start**
4. Auf dem iPhone:
   - Einstellungen → Allgemein → **VPN & Geräteverwaltung** → Apple-ID antippen → **Vertrauen**
   - Einstellungen → Datenschutz & Sicherheit → **Entwicklermodus** einschalten (iPhone startet neu)

Tipp: Eine separate, neue Gratis-Apple-ID nur dafür verwenden.

## 3. Alle 7 Tage erneuern
Mit Gratis-Apple-ID läuft die App nach 7 Tagen ab. Einfach in Sideloadly erneut installieren
(gleiche IPA, gleiche Apple-ID) – die Daten bleiben erhalten. Max. 3 selbst installierte Apps gleichzeitig.

## Anpassen
`Resources/hosts.txt`, `Resources/youtube.js`, `Resources/cosmetic.css` – gleiche Dateien wie bei Android.
Änderung auf GitHub hochladen → Bau startet automatisch neu.

---

## Bonus: Schildwall-DNS-Profil (Schutz für ALLE Apps, gratis)
Die Datei `Schildwall-DNS.mobileconfig` blockiert Werbung, Tracker, Schadsoftware und Phishing
in allen Apps – ohne App, ohne Entwicklerkonto, gilt im WLAN und Mobilfunk.

**Installieren (eine der Varianten):**
- **Per E-Mail:** Datei an die Person mailen → in der Apple-Mail-App antippen
- **Per GitHub:** Datei liegt im Repository → auf dem iPhone in **Safari** öffnen → «Raw»/Download antippen → «Erlauben»

Danach: Einstellungen → oben **«Profil geladen»** → **Installieren** (Hinweis «nicht signiert» ist normal).
Test: adguard.com/test.html in Safari öffnen.

**Entfernen:** Einstellungen → Allgemein → VPN & Geräteverwaltung → Profil → Entfernen.
Hinweis: Läuft eine VPN-App, ist das Profil so lange wirkungslos.
