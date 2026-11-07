source "https://rubygems.org"

gem "jekyll", "~> 4.3"

# Bootstrap als Sass-Version einbinden (Quelle: node_modules-freie Ruby-Gem)
gem "bootstrap", "~> 5.3"

# Font Awesome als Sass-Version einbinden (Quelle: node_modules-freie Ruby-Gem),
# ersetzt die zuvor manuell vendorten Dateien unter assets/fontawesome/
gem "font-awesome-sass", "~> 6.7"

# Jekyll benötigt für Sass-Kompilierung Dart-Sass
gem "jekyll-sass-converter", "~> 3.0"

# Lokaler Server unter Ruby 3.x
gem "webrick", "~> 1.8"

# Zeitzonen-korrekte Umrechnung der Konzertmeister-Termine (UTC → Europe/Berlin,
# DST-sicher) in script/fetch_termine.rb
gem "tzinfo", "~> 2.0"

# Lädt KONZERTMEISTER_API_KEY lokal aus .env.local (nicht committet), damit er
# beim lokalen Entwickeln nicht bei jedem Aufruf manuell gesetzt werden muss.
# In CI ungenutzt, da dort kein .env.local existiert und das Secret bereits als
# echte Umgebungsvariable vorliegt.
gem "dotenv", "~> 3.1", groups: [:development]

# Testsuite (bundle exec rake, siehe README): minitest für die Tests, rake als
# Aufruf, html-proofer prüft Links, Bilder und Skripte der gebauten Seite.
group :test do
  gem "html-proofer", "~> 5.0"
  gem "minitest", "~> 5.25"
  gem "rake", "~> 13.2"
end

group :jekyll_plugins do
  gem "jekyll-feed"
  gem "jekyll-sitemap"
  gem "jekyll-seo-tag"
end

# Windows/JRuby: tzinfo braucht hier zusätzlich die Zonendaten als Gem,
# da diese Betriebssysteme keine eigene Zoneinfo-Datenbank mitbringen.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo-data"
end

gem "wdm", "~> 0.1", :platforms => [:mingw, :x64_mingw, :mswin]
