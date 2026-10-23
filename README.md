# Shelf

Shelf ist eine Menüleisten-App für macOS nach Vorbild von Dropover: eine schwebende Ablage für alles, was du gerade ziehst. Zeiger beim Ziehen kurz schütteln – schon erscheint ein Shelf. Darauf lassen sich Dateien, Ordner, Links, Text und Bilder zwischenparken, bis sie ihr Ziel haben. Von dort ziehst du sie gesammelt weiter, teilst sie oder bearbeitest sie mit Aktionen, etwa Bilder verkleinern, Text erkennen oder als ZIP packen.

- Shelf öffnen per Schütteln, Tastenkürzel, Menüleiste, Kurzbefehle, Dienste-Menü oder Terminal
- Shelves anheften, benennen, einfärben und am Bildschirmrand andocken
- Suche, Filter, Vorlagen und eine Shelf-Leiste für angeheftete und zuletzt geschlossene Shelves
- Widget „Zuletzt benutzte Shelves“
- Oberfläche auf Deutsch und Englisch

Ab macOS 15, Swift 5, ohne Sandbox.

## Starten

- **Xcode:** `Dropper.xcodeproj` öffnen, Ziel **Dropper › My Mac**, **⌘R** startet, **⌘U** testet.
- **Installieren:** im Ordner `Dropper_Paket` Doppelklick auf **„Shelf installieren.command“** → baut die Release-Fassung, legt sie nach „Programme“ und erstellt im selben Ordner **`Shelf-<Version>.dmg`** (Shelf + Verknüpfung zu „Programme“ zum Hineinziehen) und **`Shelf-<Version>.zip`** (das ganze Paket mit Projekt und Skripten).
- **Tests:** Doppelklick auf **„Shelf testen.command“** – Ergebnis im Fenster und in `Dropper/build/test.log`.
- **Terminal:** `./build.sh --run`

Shelf hat kein Dock-Symbol, nur ein Regal-Symbol in der Menüleiste. Es füllt sich mit den angehefteten Shelves (sichtbar oder ausgeblendet): leer bei keinem, erste Bücher ab 1, mehr ab 4, voll ab 8. Es ist so hoch wie das Docker-Symbol und steht unten auf derselben Linie. Unter Einstellungen › Erscheinungsbild › Menüleiste lässt sich weiter ein anderes Symbol wählen.

## Bedienung

| Aktion | So geht's |
|---|---|
| Neues Shelf am Zeiger | ⌥ ⇧ D (in jeder App) oder Menüleiste › Neues Shelf |
| Shelf aus der Zwischenablage | ⌥ ⇧ V (in jeder App) oder Menüleiste › Neues Shelf aus Zwischenablage – übernimmt kopierte Dateien, Bilder, Text oder Links |
| Dateien aufs Menüleisten-Symbol ziehen | öffnet darunter ein neues Shelf mit dem Gezogenen |
| Tastenkürzel ändern | Einstellungen › Shelf-Aktivierung › Tastenkürzel › aufs Kürzel klicken, neue Kombination drücken (Esc bricht ab, „Standard“ setzt zurück) |
| Shelf beim Ziehen | Datei ziehen und den Zeiger 2–3-mal schnell hin und her schütteln – oder (falls eingeschaltet) beim Ziehen kurz die eingestellte Taste drücken; pro Ziehvorgang höchstens ein Shelf |
| Leeres Shelf | Ein beim Ziehen geöffnetes Shelf, in das nichts gelegt wird, schließt sich nach dem Loslassen von selbst |
| Apps ausschließen | Einstellungen › Shelf-Aktivierung › Ausgeschlossene Apps |
| Shelf verschieben | freie Fläche im Shelf ziehen |
| Shelf schließen | ✕ oben links, „…“ › Shelf schließen, oder ins Shelf klicken und ⌘ W |
| Shelf leeren | ⌥ gedrückt halten und ✕ klicken, oder „…“ › Shelf leeren (das Shelf bleibt offen) |
| Ablegen | Dateien, Ordner, Links, markierten Text oder Bilder aufs Shelf ziehen (blauer Rahmen) |
| Alle Einträge sehen | Knopf „3 Bilder ⌄“ unter dem Stapel |
| Auswählen | Klick, mehrere mit ⌘-Klick |
| Quick Look | ins Shelf klicken, Leertaste (wirkt auf die Auswahl, sonst auf alle); nochmal Leertaste oder Esc schließt |
| Umbenennen | Rechtsklick auf einen Eintrag › Umbenennen … – die Datei heißt dann auch im Finder so |
| Umsortieren | in der aufgeklappten Ansicht einen Eintrag an eine andere Stelle im Raster bzw. in der Liste ziehen |
| In neues Shelf verschieben | Rechtsklick auf Eintrag bzw. Auswahl › In neues Shelf verschieben |
| Name, Farbe | „…“ › Shelf benennen … / Farbe |
| Anheften | „…“ › Anheften – das Shelf bleibt dauerhaft, ✕ blendet es nur aus; wieder einblenden über Menüleiste › Angeheftete Shelves (Shelf-Leiste) |
| Am Rand andocken | „…“ › Am Rand andocken › linken/rechten Rand – das Shelf wird zur schmalen Lasche; Zeiger drauf oder Datei drüberziehen klappt es auf, 0,7 s nach dem Verlassen klappt es wieder zu; „Abdocken“ löst es |
| Alles teilen | Teilen-Knopf oben rechts im Shelf (neben „…“) – AirDrop, Mail, Nachrichten und alles aus dem System-Teilen-Menü |
| Aktionen | „…“ oben rechts (für Auswahl, sonst alle), Rechtsklick auf Eintrag › Aktionen |
| Command Bar | ins Shelf klicken, ⌘ K, tippen (z. B. „cop“, „zip“, „jpeg“), ↑/↓, ↩ führt aus, Esc schließt |
| Instant Actions | Dateien übers Shelf ziehen, unten erscheinen die Kacheln AirDrop, Mail, Nachrichten – auf eine Kachel fallen lassen teilt sofort (landet nicht im Shelf) |
| Eigene Aktionen | Einstellungen › Aktionen › „+“: Shell-Skript, AppleScript oder Kurzbefehl |
| Herausziehen | Stapel ziehen = alle Einträge; im Raster einen Eintrag ziehen = ihn bzw. die ganze Auswahl |
| Kopieren statt verschieben | beim Loslassen ⌥ halten (anderes Laufwerk kopiert automatisch, ⌘ erzwingt Verschieben) |
| Shelf nach dem Herausziehen behalten | beim Loslassen ⇧ halten |
| Öffnen / Im Finder zeigen / Entfernen | Doppelklick bzw. Rechtsklick auf einen Eintrag; „…“ › Alle im Finder zeigen, Shelf leeren |
| Alle schließen | Menüleiste › Alle Shelves schließen |
| Geschlossenes Shelf wieder öffnen | Menüleiste › Zuletzt geschlossen (Shelf-Leiste; die letzten 10, auch nach einem Neustart) |
| Link herausziehen | geht als Link: Browser öffnet ihn, Chat/Mail/Notizen fügen die Adresse ein, der Finder legt eine Link-Datei an; Rechtsklick › Link kopieren |
| Einstellungen | Menüleiste › Einstellungen … (Shelf-Aktivierung, Shelf-Verhalten, Erscheinungsbild, Aktionen, Allgemein, Diagnose) |
| Aussehen ändern | Einstellungen › Erscheinungsbild – mit Live-Vorschau (siehe unten) |
| Im Shelf suchen | ins Shelf klicken, ⌘ F (oder „…“ › Im Shelf suchen …) – filtert beim Tippen; Esc leert die Suche |
| Filtern, sortieren | in der aufgeklappten Ansicht die Knöpfe neben dem Suchfeld: nach Art (Dateien, Ordner, Bilder, Links, Texte) und nach Name, Datum, Größe, Art; ✕ setzt alles zurück |
| Vorlagen | „…“ › Als Vorlage sichern … – Kürzel dafür unter Einstellungen › Vorlagen; öffnen per Kürzel oder Menüleiste › Vorlagen |
| Sprache | Einstellungen › Allgemein › Sprache: Deutsch, English oder wie das System (wirkt nach „Jetzt neu starten“) |

**Dateizugriff:** Ohne weitere Freigabe fragt macOS für jeden geschützten Ordner einzeln (Schreibtisch, Dokumente, Downloads, iCloud Drive, USB-Sticks …). Einmalig **Festplattenvollzugriff** geben, dann entfällt das: Einstellungen › Allgemein › Dateizugriff › „Systemeinstellungen öffnen“ → Shelf einschalten (fehlt es, mit „+“ aus „Programme“ hinzufügen). Der Installer signiert Shelf mit einem festen, lokalen Zertifikat („Dropper Signatur (lokal)“ im Schlüsselbund), damit die Freigabe auch nach Updates bestehen bleibt. Aus Xcode gestartete Test-Versionen zählen als eigene App.

Diagnose: Einstellungen › Diagnose, oder in der App „Konsole“ nach `Dropper` suchen (jede Aktion wird dort protokolliert).

Dateien aus dem Finder bleiben, wo sie sind – das Shelf merkt sich nur den Verweis. Text, Links, Web-Bilder, Fotos und Ergebnisse von Aktionen legt Shelf als Datei in `~/Library/Application Support/Dropper/Items` ab. Sie bleiben liegen, solange ein Shelf oder „Zuletzt geschlossen“ sie braucht; alles andere wird beim nächsten Start aufgeräumt.

**Speichern:** Offene Shelves (mit Inhalt oder angeheftet), Name, Farbe, Lage, Andocken und „Zuletzt geschlossen“ stehen in `~/Library/Application Support/Dropper/Shelves.json` und sind nach einem Neustart wieder da. Dateien werden über Lesezeichen gefunden, auch wenn sie inzwischen umbenannt oder verschoben wurden. Gibt es eine Datei nicht mehr (oder ist der USB-Stick nicht eingesteckt), erscheint der Eintrag grau mit „Nicht gefunden“. Herausgezogene Dateien bleiben bis zum nächsten Start liegen, damit z. B. ein Browser-Upload sie noch findet.

Nach dem Herausziehen verschwinden die gezogenen Einträge aus dem Shelf; ist es leer, schließt es sich.

## Erscheinungsbild

Einstellungen › Erscheinungsbild; die Vorschau oben zeigt jede Änderung sofort, offene Shelves ändern sich mit.

| Option | Auswahl |
|---|---|
| Theme | Standard, Minimal (klein, ohne Rahmen, ein Vorschaubild), Kontrast (deckend, kräftiger Rahmen, eingefärbt), Farbig (Glas, eingefärbt) – setzt Material, Transparenz, Einfärben, Rahmen, Größe und Stapel auf einmal; jede Einzeländerung danach zeigt „Eigenes“ |
| Design | System, Hell, Dunkel – nur für Shelf, unabhängig vom Mac |
| Material, Transparenz | Glas (durchscheinend) oder deckend; Regler 0–70 % |
| Einfärben, Rahmen | Shelf-Farbe färbt das ganze Shelf; Rahmen in der Shelf-Farbe: ohne, normal, kräftig |
| Größe | Kompakt, Normal, Groß – Shelf, Kacheln und Schrift |
| Aufgeklappt | Raster (Vorschaubilder) oder Liste (Name, Datum, Größe) |
| Stapel | Aufgefächert, Gestapelt, Ein Bild (mit Zähler) |
| Neue Shelves erscheinen | am Zeiger, in einer Ecke (wählbar) oder immer am gleichen Platz (dort, wohin zuletzt ein Shelf geschoben wurde) |
| Animation | Aufploppen, Einblenden, Keine – ist in macOS „Bewegung reduzieren“ an, animiert Shelf nie |
| Töne | kurzer Ton beim Ablegen und Herausziehen (aus, bis man ihn einschaltet) |
| Menüleiste | Symbol wählbar, auf Wunsch mit der Zahl der offenen Shelves |

## Suche, Filter und Vorlagen

**Suche und Filter:** In der aufgeklappten Ansicht steht oben ein Suchfeld (⌘ F). Mehrere Wörter müssen alle vorkommen; Groß-/Kleinschreibung und Akzente sind egal, bei Links zählt auch die Adresse. Daneben: Filter nach Art und Sortierung (Name, Datum – neueste zuerst, Größe – größte zuerst, Art). Solange gesucht oder gefiltert wird, wirken Herausziehen, Teilen-Knopf, Aktionen und ⌘ K nur auf die gefundenen Einträge (bzw. die Auswahl darin). Umsortieren per Ziehen geht nur ohne Suche/Filter und bei eigener Reihenfolge. Zuklappen leert Suche und Filter; die Sortierung bleibt.

**Vorlagen:** Eine Vorlage merkt sich Name, Farbe, Anheften und Platz (gespeicherter Platz oder linker/rechter Rand) und bekommt ein eigenes Tastenkürzel.

| Was | So geht's |
|---|---|
| Vorlage aus einem Shelf | „…“ › Als Vorlage sichern … – übernimmt Name (sonst wird gefragt), Farbe, Anheften und Platz |
| Vorlage aktualisieren | im Shelf der Vorlage „…“ › Vorlage „Name“ aktualisieren |
| Kürzel, Name, Farbe, Platz ändern | Einstellungen › Vorlagen (auch „+“ für eine neue, „–“ zum Löschen, „Jetzt öffnen“) |
| Öffnen | Kürzel der Vorlage oder Menüleiste › Vorlagen – ist ihr Shelf schon offen (oder ausgeblendet), kommt es nach vorn statt eines zweiten |

## Shelf-Leiste

Menüleiste › **Angeheftete Shelves** oder › **Zuletzt geschlossen** öffnet unten am Bildschirm eine Leiste mit Karten – wie bei Paste. Solange sie offen ist, ist das Dock ausgeblendet – das macOS-Dock und das eigene Dock von Docker (ab Docker 0.9.3, per Meldung zwischen den Apps); beim Schließen kommt es zurück und die vorher benutzte App ist wieder vorn. Jede Karte zeigt Name, Farbe (als farbigen Kopf), Inhalt („3 Bilder“), Zustand (sichtbar, ausgeblendet oder wann geschlossen) und eine Vorschau der ersten Einträge (bei mehr als vier: drei Bilder und „+N“). Name und Farbe merkt sich jetzt auch „Zuletzt geschlossen“ und gibt sie beim Wiederöffnen zurück.

| Was | So geht's |
|---|---|
| Öffnen | Menüleiste › Angeheftete Shelves bzw. Zuletzt geschlossen; derselbe Menüpunkt nochmal schließt die Leiste |
| Reiter wechseln | oben links „Angeheftet · n“ / „Zuletzt geschlossen · n“, oder Tab |
| Shelf holen | Klick auf die Karte: angeheftetes kommt nach vorn (ausgeblendetes wird eingeblendet), geschlossenes öffnet wieder – die Leiste schließt sich |
| Tastatur | ← → wählen, ↩ öffnen, Esc schließt |
| Rechtsklick auf eine Karte | Nach vorn holen / Ausblenden (angeheftet), Anzeigen (ausgeblendet), Wieder öffnen / Aus dem Verlauf entfernen (geschlossen) |
| Verlauf leeren | Knopf oben rechts im Reiter „Zuletzt geschlossen“ |
| Schließen | Esc, ✕ oben rechts, Klick daneben oder in ein Shelf |

## Kurzbefehle und weitere Zugänge

**App „Kurzbefehle“** – drei Shelf-Aktionen (in Kurzbefehle nach „Shelf“ suchen):

| Aktion | Wirkung |
|---|---|
| Neues Shelf | leeres Shelf in der Bildschirmmitte |
| Shelf aus Zwischenablage | Shelf mit dem kopierten Inhalt |
| Zu Shelf hinzufügen | Dateien in ein neues Shelf (Schalter „In neues Shelf“ aus: ins zuletzt benutzte) |

Beispiel „Finder-Auswahl in ein Shelf“: neuer Kurzbefehl › „Ausgewählte Objekte im Finder abfragen“ › „Zu Shelf hinzufügen“. Den Kurzbefehl kannst du in Kurzbefehle mit einem eigenen Tastenkürzel belegen.

**Dienste-Menü** – Rechtsklick auf Dateien im Finder (oder markierten Text / einen Link in einer App) › Dienste › **Zu Shelf hinzufügen**. Falls der Eintrag fehlt: Systemeinstellungen › Tastatur › Tastaturkurzbefehle › Dienste › einschalten.

**Terminal, Alfred, Raycast** – über „Öffnen mit“ oder das URL-Schema `dropper://`:

```sh
open -g -a Shelf Bericht.pdf Foto.jpg                     # Dateien in ein neues Shelf
open -g "dropper://add?path=$PWD/Bericht.pdf"               # dasselbe per URL
open -g "dropper://add?path=$PWD/Bericht.pdf&target=last"   # ins zuletzt benutzte Shelf
open -g "dropper://add?url=https://example.com"             # Link
open -g "dropper://add?text=Hallo"                          # Text
open -g "dropper://new"                                     # leeres Shelf
open -g "dropper://clipboard"                               # Shelf aus der Zwischenablage
open -g "dropper://show?id=<UUID>"                          # Shelf nach vorn holen / wieder öffnen (nutzt das Widget)
```

Pfade mit Leerzeichen in der URL als `%20` schreiben – oder einfach `open -g -a Shelf "Mein Bericht.pdf"`. Als Befehl für die `~/.zshrc`: `dropper() { open -g -a Shelf "$@"; }`

**Widget „Zuletzt benutzte Shelves“** – Rechtsklick auf den Schreibtisch › „Widgets bearbeiten …“ › Shelf (klein, mittel oder groß). Zeigt die offenen Shelves (zuletzt benutztes zuerst) und „Zuletzt geschlossen“; ein Klick holt ein Shelf nach vorn oder öffnet es wieder, „Neues Shelf“ öffnet ein leeres. Die App schreibt dafür `Widget.json` nach `~/Library/Application Support/Dropper/`; das Widget darf nur diesen Ordner lesen.

## Aktionen

| Gruppe | Aktionen |
|---|---|
| Allgemein | Öffnen, Öffnen mit, Im Finder zeigen, Quick Look, Pfad kopieren, In die Zwischenablage kopieren, Link kopieren, Kopieren nach …, Bewegen nach …, In neues Shelf verschieben, Shelf leeren |
| Teilen | AirDrop, Mail, Nachrichten, Teilen … (Systemmenü) |
| Bilder | auf 50 % / 25 % verkleinern, in JPEG / PNG / HEIC umwandeln, komprimieren (JPEG 70 %), Metadaten entfernen, unter- oder nebeneinander zusammenfügen |
| Umwandeln | Text erkennen (Deutsch/Englisch) und kopieren, Bilder als PDF zusammenfassen, als ZIP komprimieren |
| Eigene | Shell-Skript (zsh, Pfade in `"$@"`), AppleScript (Pfade in `on run argv`), Kurzbefehl (`shortcuts run Name -i Datei …`) |

Neue Dateien aus Aktionen landen in einem eigenen Ordner unter `Items` und direkt im Shelf – die Originale bleiben unverändert. Die erste Ausgabezeile eines eigenen Skripts erscheint als Meldung.

## Aufbau

| Ordner | Inhalt |
|---|---|
| `Dropper/App` | Einstieg, Menüleiste (`AppDelegate`), Einstellungsfenster, Kurzbefehle (`Intents`), URL-Schema/Dienste (`Commands`) |
| `Dropper/Core` | `ShakeDetector`, `DragTrigger` (Taste, ausgeschlossene Apps), `ShelfItem`, `KeyCombo`, `ShelfRecord` (Speichern, Andocken, Umsortieren), `ShelfAction` (Aktionskatalog, Suche, eigene Aktionen), `Appearance` (Themes, Aussehen, Lage neuer Shelves), `ShelfFilter` (Suche, Filter, Sortierung), `ShelfTemplate` (Vorlagen) – reine Logik, getestet; Einstellungs-Schlüssel |
| `Dropper/System` | globaler Maus-Monitor, Tastenkürzel (Carbon), Autostart, Diagnose, `DropReader`, `ItemStorage`, `ShelfStore` (JSON), `ImageTools` (ImageIO), `DocumentTools` (Vision, PDFKit, ditto, Skripte), `Sharing`, `ShelfSound` |
| `Dropper/Shelf` | `ShelfPanel` (NSPanel + Drop-Fläche, Tasten, Quick Look), `DragSource` (Herausziehen), `ShelfModel`, `ShelfView` (Stapel, Raster, Liste, Lasche, Kacheln, Meldungen), `ShelfBackground` (Glas/deckend, Einfärben), `ShelfMenus`, `CommandBar`, `ActionRunner`, `QuickLook`, `Thumbnails`, `ShelfManager` (Öffnen, Lage, Animation, Andocken, Speichern), `ShelfBrowser` (Shelf-Leiste am unteren Rand) |
| `Dropper/Views` | Einstellungen (inkl. eigene Aktionen), Erscheinungsbild mit Live-Vorschau (`AppearanceSettings`), Vorlagen mit Kürzel-Aufnahme (`TemplatesSettings`), Kürzel-Aufnahme (`ShortcutRecorder`) |
| `DropperWidget` | Widget „Zuletzt benutzte Shelves“ (WidgetKit, Sandbox, liest `Widget.json`) |
| `DropperTests` | Tests für Schüttel-Erkennung, Einträge (Einordnung, Beschriftung, Dateinamen, Duplikate), Herausziehen, Tastenkürzel, Links, „Zuletzt geschlossen“, Auslösen beim Ziehen, Umsortieren, Andocken, Speichern, Umbenennen, Aktionssuche, eigene Aktionen, Bildbearbeitung, Suche/Vorlagen und Shelf-Leiste |

Das Xcode-Projekt nutzt synchronisierte Ordner: neue Dateien werden automatisch übernommen. `Support/Dropper-Info.plist` ergänzt die erzeugte Info.plist um URL-Schema, „Öffnen mit“ und Dienste-Menü; `Support/DropperWidget-*` sind Info.plist und Berechtigungen des Widgets. Texte stehen auf Deutsch im Code; die englischen Übersetzungen liegen in `Dropper/Localizable.xcstrings` (das Diagnose-Protokoll bleibt deutsch).

## Lizenz

MIT-Lizenz, siehe [`LICENSE`](LICENSE).
