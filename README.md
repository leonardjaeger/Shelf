# Shelf

(Früher „Dropper“ – intern heißen Projekt, Ordner, Bundle-ID und Datenordner weiter so, damit Einstellungen, Shelves und Freigaben erhalten bleiben.)

Menüleisten-App für den Mac nach Vorbild von Dropover: Zeiger beim Ziehen schütteln → ein schwebendes Shelf erscheint.
Stand: **Version 1.3** – neuer Name „Shelf“, neues App-Symbol und Regal-Symbol in der Menüleiste; davor Phase 13 (Shelf-Leiste am unteren Rand). Phase 0–7, 9 und 11 abgenommen am 27./28.09.2026 (Version 1.0), Phase 12 abgenommen am 28.09.2026 (Version 1.1), Phase 13 abgenommen am 28.09.2026 (Version 1.2), Phase 8 (Cloud) übersprungen. Ab macOS 15, Swift 5-Modus, ohne Sandbox.

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

## Erscheinungsbild (Phase 11)

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

## Suche, Filter und Vorlagen (Phase 12)

**Suche und Filter:** In der aufgeklappten Ansicht steht oben ein Suchfeld (⌘ F). Mehrere Wörter müssen alle vorkommen; Groß-/Kleinschreibung und Akzente sind egal, bei Links zählt auch die Adresse. Daneben: Filter nach Art und Sortierung (Name, Datum – neueste zuerst, Größe – größte zuerst, Art). Solange gesucht oder gefiltert wird, wirken Herausziehen, Teilen-Knopf, Aktionen und ⌘ K nur auf die gefundenen Einträge (bzw. die Auswahl darin). Umsortieren per Ziehen geht nur ohne Suche/Filter und bei eigener Reihenfolge. Zuklappen leert Suche und Filter; die Sortierung bleibt.

**Vorlagen:** Eine Vorlage merkt sich Name, Farbe, Anheften und Platz (gespeicherter Platz oder linker/rechter Rand) und bekommt ein eigenes Tastenkürzel.

| Was | So geht's |
|---|---|
| Vorlage aus einem Shelf | „…“ › Als Vorlage sichern … – übernimmt Name (sonst wird gefragt), Farbe, Anheften und Platz |
| Vorlage aktualisieren | im Shelf der Vorlage „…“ › Vorlage „Name“ aktualisieren |
| Kürzel, Name, Farbe, Platz ändern | Einstellungen › Vorlagen (auch „+“ für eine neue, „–“ zum Löschen, „Jetzt öffnen“) |
| Öffnen | Kürzel der Vorlage oder Menüleiste › Vorlagen – ist ihr Shelf schon offen (oder ausgeblendet), kommt es nach vorn statt eines zweiten |

## Shelf-Leiste (Phase 13)

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

## Abnahme Phase 0 – Fundament

- [x] App startet ohne Dock-Symbol, das Symbol erscheint in der Menüleiste
- [x] Einstellungsfenster öffnet sich, „Shelf beenden“ beendet die App
- [x] Einstellungen › Diagnose: Beim Ziehen einer Datei in Finder, Safari und Fotos steigt „Drags“, beim Schütteln steigt „Schütteln“
- [x] Bloßes Markieren mit gedrückter Maus (z. B. Text markieren, Fenster verschieben) erhöht „Drags“ nicht

## Abnahme Phase 1 – Shelf-Fenster

- [x] ⌥ ⇧ D öffnet ein Shelf am Zeiger, auch über einer Vollbild-App
- [x] Drei Shelves sind gleichzeitig offen, jedes einzeln verschieb- und schließbar
- [x] Die gerade benutzte App behält den Fokus, wenn ein Shelf erscheint (z. B. in TextEdit weitertippen)

## Abnahme Phase 2 – Ablegen

- [x] 3 Fotos aus dem Finder ablegen ergibt einen Stapel mit Badge „3“ und „3 Bilder ⌄“
- [x] Ein Link aus der Safari-Adressleiste, markierter Text und ein Bild von einer Webseite landen als eigene Einträge (Beschriftung dann „… Objekte“)
- [x] Ein Foto aus der Fotos-App wird als Datei übernommen
- [x] „… ⌄“ klappt das Raster mit Name und Größe auf; ⌘-Klick wählt mehrere aus, oben steht „Ausgewählt: … · Größe“
- [x] Dieselbe Datei ein zweites Mal ablegen fügt sie nicht doppelt hinzu
- [x] Die Originaldateien bleiben unverändert an ihrem Ort

## Abnahme Phase 3 – Herausziehen

- [x] Stapel in einen anderen Ordner ziehen verschiebt alle Dateien, das Shelf schließt sich
- [x] Mit ⌥ werden die Dateien kopiert, die Originale bleiben
- [x] Auf einen USB-Stick wird automatisch kopiert
- [x] Upload in ein Browser-Formular und Anhängen in Mail klappen
- [x] Mit ⇧ bleibt das Shelf nach dem Ablegen offen und unverändert
- [x] Im Raster: einen Eintrag ziehen nimmt nur ihn mit, bei Auswahl alle ausgewählten; Rechtsklick › Aus Shelf entfernen
- [x] Beim Ziehen am Stapel bleibt das Shelf-Fenster stehen (verschieben nur an freier Fläche)
- [x] Eigenes Tastenkürzel einstellen (z. B. ⇧ ⌘ D) öffnet danach ein Shelf; „Standard“ stellt ⌥ ⇧ D wieder her
- [x] Nach einmaligem Festplattenvollzugriff keine Ordner-Rückfragen mehr – auch nicht nach dem nächsten Update
- [x] Link aus dem Shelf in ein Textfeld (Nachrichten, Notizen) ziehen fügt die Adresse ein; in den Browser gezogen öffnet er die Seite
- [x] Geschlossenes Shelf über Menüleiste › Zuletzt geschlossen mit Inhalt wieder öffnen

## Abnahme Phase 4 – Schütteln

- [x] Schütteln beim Ziehen in Finder, Safari und Fotos öffnet sofort ein Shelf unter dem Zeiger – pro Ziehvorgang nur eins
- [x] Normales Ziehen, Fensterverschieben und Markieren lösen nie ein Shelf aus
- [x] Stufe „Niedrig“ braucht spürbar mehr Schütteln als „Hoch“
- [x] Mit eingeschalteter Taste: ziehen, Taste kurz drücken → Shelf erscheint; schon beim Anfassen gedrücktes ⌥ löst nichts aus
- [x] In einer ausgeschlossenen App passiert beim Ziehen nichts
- [x] Shelf per Schütteln öffnen, dann woanders ablegen → das leere Shelf schließt sich von selbst; wird etwas hineingelegt, bleibt es
- [ ] **MVP-Meilenstein:** eine Woche im Alltag benutzt, ohne Absturz und ohne störende Fehlauslösung

## Abnahme Phase 5 – Shelves verwalten

- [x] Ins Shelf klicken, Leertaste → Quick-Look-Vorschau; Leertaste/Esc schließt sie
- [x] Rechtsklick › Umbenennen …: die Datei hat auch im Finder den neuen Namen
- [x] In der aufgeklappten Ansicht einen Eintrag an eine andere Stelle ziehen → Reihenfolge ändert sich, nichts verschwindet
- [x] Rechtsklick › In neues Shelf verschieben → daneben erscheint ein zweites Shelf damit
- [x] Shelf benennen und einfärben: Name oben, farbiger Rand
- [x] Shelf anheften, etwas hineinlegen, Shelf beenden und neu starten → angeheftete Shelves samt Inhalt sind wieder da
- [x] Angeheftetes Shelf mit ✕ ausblenden, über Menüleiste › Angeheftete Shelves wieder einblenden
- [x] Datei eines gespeicherten Shelfs im Finder löschen, Shelf neu starten → Eintrag erscheint grau („Nicht gefunden“)
- [x] Versehentlich geschlossenes Shelf über Menüleiste › Zuletzt geschlossen wiederherstellen – auch nach einem Neustart
- [x] Dateien aufs Menüleisten-Symbol ziehen öffnet ein neues Shelf damit
- [x] Datei im Finder kopieren (⌘ C), ⌥ ⇧ V → neues Shelf mit dieser Datei
- [x] ⌥ + ✕ leert das Shelf, es bleibt offen
- [x] „…“ › Am Rand andocken › rechten Rand: Lasche am Rand; Zeiger drauf klappt auf, weg klappt zu; Datei auf die Lasche ziehen klappt auf und nimmt sie an

## Abnahme Phase 6 – Aktionen

- [x] 4 Fotos per AirDrop aufs iPhone: ins Shelf legen, „…“ › Teilen › AirDrop (oder Fotos über das Shelf ziehen und auf die Kachel „AirDrop“ fallen lassen)
- [x] 3 Bilder im Shelf, „…“ › Bilder › Auf 50 % verkleinern → drei neue, halb so große Dateien („… 50 %“) liegen im Shelf, unten kurz „Fertig: 3 Bilder im Shelf“
- [x] Bildschirmfoto (⇧ ⌘ 4) ins Shelf, „…“ › Umwandeln › Text erkennen und kopieren → Text liegt in der Zwischenablage
- [x] Einstellungen › Aktionen › „+“ › Shell-Skript (Vorlage genügt), dann im Shelf „…“ › Eigene Aktionen → Meldung „… Einträge“ erscheint
- [x] ⌘ K, „cop“ tippen → alle Kopieren-Aktionen (Pfad, Zwischenablage, Link, Kopieren nach, Text erkennen und kopieren – je nach Inhalt)
- [x] „…“ › Öffnen mit, Im Finder zeigen, Pfad kopieren, Kopieren nach …, Bewegen nach …, Als ZIP komprimieren, Als PDF zusammenfassen funktionieren
- [x] Rückmeldungen kommen als kurze Meldung unten im Shelf, nicht als Dialog

## Kurzbefehle und weitere Zugänge (Phase 7)

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

## Abnahme Phase 7 – Kurzbefehle und Zugänge

- [x] Ein Kurzbefehl („Ausgewählte Objekte im Finder abfragen“ › „Zu Shelf hinzufügen“) legt die Finder-Auswahl in ein Shelf
- [x] Kurzbefehle-Aktionen „Neues Shelf“ und „Shelf aus Zwischenablage“ funktionieren
- [x] Ein Terminal-Befehl über das URL-Schema fügt eine Datei hinzu (`open -g "dropper://add?path=…"`)
- [x] `open -g -a Shelf Datei` und Finder › Öffnen mit › Shelf legen die Datei in ein Shelf
- [x] Finder › Rechtsklick › Dienste › „Zu Shelf hinzufügen“ funktioniert
- [x] Teilen-Knopf im Shelf teilt alle Einträge (z. B. per AirDrop)
- [x] Widget „Zuletzt benutzte Shelves“ erscheint unter „Widgets bearbeiten …“, zeigt die Shelves und ein Klick holt das Shelf nach vorn bzw. öffnet es wieder

## Abnahme Phase 9 – Feinschliff

- [x] Einstellungen › Shelf-Verhalten: jede Option wirkt (Einträge behalten, immer kopieren, leeres Shelf schließen, Kacheln, Neustart-Verhalten)
- [x] Einstellungen › Allgemein › Sprache › English › „Jetzt neu starten“: Menüs, Shelf und Einstellungen sind englisch; zurück auf Deutsch geht genauso
- [x] 500 Dateien in ein Shelf legen, aufklappen und scrollen – ohne Ruckeln
- [x] VoiceOver (⌘ F5): Knöpfe und Einträge im Shelf werden vorgelesen
- [x] Alle Meilensteine aus Phase 0–7 laufen als Gesamttest noch einmal durch
- [ ] Nach 8 Stunden Laufzeit wächst der Speicher nicht stetig (Einstellungen › Diagnose zeigt Speicher, Höchstwert und Laufzeit)

## Abnahme Phase 11 – Aussehen, Themes und Verhalten

- [x] Jede Option wirkt sofort und übersteht einen Neustart von Shelf
- [x] Die vier Themes sehen deutlich verschieden aus; Hell/Dunkel gilt unabhängig vom Mac
- [x] Raster und Liste laufen auch mit 500 Dateien ohne Ruckeln
- [x] Mit „Bewegung reduzieren“ gibt es keine Animationen
- [x] Angeheftete Shelves sind allein an ihrer Farbe unterscheidbar
- [x] Position (Zeiger, Ecke, gleicher Platz), Töne und Menüleisten-Symbol mit Zähler funktionieren

## Abnahme Phase 12 – Suche, Filter und Shelf-Vorlagen

- [x] In einem Shelf mit 500 Dateien findet die Suche eine Datei beim Tippen ohne Verzögerung
- [x] Suche, Filter und Sortierung lassen sich kombinieren und mit einem Klick zurücksetzen
- [x] Herausziehen, Teilen und Aktionen erfassen nur die gefundenen Einträge
- [x] Das Kürzel einer Vorlage öffnet das Shelf fertig eingerichtet (Name, Farbe, Platz)
- [x] Ein zweiter Druck holt das vorhandene Shelf nach vorn statt ein neues zu öffnen
- [x] „Als Vorlage sichern“ übernimmt Name, Farbe und Platz eines bestehenden Shelfs

## Abnahme Phase 13 – Shelf-Leiste

- [x] Menüleiste › Angeheftete Shelves und › Zuletzt geschlossen öffnen die Leiste unten statt eines Untermenüs; das Menüleisten-Symbol bleibt
- [x] Jede Karte zeigt Name, Farbe (falls gesetzt) und eine Vorschau des Inhalts
- [x] Klick auf eine Karte holt das angeheftete Shelf nach vorn bzw. öffnet das geschlossene wieder – mit Name und Farbe
- [x] Esc, ✕ oder ein Klick daneben schließt die Leiste; ← → und ↩ funktionieren
- [x] Ausblenden, Aus dem Verlauf entfernen und Verlauf leeren wirken sofort in der Leiste

## Abnahme Version 1.3 – Name „Shelf“ und neue Symbole

- [ ] In „Programme“ liegt „Shelf“ mit dem blau-gelben Regal-Symbol, die alte „Dropper.app“ ist weg
- [ ] Menüleiste › „Shelf beenden“, das Einstellungsfenster heißt „Shelf – Einstellungen“
- [ ] Angeheftete Shelves, Einstellungen und Festplattenvollzugriff sind nach dem Umbenennen noch da
- [ ] Finder › Rechtsklick › Dienste › „Zu Shelf hinzufügen“ und die Kurzbefehle-Aktionen funktionieren
- [ ] Das Regal in der Menüleiste füllt sich mit den angehefteten Shelves (0 / ab 1 / ab 4 / ab 8) und steht bündig neben dem Docker-Symbol

App-Name (Shelf) und App-Symbol stehen. Signiert wird lokal mit „Dropper Signatur (lokal)“; Notarisieren und Updates über Sparkle wären erst nötig, wenn Shelf an andere weitergegeben wird.

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
