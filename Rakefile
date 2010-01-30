require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'


PKG_VERSION = "0.0.1"
PKG_NAME = "activeshipping"
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

PKG_FILES = FileList[
    "lib/**/*", "examples/**/*", "[A-Z]*", "Rakefile"
].exclude(/\.svn$/)


desc "Default Task"
task :default => 'test:units'
task :test => ['test:units','test:remote']

# Run the unit tests

namespace :test do
  Rake::TestTask.new(:units) do |t|
    t.libs << "test"
    t.pattern = 'test/unit/**/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.verbose = true
  end

  Rake::TestTask.new(:remote) do |t|
    t.pattern = 'test/remote/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.verbose = true
  end
end

# Genereate the RDoc documentation
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "ActiveShipping library"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task :install => [:package] do
  `gem install pkg/#{PKG_FILE_NAME}.gem`
end
