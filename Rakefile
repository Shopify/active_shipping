require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

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

desc "Default Task"
task :default => 'test:units'

desc "Run the unit and remote tests"
task :test => ['test:units','test:remote']
