require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rake/gempackagetask'

desc 'Run unit tests by default (and not remote tests)'
task :default => 'test:units'

desc 'Run all tests, including remote tests'
task :test => ['test:units','test:remote']

gemspec = eval(File.read('active_shipping.gemspec'))

Rake::GemPackageTask.new(gemspec) do |pkg|
  pkg.gem_spec = gemspec
end

desc "Default Task"
task :default => 'test:units'
task :test => ['test:units','test:remote']

namespace :test do
  Rake::TestTask.new(:units) do |t|
    t.libs << "test"
    t.pattern = 'test/unit/**/*_test.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:remote) do |t|
    t.libs << "test"
    t.pattern = 'test/remote/*_test.rb'
    t.verbose = true
  end
end

desc "Validate the gemspec"
task :gemspec do
  gemspec.validate
end

task :package => :gemspec

desc "Build and install the gem"
task :install => :package do
  sh %{gem install pkg/#{gemspec.name}-#{gemspec.version}}
end

desc "Uninstall gem"
task :uninstall => [ :clean ] do
  sh %{gem uninstall #{gemspec.name}}
end

desc "Release #{gemspec.name} gem (#{gemspec.version})"
task :release => [ :test, :package ] do
  sh %{gem push pkg/#{gemspec.name}-#{gemspec.version}.gem}
end