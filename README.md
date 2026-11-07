# Musikverein Hart e.V. – Website

[![Build & Deploy nach GitHub Pages](https://github.com/MVHart1947/musikverein-hart.de/actions/workflows/pages.yml/badge.svg)](https://github.com/MVHart1947/musikverein-hart.de/actions/workflows/pages.yml)

Quellcode der offiziellen Website des [Musikverein Hart e.V.](https://www.musikverein-hart.de) – Blasmusikverein aus dem Zollernalbkreis, mit Terminen, Mitgliedern, Vorstandschaft und Impressum.

## Tech-Stack

- [Jekyll](https://jekyllrb.com) 4.3 (Ruby, statischer Seitengenerator)
- [Bootstrap](https://getbootstrap.com) 5.3 als Ruby-Gem eingebunden (siehe [`_plugins/bootstrap_sass_paths.rb`](_plugins/bootstrap_sass_paths.rb)), kein CDN-Aufruf zu Drittanbietern
- [Font Awesome](https://fontawesome.com) 6 als Ruby-Gem eingebunden (siehe [`_plugins/font_awesome_sass_paths.rb`](_plugins/font_awesome_sass_paths.rb)), kein CDN-Aufruf zu Drittanbietern
- Bootstraps JS-Bundle (`assets/js/bootstrap.bundle.min.js`) nur für die Collapse-Funktion des mobilen Navigations-Togglers; [Salvattore](https://github.com/rnmp/salvattore) (`assets/js/salvattore.js`) für das Masonry-Grid auf `mitglieder.html` und `datenschutz.html` – sonst kein eigenes JavaScript

### Farben

| Rolle    | Hex       | Verwendung                     |
|----------|-----------|----------------------------------|
| Primär   | `#0255a3` | Buttons, Links, Akzente          |
| Sekundär | `#eb1c24` | Hervorhebungen                   |
| Tertiär  | `#919396` | Trennlinien, dezente Flächen     |

Definiert in `_sass/vars.scss` – dort auch die Bootstrap-Farb-Map (`$primary`/`$secondary`/`$tertiary`), damit z.&nbsp;B. `btn-primary` automatisch in der Vereinsfarbe erscheint.

## Lokale Entwicklung

Voraussetzung: Ruby >= 3.1 und Bundler.

```bash
bundle install             # Gems installieren
bundle exec jekyll serve   # Dev-Server mit Live-Rebuild unter http://127.0.0.1:4000
bundle exec jekyll build   # Statische Seite nach _site/ bauen
bundle exec rake           # Testsuite
```

Die Tests in `test/` (minitest) prüfen das Konzertmeister-Skript, die Daten in `_data/` und die gebaute Seite:
Links, Bilder und Skripte über [html-proofer](https://github.com/gjtorikian/html-proofer), die Termin-Karte mit
Beispielterminen aus `test/fixtures/`, den Flyer-Zeitraum und die Seiten, die aus den Daten entstehen. Sie bauen
die Seite in einen temporären Ordner und brauchen weder Netz noch API-Schlüssel. Der Workflow
[`test.yml`](.forgejo/workflows/test.yml) führt sie bei jedem Pull Request und jedem Push auf `develop` aus.
Einen Linter für JS/CSS gibt es nicht.

## Struktur

- `index.html`, `historie.html`, `jugend.html`, `mitglieder.html`, `vorstandschaft.html`, `partnerkapelle.html`, `kontakt.html`, `downloads.html`, `impressum.html`, `datenschutz.html` – die Seiten der Website
- `_layouts/`, `_includes/` – gemeinsames Seitengerüst (Navigation, Footer, Register-/Termine-Karten)
- `_data/` – listenartiger Inhalt (Mitglieder, Register, Vorstandschaft, Termine, Flyer, Navigation, Rechtliches), wird per `{% for %}`-Schleife eingebunden
- `_sass/`, `assets/css/main.scss` – Styling (Bootstrap + eigene Anpassungen)
- `_config.yml` – Site-Einstellungen inkl. Vereinskontakt (`contact.*`)
- `script/fetch_termine.rb` – holt die Konzerttermine von der Konzertmeister-API (siehe unten)
- `test/`, `Rakefile` – Testsuite (`bundle exec rake`)

Mehr Architektur-Details (inkl. einiger nicht offensichtlicher Stolperfallen) stehen in [CLAUDE.md](CLAUDE.md).

## Konzertmeister-API (Termine)

Die "Anstehende Termine"-Karte auf der Startseite (`_includes/termine.html`) wird nicht manuell gepflegt, sondern bei jedem Build von [Konzertmeister](https://konzertmeister.app) über `script/fetch_termine.rb` in `_data/termine.yml` geschrieben. Übernommen werden nur kommende Termine vom Typ *Performance*, mit Status *aktiv*, die für die öffentliche Website freigegeben wurden (`publicsite: true` in Konzertmeister).

**API-Key erstellen:** In der [Konzertmeister-Web-App](https://web.konzertmeister.app) unter den Organisationseinstellungen einen API-Key für die M2M-Schnittstelle anlegen.

**API-Key sicher hinterlegen:** Ein Konzertmeister-API-Key darf **niemals** im Repository landen (GitHub Pages ist immer öffentlich erreichbar, egal ob das Repo privat oder öffentlich ist). Stattdessen als **verschlüsseltes Repository-Secret** hinterlegen:

Settings → Secrets and variables → Actions → *New repository secret* → Name `KONZERTMEISTER_API_KEY`, Wert der API-Key.

Der Workflow ([`.github/workflows/pages.yml`](.github/workflows/pages.yml)) reicht das Secret nur während des Build-Jobs als Umgebungsvariable an das Fetch-Script durch – der Key landet nie im ausgelieferten `_site`-Verzeichnis und ist für Website-Besucher:innen nicht einsehbar.

**Lokal mit echten Daten arbeiten** (optional): entweder den Key nur für den einen Aufruf als Umgebungsvariable setzen, nicht dauerhaft exportieren:

```bash
KONZERTMEISTER_API_KEY="dein-key" bundle exec ruby script/fetch_termine.rb
```

...oder dauerhaft in einer lokalen `.env.local`-Datei hinterlegen (wird von `script/fetch_termine.rb` automatisch geladen, ist per `.gitignore` von Commits ausgeschlossen und landet nie im Repo). Secrets gehören nur in `.env.local`, nie in `.env`:

```bash
cp .env.example .env.local
# .env.local öffnen und KONZERTMEISTER_API_KEY=... eintragen
bundle exec ruby script/fetch_termine.rb
```

`_data/termine.yml` selbst ist ebenfalls gitignored – lokal mit echten Terminen zum Design-Testen befüllen ist also gefahrlos, die Datei landet nie in einem Commit. Ohne gesetzten Key (weder als Umgebungsvariable noch via `.env.local`) bleibt eine bereits lokal vorhandene `_data/termine.yml` unverändert bzw. fehlt auf einem frischen Checkout ganz – lokales Entwickeln funktioniert in beiden Fällen, die Karte zeigt dann einfach "keine Termine geplant".

## Flyer-Werbung (Startseite)

Für Aktionen wie die Bachhockete kann auf der Startseite (`index.html`, über `_includes/flyer.html`) automatisch ein Flyer-Bild eingeblendet werden – gesteuert allein über `_data/flyer.yml`, ohne Code-Änderung:

```yaml
aktiv: true
bild: "/assets/media/flyer/bh-2026-programm.jpg"
alt: "Flyer Bachhockete 2026"
breite: 1610
hoehe: 2268
start: 2026-08-01
ende: 2026-08-31
```

| Feld     | Bedeutung                                                        |
|----------|-------------------------------------------------------------------|
| `aktiv`  | `false` blendet den Flyer unabhängig vom Zeitraum komplett aus    |
| `bild`   | Pfad zum Bild unter `assets/media/flyer/`                         |
| `alt`    | Alt-Text für Barrierefreiheit                                     |
| `breite`/`hoehe` | Bild-Maße in Pixel (für CLS-freies Lazy-Loading)           |
| `start`/`ende`   | Zeitraum im Format `YYYY-MM-DD` (ISO 8601, ohne Uhrzeit)    |

Der Flyer wird nur angezeigt, wenn `aktiv: true` ist und die aktuelle Build-Zeit zwischen `start` und `ende` liegt (jeweils inklusive, Tagesgenauigkeit). Da die Seite täglich automatisch neu baut (siehe unten), erscheint und verschwindet der Flyer von selbst – ein manueller Deploy an den Stichtagen ist nicht nötig.

**Für eine neue Aktion:** neues Bild unter `assets/media/flyer/` hochladen, `bild`/`breite`/`hoehe`/`start`/`ende` in `_data/flyer.yml` anpassen, committen.

## Deployment

Die Website liegt auf [GitHub Pages](https://pages.github.com) unter der eigenen Domain `https://www.musikverein-hart.de` (als Custom Domain in den Repository-Settings hinterlegt).

Workflow: Alle Änderungen laufen über den `develop`-Branch. Sobald `develop` nach `main` gemerged/gepusht wird, laufen automatisch zwei GitHub-Actions-Workflows:

- [`.github/workflows/pages.yml`](.github/workflows/pages.yml) baut die Seite (`bundle exec jekyll build`) und deployed sie auf GitHub Pages. Er läuft zusätzlich täglich per `schedule`, damit neue/geänderte Konzertmeister-Termine auch ohne Code-Änderung erscheinen.
- [`.github/workflows/release.yml`](.github/workflows/release.yml) erstellt automatisch ein neues [Release](https://github.com/MVHart1947/musikverein-hart.de/releases) nach dem Schema `YYYY.MM.VERSION` (z.&nbsp;B. `2026.08.1`), mit Release-Notes aus dem Commit-Log seit dem letzten Tag.

**Einmalig im Repository eingerichtet:** Settings → Pages → *Build and deployment* → Source auf „GitHub Actions" gestellt.
