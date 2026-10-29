# Disk Archive Beta – Installieren und Öffnen

*Entwurf Host 29.10.2026 für die Download-Seite `https://diskarchive.app/` (`todo.0.4.021`, Zielversion 0.4.1). Der Nutzer prüft und kürzt; Texte im Ton der App (du).*

---

**Voraussetzung:** macOS 15 Sequoia oder neuer, Mac mit Apple-Chip oder Intel.

Die Beta ist noch nicht von Apple beglaubigt (notarisiert). macOS fragt deshalb beim ersten Öffnen einmal nach. Das dauert eine Minute.

## Installieren

1. **DMG laden und öffnen:** Doppelklick auf `Disk-Archive-0.4.1.dmg`.
2. **In „Programme“ ziehen:** Im Fenster das App-Symbol auf den Ordner „Programme“ ziehen. Wichtig: Die App nicht direkt aus dem DMG oder aus „Downloads“ starten, sonst startet macOS sie von einem wechselnden Ort.
3. **DMG auswerfen** (in der Finder-Seitenleiste auf ⏏ klicken).

## Beim ersten Öffnen

4. **Öffnen:** „Disk Archive“ in „Programme“ doppelklicken. macOS meldet: *„Disk Archive“ kann nicht geöffnet werden*. Auf **Fertig** klicken (nicht „In den Papierkorb“).
5. **Freigeben:** **Systemeinstellungen → Datenschutz & Sicherheit** öffnen, ganz nach unten zum Abschnitt **Sicherheit** scrollen. Dort steht *„Disk Archive“ wurde blockiert …*. Auf **Dennoch öffnen** klicken und mit Passwort oder Touch ID bestätigen.
6. **Noch einmal öffnen:** Im letzten Hinweis auf **Öffnen** klicken. Ab jetzt startet die App normal.

> Seit macOS 15 reicht der frühere Weg „Rechtsklick → Öffnen“ nicht mehr; die Freigabe geht nur über die Systemeinstellungen.

7. **Rückfragen von macOS erlauben:**
   - **Zugriff auf Wechseldatenträger:** Erlauben. Ohne diesen Zugriff kann Disk Archive deine Speichermedien nicht lesen.
   - **Mitteilungen:** nach Wunsch. Disk Archive meldet damit z. B., wenn ein großes Medium fertig indiziert ist.
   - **Anmeldeobjekt hinzugefügt:** Disk Archive startet beim Anmelden, damit angeschlossene Medien sofort erkannt werden. Abschalten kannst du das in Disk Archive unter **Einstellungen → Erweitert → Beim Anmelden starten**.

## Loslegen

Steck ein Speichermedium an (USB-Stick, SD-Karte, externe SSD oder Festplatte). Disk Archive fragt, ob es indiziert werden soll. Danach findest du seine Dateien auch dann, wenn es nicht angeschlossen ist.

## Neue Version installieren

Disk Archive weist dich auf neue Versionen hin (abschaltbar unter **Einstellungen → Erweitert → Auf Updates hinweisen**).

1. Disk Archive beenden (Menüleisten-Symbol → Beenden).
2. Neues DMG öffnen, die App wieder auf „Programme“ ziehen und **Ersetzen** wählen.
3. Öffnen. Weil die neue Version wieder aus dem Internet kommt, ist die Freigabe aus Schritt 4–6 noch einmal nötig.

Index, Favoriten und Einstellungen bleiben erhalten; sie liegen nicht in der App, sondern in `~/Library/Application Support/Disk Archive/`.

## Fehler melden

Beendet sich Disk Archive unerwartet, bietet es beim nächsten Start einen Fehlerbericht an. Er enthält keine Datei- oder Ordnernamen und keine Suchbegriffe.

## Entfernen

Disk Archive beenden, die App aus „Programme“ in den Papierkorb legen. Um auch alle Daten zu löschen: den Ordner `~/Library/Application Support/Disk Archive/` löschen (im Finder: Gehe zu → Gehe zum Ordner …).

---

**Für den Host / Nutzer vor der Veröffentlichung prüfen (nicht auf die Seite):**
- Schritt 4–6 und die Wortlaute der macOS-Hinweise mit dem echten DMG auf einem Mac ohne Vorgeschichte nachstellen (`todo.0.4.1.002`); Wortlaute auf macOS 15 und 27 vergleichen.
- macOS 27: „Beim Anmelden starten“ mit dem heruntergeladenen DMG (Quarantäne-Merkmal, `launchd`) prüfen (`todo.0.4.022`, Backlog). Klappt es nicht, Hinweis ergänzen.
- Ob die Rückfrage „Wechseldatenträger“ auch bei fest verbauten externen SSDs kommt.
- Dateiname des DMG und Link der Download-Seite an `Werkzeuge/dmg-erstellen.sh` und `konzept/datenbank.md` (`/download/`) angleichen.
