# frozen_string_literal: true

# Shared setup of the test suite (bundle exec rake, see README).
#
# Loads the functions of script/fetch_termine.rb without running it, reads the data files
# and builds the site with Jekyll into temporary folders. Each build can replace data
# files and the build time, so the tests check the templates with known appointments and
# flyer dates instead of whatever the Konzertmeister API or _data/ currently hold.

# The pages contain umlauts, html-proofer and Nokogiri must not read them as ASCII
Encoding.default_external = Encoding::UTF_8

# Never call the real API from the tests: dotenv does not override a variable that is set
ENV["KONZERTMEISTER_API_KEY"] = ""
ENV["JEKYLL_ENV"] ||= "production"

require "fileutils"
require "jekyll"
require "json"
require "minitest/autorun"
require "tmpdir"
require "yaml"

require_relative "../script/fetch_termine"

# Minitest turns deprecation warnings on; those of Liquid and Jekyll would bury the results
Warning[:deprecated] = false

ROOT = File.expand_path("..", __dir__)
FIXTURES = File.join(__dir__, "fixtures")

# Reads one data file the way Jekyll does.
#
# @param name [String] file name in _data/ without extension
# @return [Object] the parsed YAML
def data(name)
  YAML.safe_load_file(File.join(ROOT, "_data", "#{name}.yml"), permitted_classes: [Date])
end

# Appointments as the Konzertmeister API returns them (test/fixtures/appointments.json).
#
# @return [Array<Hash>]
def appointments
  JSON.parse(File.read(File.join(FIXTURES, "appointments.json")))
end

# Builds the site once per combination of time and data and keeps the result for the run.
module SiteBuild
  @builds = {}

  # Builds the site into a temporary folder.
  #
  # @param time [Time] value of site.time, decides about the flyer
  # @param data [Hash] data files to replace after reading, e.g. { "termine" => [] }
  # @return [String] path of the built site
  def self.build(time:, data: {})
    @builds[[time.to_i, data]] ||= begin
      destination = Dir.mktmpdir("site-")
      Minitest.after_run { FileUtils.rm_rf(destination) }
      Jekyll.logger.log_level = :error
      config = Jekyll.configuration(
        "source" => ROOT, "destination" => destination, "quiet" => true,
        "disable_disk_cache" => true, "time" => time.iso8601
      )
      site = Jekyll::Site.new(config)
      site.reset
      site.read
      site.data.merge!(data)
      site.generate
      site.render
      site.cleanup
      site.write
      destination
    end
  end
end

# Reads a page of a built site.
#
# @param site [String] path returned by SiteBuild.build
# @param page [String] path of the page below the site, e.g. "index.html"
# @return [String] HTML of the page
def page(site, page)
  File.read(File.join(site, page))
end
