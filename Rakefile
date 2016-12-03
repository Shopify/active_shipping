require 'bundler/gem_tasks'
require 'rake/testtask'

desc "Run the unit and functional remote tests"
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
  t.warning = false
end

namespace :test do
  desc "Run unit tests"
  Rake::TestTask.new(:unit) do |t|
    t.libs << "test"
    t.pattern = 'test/unit/**/*_test.rb'
    t.verbose = true
    t.warning = false
  end

  desc "Run functional remote tests"
  Rake::TestTask.new(:remote) do |t|
    t.libs << "test"
    t.pattern = 'test/remote/*_test.rb'
    t.verbose = true
    t.warning = false
  end
end

desc "Open a pry session preloaded with this library"
task :console do
  sh 'ruby -Ilib -Itest test/console.rb'
end

task :default => 'test'
