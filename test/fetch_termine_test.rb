# frozen_string_literal: true

# Tests for script/fetch_termine.rb: conversion of Konzertmeister appointments into the
# entries of _data/termine.yml, paging through the API and the start without a key.

require "open3"
require "test_helper"

class FetchTermineTest < Minitest::Test
  # Response of the fake API: one page per call, an empty page ends the paging.
  FakeHttp = Struct.new(:pages, :requests) do
    def request(request)
      requests << request
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@body, JSON.generate(pages.shift || []))
      response.instance_variable_set(:@read, true)
      response
    end
  end

  def test_summer_appointment_is_shown_in_berlin_time
    termin = to_termin(appointments[0])

    assert_equal "Sommerfest", termin["titel"]
    assert_equal ["Sa", "Samstag", 18, "Jul", "Juli", 2026],
                 termin.values_at("wochentag_kurz", "wochentag_lang", "tag", "monat_kurz", "monat_lang", "jahr")
    assert_equal %w[17:30 23:00], termin.values_at("uhrzeit_start", "uhrzeit_ende")
    assert_equal false, termin["zeit_unbekannt"]
    assert_equal "Mit Bewirtung\nab 17 Uhr", termin["beschreibung"]
  end

  def test_winter_appointment_without_end_and_time
    termin = to_termin(appointments[2])

    assert_equal ["Sa", 5, "Dez", "Dezember"], termin.values_at("wochentag_kurz", "tag", "monat_kurz", "monat_lang")
    assert_equal "19:00", termin["uhrzeit_start"]
    assert_nil termin["uhrzeit_ende"]
    assert_equal true, termin["zeit_unbekannt"]
    assert_equal "", termin["beschreibung"]
  end

  def test_date_follows_the_local_day_after_midnight
    termin = to_termin(appointments[0].merge("start" => "2026-03-31T22:30:00Z", "end" => nil))

    assert_equal ["Mi", 1, "Apr"], termin.values_at("wochentag_kurz", "tag", "monat_kurz")
    assert_equal "00:30", termin["uhrzeit_start"]
  end

  def test_only_the_town_of_an_address_is_shown
    assert_equal "Haigerloch", to_termin(appointments[0])["ort"]
    assert_equal "Haigerloch-Hart", nur_ort("Festplatz, 72401 Haigerloch-Hart, Baden-Württemberg")
    assert_equal "Kirche St. Georg", to_termin(appointments[2])["ort"]
    assert_equal "", to_termin(appointments[2].merge("location" => nil))["ort"]
  end

  def test_maps_link_needs_coordinates
    assert_equal "https://www.google.com/maps/search/?api=1&query=48.36,8.81", to_termin(appointments[0])["ort_maps_url"]
    assert_equal "", to_termin(appointments[2])["ort_maps_url"]
  end

  def test_only_appointments_released_for_the_website_are_kept
    assert_equal %w[Sommerfest Adventskonzert], public_termine(appointments).map { |t| t["titel"] }
  end

  def test_pages_are_fetched_until_an_empty_one
    http = FakeHttp.new([appointments[0..1], [appointments[2]]], [])
    result = Net::HTTP.stub(:start, ->(*_args, **_options, &block) { block.call(http) }) do
      fetch_all_appointments("test-key")
    end

    assert_equal 3, result.length
    assert_equal [0, 1, 2], http.requests.map { |r| JSON.parse(r.body)["page"] }
    assert_equal ["test-key"], http.requests.map { |r| r["X-KM-ORG-API-KEY"] }.uniq
    assert_equal({ "typeIds" => [TYPE_PERFORMANCE], "dateMode" => "UPCOMING" },
                 JSON.parse(http.requests[0].body).slice("typeIds", "dateMode"))
  end

  def test_an_api_error_stops_the_script
    error = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
    error.instance_variable_set(:@body, "invalid key")
    error.instance_variable_set(:@read, true)

    _out, err = capture_io do
      exit_error = assert_raises(SystemExit) do
        Net::HTTP.stub(:start, ->(*_args, **_options) { error }) { fetch_all_appointments("wrong-key") }
      end
      assert_equal 1, exit_error.status
    end
    assert_includes err, "antwortete mit 403: invalid key"
  end

  def test_without_key_the_script_ends_and_keeps_the_file
    output = File.join(ROOT, "_data", "termine.yml")
    before = File.exist?(output) && File.mtime(output)

    _out, err, status = Dir.mktmpdir do |empty_dir|
      # Run outside the repository, so dotenv finds no local .env with a real key
      Open3.capture3({ "KONZERTMEISTER_API_KEY" => "" }, RbConfig.ruby, File.join(ROOT, "script", "fetch_termine.rb"),
                     chdir: empty_dir)
    end

    assert status.success?
    assert_includes err, "KONZERTMEISTER_API_KEY ist nicht gesetzt"
    assert_equal before, File.exist?(output) && File.mtime(output)
  end
end
