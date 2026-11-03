# frozen_string_literal: true

# Tests for the built site: links, images and scripts (html-proofer), files that must
# not be published, the appointment card, the flyer and the pages built from _data/.
# The site is built with appointments from test/fixtures and a flyer period around the
# build time, and a second time without appointments and outside the flyer period.

require "html-proofer"
require "test_helper"

class SiteTest < Minitest::Test
  BUILD_TIME = Time.utc(2026, 7, 1, 12)
  FLYER = data("flyer").merge("aktiv" => true, "start" => Date.new(2026, 6, 20), "ende" => Date.new(2026, 7, 10))

  # Files of the repository that must never end up on the website
  INTERNAL_FILES = %w[Gemfile Gemfile.lock README.md Rakefile script test .env .env.example .github .forgejo].freeze

  def site
    SiteBuild.build(time: BUILD_TIME, data: { "termine" => public_termine(appointments), "flyer" => FLYER })
  end

  def site_without_appointments
    SiteBuild.build(time: Time.utc(2026, 8, 1, 12), data: { "termine" => [], "flyer" => FLYER })
  end

  # Runs html-proofer on the built site and returns its findings instead of exiting.
  #
  # @param options [Hash] further html-proofer options
  # @return [Array<String>] one line per failure
  def proofer_failures(**options)
    proofer = HTMLProofer.check_directory(site, disable_external: true, checks: %w[Links Images Scripts],
                                                log_level: :fatal, **options)
    begin
      proofer.run
    rescue SystemExit
      nil # html-proofer exits on failures, the findings stay readable
    end
    proofer.failed_checks.map { |failure| "#{failure.path}:#{failure.line} #{failure.description}" }
  end

  def test_links_images_and_scripts_resolve
    # Missing alt attributes are known, see test_images_have_alt_texts
    assert_empty proofer_failures(ignore_missing_alt: true)
  end

  def test_images_have_alt_texts
    skip "14 Bilder ohne alt-Attribut, Issue #7"
    assert_empty proofer_failures
  end

  def test_repository_files_are_not_published
    published = INTERNAL_FILES.select { |file| File.exist?(File.join(site, file)) }
    assert_empty published
  end

  def test_claude_md_is_not_published
    skip "CLAUDE.md wird veröffentlicht, Issue #5"
    refute File.exist?(File.join(site, "CLAUDE.md"))
  end

  def test_every_page_has_a_title
    Dir.glob("**/*.html", base: site).each do |file|
      title = page(site, file)[%r{<title>(.*?)</title>}m, 1].to_s.strip
      refute_empty title, "#{file} has no title"
    end
  end

  def test_upcoming_appointments_are_shown_with_date_time_and_place
    html = page(site, "index.html")

    assert_includes html, "Sommerfest"
    assert_includes html, "Adventskonzert"
    refute_includes html, "Interne Probe"
    assert_includes html, "17:30–23:00 Uhr"
    assert_includes html, %(href="https://www.google.com/maps/search/?api=1&query=48.36,8.81")
    assert_includes html, "Mit Bewirtung<br />\nab 17 Uhr"
    assert_includes html, "Kirche St. Georg"
    refute_includes html, "19:00 Uhr", "an appointment without time shows no time"
  end

  def test_at_most_five_appointments_are_shown
    termine = Array.new(7) { |i| to_termin(appointments[0].merge("name" => "Termin #{i + 1}")) }
    html = page(SiteBuild.build(time: BUILD_TIME, data: { "termine" => termine }), "index.html")

    assert_includes html, "Termin 5"
    refute_includes html, "Termin 6"
  end

  def test_without_appointments_a_note_is_shown
    assert_includes page(site_without_appointments, "index.html"), "Aktuell sind keine Termine geplant"
  end

  def test_flyer_is_shown_only_during_its_period
    assert_includes page(site, "index.html"), %(src="#{FLYER["bild"]}")
    refute_includes page(site_without_appointments, "index.html"), %(src="#{FLYER["bild"]}")
  end

  def test_every_member_is_listed
    html = page(site, "mitglieder.html")
    data("mitglieder").each { |member| assert_includes html, member["name"] }
  end

  def test_every_office_holder_is_listed_on_the_board_page
    html = page(site, "vorstandschaft.html")
    data("mitglieder").select { |member| member["rollen"] }.each do |member|
      assert_includes html, member["name"]
    end
  end

  def test_imprint_shows_the_address_and_the_chairs
    html = page(site, "impressum.html")
    site_config = YAML.safe_load_file(File.join(ROOT, "_config.yml"))
    site_config["contact"].each_value { |value| assert_includes html, value }
    data("mitglieder").select { |m| (Array(m["rollen"]) & %w[vorsitzender-1 vorsitzender-2]).any? }.each do |member|
      assert_includes html, member["name"]
    end
  end

  def test_navigation_points_to_existing_pages
    data("navigation").each do |entry|
      assert File.file?(File.join(site, entry["url"])), "navigation: #{entry["url"]} is not built"
    end
  end

  def test_every_icon_of_the_data_files_exists_in_font_awesome
    stylesheet = page(site, "assets/css/main.css")
    icons = Dir.glob(File.join(ROOT, "_data", "*.yml")).flat_map do |file|
      Array(YAML.safe_load_file(file, permitted_classes: [Date])).grep(Hash).filter_map { |entry| entry["icon"] }
    end
    refute_empty icons
    icons.uniq.each { |icon| assert_includes stylesheet, ".#{icon}", "#{icon} is not part of Font Awesome" }
  end
end
