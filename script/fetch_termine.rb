#!/usr/bin/env ruby
# frozen_string_literal: true

# Holt die kommenden Konzerttermine über die Konzertmeister-API und schreibt
# sie nach _data/termine.yml. Wird vor "jekyll build" ausgeführt (siehe
# .github/workflows/pages.yml bzw. README).
#
# Der API-Key wird ausschließlich über die Umgebungsvariable
# KONZERTMEISTER_API_KEY gelesen und landet nie im Repository. In GitHub
# Actions kommt er aus einem verschlüsselten Repository-Secret; lokal kann
# er beim Aufruf gesetzt werden. Ist keine Umgebungsvariable gesetzt, bricht
# das Script NICHT ab, sondern behält die zuletzt im Repo vorhandene
# _data/termine.yml bei (praktisch für lokale Entwicklung ohne Key).

require "net/http"
require "uri"
require "json"
require "yaml"
require "time"
require "tzinfo"

# Lädt KONZERTMEISTER_API_KEY lokal aus einer .env-Datei (falls vorhanden).
# Überschreibt keine bereits gesetzte Umgebungsvariable, ist also in CI
# (Key kommt dort aus einem GitHub-Secret) folgenlos.
begin
  require "dotenv/load"
rescue LoadError
  nil
end

API_URL = "https://rest.konzertmeister.app/api/v4/org/m2m/appointments"
TYPE_PERFORMANCE = 2
OUTPUT_PATH = File.join(__dir__, "..", "_data", "termine.yml")
DEFAULT_TIMEZONE = "Europe/Berlin"

FILTERS = {
  typeIds: [TYPE_PERFORMANCE],
  activationStatusList: ["ACTIVE"],
  publishedStatus: "PUBLISHED",
  sortMode: "STARTDATE",
  dateMode: "UPCOMING",
}.freeze

# Liquids "date"-Filter nutzt für %A/%B/%H die System-Locale bzw. UTC, was
# auf den meisten Servern/CI-Runnern zu falschen (englischen bzw. nicht an
# die Sommerzeit angepassten) Werten führt. Deshalb rechnen wir hier per
# tzinfo einmalig UTC → Europe/Berlin um und formatieren Wochentag/Monat
# selbst auf Deutsch – die Templates zeigen die fertigen Strings nur an.
WOCHENTAGE_KURZ = %w[So Mo Di Mi Do Fr Sa].freeze
WOCHENTAGE_LANG = %w[Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag].freeze
MONATE_KURZ = %w[Jan Feb Mär Apr Mai Jun Jul Aug Sep Okt Nov Dez].freeze
MONATE_LANG = %w[
  Januar Februar März April Mai Juni Juli August September Oktober November Dezember
].freeze

def fetch_page(api_key, page)
  uri = URI(API_URL)
  request = Net::HTTP::Post.new(uri)
  request["X-KM-ORG-API-KEY"] = api_key
  request["Content-Type"] = "application/json"
  request.body = FILTERS.merge(page: page).to_json

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

  unless response.is_a?(Net::HTTPSuccess)
    warn "Konzertmeister-API antwortete mit #{response.code}: #{response.body}"
    exit 1
  end

  JSON.parse(response.body)
end

def fetch_all_appointments(api_key)
  appointments = []
  page = 0

  loop do
    batch = fetch_page(api_key, page)
    break if batch.empty?

    appointments.concat(batch)
    page += 1
  end

  appointments
end

def local_time(iso_string, timezone_id)
  timezone = TZInfo::Timezone.get(timezone_id)
  timezone.utc_to_local(Time.iso8601(iso_string).utc)
end

# Konzertmeisters "formattedAddress" enthält je nach Eingabe-Präzision mal die
# Straße, mal einen Ortsteil, mal das Bundesland (uneinheitlich formatiert).
# Für die Website reicht der Ort – die genaue Adresse sehen die Musiker:innen
# ohnehin über die Konzertmeister-App.
PLZ_ORT_PATTERN = /\d{5}\s+(?<ort>[^,]+)/

def nur_ort(formatted_address)
  match = PLZ_ORT_PATTERN.match(formatted_address)
  match ? match[:ort].strip : formatted_address
end

def maps_url(location)
  lat = location["latitude"]
  lng = location["longitude"]
  return "" unless lat && lng

  "https://www.google.com/maps/search/?api=1&query=#{lat},#{lng}"
end

def to_termin(appointment)
  location = appointment["location"] || {}
  adresse = location["formattedAddress"] || location["name"] || ""
  ort = nur_ort(adresse)
  timezone_id = appointment["timezoneId"] || DEFAULT_TIMEZONE

  start_local = local_time(appointment["start"], timezone_id)
  end_local = appointment["end"] ? local_time(appointment["end"], timezone_id) : nil

  {
    "titel" => appointment["name"],
    "beschreibung" => appointment["description"] || "",
    "ort" => ort,
    "ort_maps_url" => maps_url(location),
    "start" => appointment["start"],
    "wochentag_kurz" => WOCHENTAGE_KURZ[start_local.wday],
    "wochentag_lang" => WOCHENTAGE_LANG[start_local.wday],
    "tag" => start_local.day,
    "monat_kurz" => MONATE_KURZ[start_local.mon - 1],
    "monat_lang" => MONATE_LANG[start_local.mon - 1],
    "jahr" => start_local.year,
    "zeit_unbekannt" => appointment["timeUndefined"] || false,
    "uhrzeit_start" => start_local.strftime("%H:%M"),
    "uhrzeit_ende" => end_local&.strftime("%H:%M"),
  }
end

def public_termine(appointments)
  # Nur Termine, die der Verein explizit für die öffentliche Website freigegeben hat.
  appointments.select { |a| a["publicsite"] }.map { |a| to_termin(a) }
end

# Läuft nur beim direkten Aufruf. Die Tests (test/fetch_termine_test.rb) laden die
# Datei, um die Funktionen oben einzeln zu prüfen.
if File.expand_path($PROGRAM_NAME) == File.expand_path(__FILE__)
  api_key = ENV["KONZERTMEISTER_API_KEY"]

  if api_key.nil? || api_key.empty?
    warn "KONZERTMEISTER_API_KEY ist nicht gesetzt – _data/termine.yml bleibt unverändert."
    exit 0
  end

  termine = public_termine(fetch_all_appointments(api_key)).sort_by { |t| t["start"] }

  File.write(OUTPUT_PATH, termine.to_yaml)
  puts "#{termine.length} kommende(r) Termin(e) von der Konzertmeister-API geschrieben."
end
