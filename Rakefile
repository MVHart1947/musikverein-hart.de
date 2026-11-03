# frozen_string_literal: true

# Tasks for development. "bundle exec rake" runs the test suite in test/ (see README):
# the Konzertmeister script, the data files and the built site.
require "rake/testtask"

Rake::TestTask.new(:test) do |task|
  task.libs << "test"
  task.test_files = FileList["test/**/*_test.rb"]
  task.warning = false
end

task default: :test
