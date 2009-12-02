require 'rubygems'
require 'rake'
require 'rcov/rcovtask'

Rcov::RcovTask.new do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true     # uncomment to see the executed command
  t.rcov_opts = ['--exclude', 'test,/Library/Ruby/Gems/1.8/gems']
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "hipe-githelper"
    gem.summary = %Q{little convenience methods for git}
    gem.description = %Q{command-line convenience methods for git}
    gem.email = "mark dot meves at gmail dot com"
    gem.homepage = "http://github.com/hipe/hipe-githelper"
    gem.authors = ["Mark Meves"]
    gem.add_development_dependency "bacon", ">= 1.1.0"
    gem.add_dependency "hipe-gorillagrammar", ">= 0.0.1"
    #gem.add_development_dependency "rspec", ">= 1.2.9"
    # gem.add_development_dependency "yard", ">= 0"
    # gem.add_development_dependency "cucumber", ">= 0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

#Spec::Rake::SpecTask.new(:rcov) do |spec|
#  spec.libs << 'lib' << 'spec'
#  spec.pattern = 'spec/**/*_spec.rb'
#  spec.rcov = true
#end
#
task :spec => :check_dependencies

begin
  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new(:features)

  task :features => :check_dependencies
rescue LoadError
  task :features do
    abort "Cucumber is not available. In order to run features, you must: sudo gem install cucumber"
  end
end

task :default => :spec

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  task :yardoc do
    abort "YARD is not available. In order to run yardoc, you must: sudo gem install yard"
  end
end

Dir['tasks/*.rake'].each{|f| import(f) }
