# frozen_string_literal: true

# Tests for the data files in _data/: required fields, references between the files and
# the files they point to. A typo here otherwise shows up as an empty card or a broken
# image on the website.

require "test_helper"

class DataTest < Minitest::Test
  # Data files with sections rendered through _includes/legal-section.html
  SECTION_FILES = %w[datenschutz historie impressum].freeze

  def role_ids
    data("vorstandschaft").map { |role| role["id"] }
  end

  def assert_repository_file(path, context)
    assert File.file?(File.join(ROOT, path)), "#{context}: #{path} does not exist"
  end

  def test_every_member_has_a_name_and_a_known_register
    instruments = data("register").map { |register| register["instrument"] }
    data("mitglieder").each do |member|
      refute_empty member["name"].to_s, "member without name: #{member}"
      assert_includes instruments, member["register"], "#{member["name"]}: register not in register.yml"
    end
  end

  def test_member_names_are_unique
    names = data("mitglieder").map { |member| member["name"] }
    assert_empty names.tally.select { |_name, count| count > 1 }.keys
  end

  def test_every_role_of_a_member_exists
    data("mitglieder").each do |member|
      unknown = Array(member["rollen"]) - role_ids
      assert_empty unknown, "#{member["name"]}: unknown roles"
    end
  end

  def test_roles_are_unique_and_complete
    roles = data("vorstandschaft")
    assert_equal role_ids.uniq, role_ids
    roles.each do |role|
      refute_empty role["rolle"].to_s, "#{role["id"]}: rolle missing"
      refute_nil role["trennzeichen"], "#{role["id"]}: trennzeichen missing"
      assert_match(/\A[^@\s]+@[^@\s]+\.[a-z]+\z/, role["email"], "#{role["id"]}: invalid email") if role["email"]
    end
  end

  def test_every_register_has_an_existing_photo
    data("register").each do |register|
      assert_repository_file register["bild"], register["instrument"]
      assert_kind_of Integer, register["breite"], register["instrument"]
      assert_kind_of Integer, register["hoehe"], register["instrument"]
    end
  end

  def test_contact_cards_point_to_roles_with_an_email
    roles = data("vorstandschaft").to_h { |role| [role["id"], role] }
    data("kontaktkarten").each do |card|
      assert_empty Array(card["rollen"]) - roles.keys, "#{card["titel"]}: unknown roles"
      assert_includes card["rollen"], card["email_rolle"], "#{card["titel"]}: email_rolle not in rollen"
      refute_nil roles.dig(card["email_rolle"], "email"), "#{card["titel"]}: role #{card["email_rolle"]} has no email"
    end
  end

  def test_sections_have_title_icon_and_content
    SECTION_FILES.each do |file|
      data(file).each do |section|
        %w[titel icon inhalt].each do |field|
          refute_empty section[field].to_s, "#{file}.yml: #{section["titel"]} without #{field}"
        end
      end
    end
  end

  def test_navigation_entries_are_complete
    data("navigation").each do |entry|
      %w[titel url icon].each { |field| refute_empty entry[field].to_s, "navigation: #{entry} without #{field}" }
    end
  end

  def test_every_download_exists
    data("downloads").each do |download|
      assert_repository_file download["datei"], download["titel"]
    end
  end

  def test_an_active_flyer_has_an_image_and_a_valid_period
    flyer = data("flyer")
    skip "no active flyer" unless flyer["aktiv"]

    assert_repository_file flyer["bild"], "flyer"
    refute_empty flyer["alt"].to_s
    assert_kind_of Date, flyer["start"]
    assert_kind_of Date, flyer["ende"]
    assert_operator flyer["start"], :<=, flyer["ende"]
  end
end
