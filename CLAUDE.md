# CLAUDE.md

Allgemeine Regeln (Git Flow, Merge-Art, Sprache, Commits, PRs, Issues, Inline-Doku, Docker-Images)
stehen im Repo `konventionen` und werden hier nicht wiederholt. Diese Datei beschreibt nur dieses Repo.

## Überblick

Statische Website des Musikvereins Hart e.V. auf Basis von Jekyll, gehostet auf GitHub Pages unter musikverein-hart.de. Jekyll 4.3, Bootstrap 5.3 (als Sass-Gem, nicht über npm) und Vanilla-JS. Kein JS-Build-Schritt und kein `node_modules`, ein reines Ruby/Jekyll-Projekt.

## Befehle

```bash
bundle install                                   # Gems installieren (Ersteinrichtung)
bundle exec jekyll serve                         # lokaler Server unter http://127.0.0.1:4000
bundle exec jekyll serve --livereload            # dasselbe mit Live-Reload, nicht bei Änderungen an _config.yml
bundle exec jekyll build                         # Build nach ./_site
JEKYLL_ENV=production bundle exec jekyll build   # Build wie in der CI
bundle exec rake                                 # Testsuite (minitest, test/)
```

Keine Linter für JS/CSS, kein `package.json`. Die Tests laden `script/fetch_termine.rb` per `require_relative` (der
Hauptteil läuft nur beim direkten Aufruf) und bauen die Seite über `SiteBuild.build` in `test/test_helper.rb` mit
der Jekyll-API in temporäre Ordner. Dabei lassen sich Daten (`termine`, `flyer`) und `site.time` ersetzen, so
hängen die Tests weder von der Konzertmeister-API noch vom aktuellen Inhalt von `_data/termine.yml` ab. Bekannte
Fehler stehen als `skip` mit Issue-Nummer in den Tests und werden mit der Behebung wieder aktiviert. Neue Daten-
dateien, Includes oder Felder brauchen einen Test in `test/data_test.rb` oder `test/site_test.rb`.

### Termine aus Konzertmeister lokal holen

`_data/termine.yml` erzeugt die CI vor jedem Build neu (siehe unten). Die Datei steht in der `.gitignore` und wird nie committet, echte Daten lassen sich lokal also gefahrlos für Designarbeit holen:

```bash
KONZERTMEISTER_API_KEY="dein-key" bundle exec ruby script/fetch_termine.rb
```

Ohne Schlüssel endet das Skript mit Code 0 und lässt `_data/termine.yml` unverändert (oder fehlend bei einem frischen Klon). Lokale Builds funktionieren trotzdem, das Include zeigt dann „keine Termine“.

## Architektur

### Inhalte aus Daten (einzige Quelle)

Die meisten Listenseiten sind Liquid-Vorlagen, die über YAML in `_data/` laufen, kein handgeschriebenes HTML. Mitglieder, Funktionen oder Register werden im YAML geändert, nie in der gerenderten Seite.

- **`_data/mitglieder.yml`**: einzige Quelle für alle Vereinsmitglieder mit Name, `register` (Instrumentengruppe) und optional `rollen` (Liste von Rollen-IDs). Die Reihenfolge im Array ist die Anzeigereihenfolge innerhalb jeder Gruppe.
- **`_data/register.yml`**: Metadaten pro Register (Anzeigename, Foto, Maße), genutzt von `mitglieder.html` über `_includes/register-card.html`.
- **`_data/vorstandschaft.yml`**: Metadaten pro Vorstandsamt (Bezeichnung, Trenner, optionale E-Mail). Wer ein Amt innehat, steht im Feld `rollen` in `mitglieder.yml`, nicht hier. Genutzt von `vorstandschaft.html`, `kontakt.html`, `impressum.html` und `jugend.html`, ein neues Amt muss auf allen vier Seiten passen.
- **`_data/termine.yml`**: kommende Termine, maschinell erzeugt (siehe unten) und nie committet. Nie von Hand bearbeiten, sie wird beim nächsten Build überschrieben und fehlt bei einem frischen Klon eventuell ganz.
- **`_data/navigation.yml`**, **`_data/rechtliches.yml`**, **`_data/datenschutz.yml`**, **`_data/impressum.yml`**: Navigation und Rechtstexte, jeder Eintrag mit `titel`, `icon` und `inhalt`, gerendert über `_includes/legal-section.html` in ein Masonry-Raster (`datenschutz.html` und untere Hälfte von `impressum.html`). Die beiden oberen Karten in `impressum.html` (Anschrift, Vertretungsberechtigte) stehen außerhalb des Rasters, weil sie `site.contact` und `_data/mitglieder.yml` live auslesen.
- **`_data/flyer.yml`**: steuert die Flyer-Karte auf der Startseite (`_includes/flyer.html`, immer von `index.html` eingebunden). Sie erscheint nur bei `aktiv: true` und wenn die Build-Zeit (`site.time`) zwischen `start` und `ende` liegt. Durch den täglichen Build erscheint und verschwindet sie ohne Code-Änderung. Für eine neue Aktion das Bild unter `assets/media/flyer/` ablegen und hier `bild`, `breite`, `hoehe`, `start` und `ende` anpassen, nie `index.html` oder `flyer.html`.

### Anbindung an Konzertmeister

Die Karte „Anstehende Termine“ ist kein iframe. `script/fetch_termine.rb` ruft vor dem Build die REST-API von Konzertmeister ab und schreibt nach `_data/termine.yml`, `_includes/termine.html` rendert das. Übernommen werden nur kommende, aktive Termine vom Typ `Performance`, die in Konzertmeister ausdrücklich mit `publicsite: true` markiert sind. Das Skript berechnet deutsche Wochentags- und Monatsnamen und die Ortszeit Europe/Berlin schon serverseitig (über `tzinfo`), weil der `date`-Filter von Liquid in der CI nicht verlässlich deutsch und sommerzeitrichtig formatiert.

Der API-Schlüssel (`KONZERTMEISTER_API_KEY`) kommt nur aus der Umgebung bzw. dem Secret der CI und wird nie committet.

### Layout und Includes

Ein einziges Layout (`_layouts/default.html`) umschließt jede Seite: `head.html` → `navigation.html` → Seiteninhalt → `footer.html`. Seiten setzen `header` und `title` im Front Matter. Gemeinsame Bausteine liegen in `_includes/` (z. B. `verein.html`, `legal-section.html`, `social.html`, `flyer.html`).

### Sass

Bootstrap und Font Awesome kommen als Ruby-Gems. `_sass/` importiert deren Sass-Quellen über `sass.load_paths`, registriert in `_plugins/bootstrap_sass_paths.rb` und `_plugins/font_awesome_sass_paths.rb`. Es gibt kein `node_modules`, kein CDN und keine eingecheckten Icon-Dateien. Das Font-Awesome-Plugin kopiert nach jedem Build die Schriftdateien des Gems nach `_site/assets/fonts/` (Hook `post_write`), weil Jekyll nur ausliefert, was in der Ausgabe liegt. Eigene Anpassungen stehen in `_sass/vars.scss` (Variablen für Bootstrap und Font Awesome, müssen vor dem jeweiligen `@import` geladen werden) und `_sass/base.scss`. Icons: `<i class="fa-solid fa-...">` bzw. `fa-brands fa-...` (Syntax von v6, z. B. im Feld `icon:` von `_data/navigation.yml` oder in `_includes/social.html`).

`exclude:` in `_config.yml` hält `Gemfile`, `script/`, `README.md`, `Rakefile` und `test/` aus der gebauten Seite heraus. `test/site_test.rb` prüft das.

## CI und Release

- **`.forgejo/workflows/test.yml`**: bei jedem Pull Request und jedem Push auf `develop` die Testsuite (`bundle exec rake`) in `ruby:3.4.7-bookworm`.
- **`.github/workflows/pages.yml`**: bei Push auf `main`, täglich um 05:00 UTC (für neue Termine ohne Code-Änderung) und von Hand. Holt die Termine, baut mit Jekyll und veröffentlicht auf GitHub Pages.
- **`.forgejo/workflows/release.yml`**: bei jedem Push auf `main` (außer Commits mit `[skip ci]`) Tag und Forgejo-Release im Schema `YYYY.MM.N`. Die Release-Notes entstehen aus dem Commit-Log seit dem letzten Tag.
- **`.forgejo/workflows/heartbeat.yml`**: monatlicher Commit nach `main`, siehe Abweichungen.

Forgejo spiegelt das Repo per Push-Mirror nach GitHub, dort laufen nur noch die Pages-Workflows.

## Abweichungen von den Konventionen

- Der Workflow `heartbeat` committet am 1. jedes Monats direkt nach `main` (Commit mit `[skip ci]`, löst kein Release aus). Sonst schaltet GitHub die geplanten Pages-Deploys nach 60 Tagen ohne Aktivität ab. `main` läuft dadurch vor `develop`. Das ist unkritisch, weil `develop` die Datei `.heartbeat` nie ändert, ein Merge von `develop` nach `main` bleibt also konfliktfrei.
